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

/// What the sign-in UI should do next after the player enters their email.
enum EmailSignInStep {
  /// The account is already on this device — ask for the PIN and sign in
  /// silently (no email code needed).
  enterPin,

  /// The account exists elsewhere (fresh device). Ask for the PIN; it is
  /// checked on the server, then a one-time code confirms the device.
  enterPinRemote,
}

/// Outcome of [AuthService.beginEmailSignIn].
class EmailSignInResult {
  const EmailSignInResult.pin(String this.name)
      : step = EmailSignInStep.enterPin;
  const EmailSignInResult.pinRemote()
      : step = EmailSignInStep.enterPinRemote,
        name = null;

  final EmailSignInStep step;

  /// The account's first name, when known (fast local path only).
  final String? name;
}

/// Sign-in and account flows for Match Word.
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
  // Sign in with email + PIN ("I already have an account")
  // ---------------------------------------------------------------------------

  /// Step 1 of email sign-in. Decides how the player proves who they are:
  ///
  ///  - If this account is already on the device, we bring up its session with
  ///    the saved password and go straight to the PIN (returning
  ///    [EmailSignInStep.enterPin] with the greeting name). No code needed.
  ///  - Otherwise this is a fresh device. We ask for the PIN next; it is
  ///    verified on the server and, if correct, a one-time code confirms the
  ///    device (returning [EmailSignInStep.enterPinRemote]).
  ///
  /// This never blocks a registered email and never sends a code until the PIN
  /// checks out.
  Future<EmailSignInResult> beginEmailSignIn({required String email}) async {
    final lower = email.trim().toLowerCase();
    final storedEmail =
        (await _storage.read(key: _kEmail))?.trim().toLowerCase();

    // Fast path: this account was set up on (or already restored to) this
    // device, so we can sign in silently and just ask for the PIN.
    if (storedEmail != null && storedEmail == lower) {
      await _ensureSession();
      final profile = await _profiles.currentProfile();
      final name = profile?.firstName ?? await rememberedName();
      if (name == null || name.trim().isEmpty) {
        throw const AuthFailure('We could not load your account. Please retry.');
      }
      return EmailSignInResult.pin(name.trim());
    }

    // Fresh device: don't send anything yet. Collect the PIN next and verify it
    // on the server (email -> PIN -> code order).
    return const EmailSignInResult.pinRemote();
  }

  /// Fresh-device step: verifies [pin] for [email] on the server (no session
  /// required) and, when correct, emails a one-time code to confirm the device.
  /// Returns the account's first name for the greeting.
  ///
  /// Throws [AuthFailure] with:
  ///  - code 'no_account' when the email has no account (UI offers Create),
  ///  - a "PIN is not correct" message when the PIN is wrong,
  ///  - a "too many tries" message while the account is temporarily locked.
  Future<String> verifyPinRemoteAndSendCode({
    required String email,
    required String pin,
  }) async {
    final trimmedEmail = email.trim();
    final Map<String, dynamic> res;
    try {
      res = (await _client.rpc(
        'mw_verify_pin',
        params: {'p_email': trimmedEmail, 'p_pin': pin},
      ) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      throw const AuthFailure(
        'We could not sign you in. Please check your connection and try again.',
      );
    }

    final ok = res['ok'] == true;
    if (!ok) {
      final reason = res['reason'] as String?;
      switch (reason) {
        case 'no_account':
          throw const AuthFailure(
            'We could not find an account for that email. '
            'Please check it, or create a new account.',
            code: 'no_account',
          );
        case 'locked':
          final secs = (res['retry_seconds'] as num?)?.round() ?? 900;
          final mins = (secs / 60).ceil();
          throw AuthFailure(
            'Too many tries. Please wait about $mins '
            '${mins == 1 ? 'minute' : 'minutes'} and try again.',
          );
        default:
          throw const AuthFailure('That PIN is not correct.');
      }
    }

    // PIN is correct — send the one-time code to confirm this device.
    try {
      await _client.auth
          .signInWithOtp(email: trimmedEmail, shouldCreateUser: false);
    } on AuthException {
      throw const AuthFailure(
        'We could not send the code. Please try again in a moment.',
      );
    }

    final name = (res['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      return 'there'; // greeting fallback; real name loads after the code
    }
    return name;
  }

  /// Fresh-device final step: verifies the one-time [code] emailed to [email],
  /// establishes the account's session, and returns its first name.
  Future<String> verifyEmailCodeSignIn({
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

    final profile = await _profiles.currentProfile();
    final name = profile?.firstName ?? await rememberedName();
    if (name == null || name.trim().isEmpty) {
      throw const AuthFailure('We could not load your account. Please retry.');
    }
    return name.trim();
  }

  /// Step 2 of email sign-in: verifies [pin] against the account whose session
  /// was established by [beginEmailSignIn] or [verifyEmailCodeSignIn]. Returns
  /// the signed-in [Profile].
  Future<Profile> verifyPinSignIn({required String pin}) async {
    final creds = await _profiles.pinCredentials();
    if (creds == null) {
      throw const AuthFailure('We could not find your account on this device.');
    }
    if (!PinHasher.verify(pin, creds.salt, creds.hash)) {
      throw const AuthFailure('That PIN is not correct.');
    }
    // Make sure this device can sign in silently next time. On a fresh device
    // (code path) there is no saved password yet, so mint one now.
    await _ensureLocalCredentials();
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
  ///
  /// Recovery (email OTP) only grants a temporary session. To let the player
  /// sign in silently with name + PIN later (after a sign-out), we also set a
  /// fresh random Supabase password here and store it securely on the device.
  Future<void> setNewPin({required String pin}) async {
    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(pin, salt);
    await _profiles.updatePin(pinHash: hash, pinSalt: salt);

    final email = _client.auth.currentUser?.email;
    final profile = await _profiles.currentProfile();
    final name = profile?.firstName ?? await rememberedName() ?? '';
    if (email == null) return;

    final password = _generatePassword();
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      await _remember(name: name, email: email, password: password);
    } on AuthException {
      // Even if the password update fails, keep name/email so the greeting and
      // recovery still work.
      await _storage.write(key: _kName, value: name.trim());
      await _storage.write(key: _kEmail, value: email.trim());
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
      throw const AuthFailure(
        'We could not sign you in on this device. Please use '
        '"Forgot My PIN" to restore your account.',
      );
    }
    try {
      await _client.auth
          .signInWithPassword(email: email, password: password);
    } on AuthException {
      throw const AuthFailure(
        'We could not sign you in. Please use "Forgot My PIN" to '
        'restore your account.',
      );
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

  /// Ensures the device holds a working email + password so it can silently
  /// re-authenticate later (daily login by name + PIN).
  ///
  /// Used after a fresh-device code sign-in, where the account's session came
  /// from a one-time code and no reusable password is stored yet. We mint a new
  /// random Supabase password and remember it. If one is already stored (the
  /// normal returning-device case), this does nothing.
  Future<void> _ensureLocalCredentials() async {
    final storedPassword = await _storage.read(key: _kPassword);
    if (storedPassword != null && storedPassword.isNotEmpty) return;

    final email = _client.auth.currentUser?.email;
    if (email == null) return;
    final profile = await _profiles.currentProfile();
    final name = profile?.firstName ?? await rememberedName() ?? '';

    final password = _generatePassword();
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      await _remember(name: name, email: email, password: password);
    } on AuthException {
      // Even if we could not rotate the password, remember name + email so the
      // greeting works and recovery stays available.
      await _storage.write(key: _kName, value: name.trim());
      await _storage.write(key: _kEmail, value: email.trim());
    }
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
