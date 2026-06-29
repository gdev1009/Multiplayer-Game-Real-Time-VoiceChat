import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/pin_hasher.dart';
import '../models/profile.dart';
import 'auth_failure.dart';
import 'device_service.dart';
import 'profile_service.dart';
import 'trial_service.dart';

/// Coordinates the whole Sign In & Account System (Milestone 1).
///
/// Login model (per spec):
///  - Account creation (once): first name + email + 4-digit PIN.
///  - Daily login: first name + 4-digit PIN.
///  - The email lives in Supabase Auth for recovery only and is never shown.
///
/// Under the hood, each account uses Supabase email/password auth. The PIN is
/// the local gate; a strong random password backs the Supabase session and is
/// stored in secure storage so the device can re-authenticate silently.
class AuthService {
  AuthService({
    required SupabaseClient client,
    required DeviceService deviceService,
    required ProfileService profileService,
    required TrialService trialService,
    FlutterSecureStorage? storage,
  })  : _client = client,
        _device = deviceService,
        _profiles = profileService,
        _trials = trialService,
        _storage = storage ?? const FlutterSecureStorage();

  static const _kName = 'mw_remembered_name';
  static const _kEmail = 'mw_account_email';
  static const _kPassword = 'mw_account_password';

  final SupabaseClient _client;
  final DeviceService _device;
  final ProfileService _profiles;
  final TrialService _trials;
  final FlutterSecureStorage _storage;

  bool get isSignedIn => _client.auth.currentSession != null;

  /// True if an account was set up on this device (so we show Daily Login
  /// instead of the Welcome / Create flow).
  Future<bool> hasLocalAccount() async {
    final email = await _storage.read(key: _kEmail);
    return email != null && email.isNotEmpty;
  }

  /// The remembered first name, shown to greet the returning player.
  Future<String?> rememberedName() => _storage.read(key: _kName);

  // ---------------------------------------------------------------------------
  // Account creation
  // ---------------------------------------------------------------------------

  Future<Profile> createAccount({
    required String firstName,
    required String email,
    required String pin,
  }) async {
    final deviceId = await _device.deviceId();

    // Silent trial-abuse check: device-id is the primary signal.
    final trialUsedBefore = await _trials.hasUsedTrial(deviceId);
    final grantTrial = !trialUsedBefore;

    final password = _generatePassword();

    final AuthResponse res;
    try {
      res = await _client.auth.signUp(email: email.trim(), password: password);
    } on AuthException catch (e) {
      throw AuthFailure(_friendlySignUpError(e));
    } catch (_) {
      throw const AuthFailure(
        'We could not create your account. Please check your '
        'connection and try again.',
      );
    }

    final user = res.user;
    if (user == null) {
      throw const AuthFailure(
        'We could not create your account. Please try again.',
      );
    }

    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(pin, salt);

    await _profiles.createProfile(
      userId: user.id,
      firstName: firstName,
      deviceId: deviceId,
      pinHash: hash,
      pinSalt: salt,
      grantTrial: grantTrial,
    );

    if (grantTrial) {
      await _trials.recordTrialStart(deviceId);
    }

    await _remember(name: firstName, email: email, password: password);

    final profile = await _profiles.currentProfile();
    if (profile == null) {
      throw const AuthFailure('Your account was created but could not load.');
    }
    return profile;
  }

  // ---------------------------------------------------------------------------
  // Daily login (first name + PIN)
  // ---------------------------------------------------------------------------

  Future<Profile> dailyLogin({
    required String firstName,
    required String pin,
  }) async {
    await _ensureSession();

    final remembered = await rememberedName();
    if (remembered == null ||
        remembered.trim().toLowerCase() != firstName.trim().toLowerCase()) {
      throw const AuthFailure('That name or PIN is not correct.');
    }

    final creds = await _profiles.pinCredentials();
    if (creds == null) {
      throw const AuthFailure('We could not find your account on this device.');
    }

    if (!PinHasher.verify(pin, creds.salt, creds.hash)) {
      throw const AuthFailure('That name or PIN is not correct.');
    }

    final profile = await _profiles.currentProfile();
    if (profile == null) {
      throw const AuthFailure('We could not load your account. Please retry.');
    }
    return profile;
  }

  // ---------------------------------------------------------------------------
  // Forgot PIN — email one-time code, then set a new PIN
  // ---------------------------------------------------------------------------

  /// Sends a one-time code to [email] (defaults to the remembered email).
  Future<void> sendRecoveryCode({String? email}) async {
    final target = (email ?? await _storage.read(key: _kEmail))?.trim();
    if (target == null || target.isEmpty) {
      throw const AuthFailure('Please enter the email you used to sign up.');
    }
    try {
      await _client.auth.signInWithOtp(email: target, shouldCreateUser: false);
    } on AuthException {
      throw const AuthFailure(
        'We could not send the code. Please check the email and try again.',
      );
    }
  }

  /// Verifies the [code] for [email] and establishes a session so a new PIN
  /// can be set.
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.email,
      );
    } on AuthException {
      throw const AuthFailure('That code is not correct or has expired.');
    }
  }

  /// Sets a brand-new PIN after recovery and remembers this account locally.
  Future<void> setNewPin({required String pin}) async {
    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(pin, salt);
    await _profiles.updatePin(pinHash: hash, pinSalt: salt);

    final profile = await _profiles.currentProfile();
    final email = _client.auth.currentUser?.email;
    if (profile != null && email != null) {
      await _storage.write(key: _kName, value: profile.firstName);
      await _storage.write(key: _kEmail, value: email);
    }
  }

  // ---------------------------------------------------------------------------
  // Session control
  // ---------------------------------------------------------------------------

  /// Locks the app (ends the session) while keeping the device's saved
  /// credentials so the player can log back in with name + PIN.
  Future<void> lock() async {
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _ensureSession() async {
    if (_client.auth.currentSession != null) return;

    final email = await _storage.read(key: _kEmail);
    final password = await _storage.read(key: _kPassword);
    if (email == null || password == null) {
      throw const AuthFailure('We could not find your account on this device.');
    }
    try {
      await _client.auth
          .signInWithPassword(email: email, password: password);
    } on AuthException {
      throw const AuthFailure('We could not sign you in. Please try again.');
    }
  }

  Future<void> _remember({
    required String name,
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _kName, value: name.trim());
    await _storage.write(key: _kEmail, value: email.trim());
    await _storage.write(key: _kPassword, value: password);
  }

  String _generatePassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return 'Mw!${base64Url.encode(bytes)}';
  }

  String _friendlySignUpError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already') || msg.contains('registered')) {
      return 'That email already has an account. Try "Forgot my PIN".';
    }
    return 'We could not create your account. Please try again.';
  }
}
