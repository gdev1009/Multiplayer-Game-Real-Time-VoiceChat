import 'package:flutter/foundation.dart';

import '../../models/profile.dart';
import '../../services/auth_service.dart';

enum AuthStatus { unknown, needsAccount, locked, signedIn }

/// App-wide authentication state. The UI listens to this and the [AuthGate]
/// routes based on [status].
class AuthController extends ChangeNotifier {
  AuthController(this._auth);

  final AuthService _auth;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  Profile? _profile;
  Profile? get profile => _profile;

  String? _rememberedName;
  String? get rememberedName => _rememberedName;

  String? _rememberedEmail;
  String? get rememberedEmail => _rememberedEmail;

  /// Decides the first screen on launch.
  Future<void> bootstrap() async {
    _rememberedName = await _auth.rememberedName();
    _rememberedEmail = await _auth.rememberedEmail();
    final hasAccount = await _auth.hasLocalAccount();
    if (!hasAccount) {
      _set(AuthStatus.needsAccount);
      return;
    }
    // An account exists on this device; require the PIN to continue.
    _set(AuthStatus.locked);
  }

  Future<void> createAccount({
    required String firstName,
    required String email,
    required String pin,
  }) async {
    _profile = await _auth.createAccount(
      firstName: firstName,
      email: email,
      pin: pin,
    );
    _rememberedName = firstName;
    _rememberedEmail = email.trim();
    _set(AuthStatus.signedIn);
  }

  Future<void> dailyLogin({
    required String firstName,
    required String pin,
  }) async {
    _profile = await _auth.dailyLogin(firstName: firstName, pin: pin);
    _set(AuthStatus.signedIn);
  }

  /// Step 1 of "I already have an account": decides whether to sign in silently
  /// and ask for the PIN (account already on this device) or to verify the PIN
  /// on the server first (fresh device).
  Future<EmailSignInResult> beginEmailSignIn({required String email}) =>
      _auth.beginEmailSignIn(email: email);

  /// Fresh-device step: verify the PIN on the server and, if correct, email a
  /// one-time code to confirm the device. Returns the greeting name.
  Future<String> verifyPinRemoteAndSendCode({
    required String email,
    required String pin,
  }) =>
      _auth.verifyPinRemoteAndSendCode(email: email, pin: pin);

  /// Fresh-device final step: verify the emailed [code] (establishes the
  /// session), then confirm the [pin] and sign in. This also restores silent
  /// sign-in on this device for next time.
  Future<void> completeRemoteSignIn({
    required String email,
    required String code,
    required String pin,
  }) async {
    await _auth.verifyEmailCodeSignIn(email: email, code: code);
    _profile = await _auth.verifyPinSignIn(pin: pin);
    _rememberedName = await _auth.rememberedName();
    _rememberedEmail = await _auth.rememberedEmail();
    _set(AuthStatus.signedIn);
  }

  /// Step 2 of "I already have an account" (same-device fast path): verify the
  /// PIN and sign in.
  Future<void> verifyPinSignIn({required String pin}) async {
    _profile = await _auth.verifyPinSignIn(pin: pin);
    _rememberedName = await _auth.rememberedName();
    _rememberedEmail = await _auth.rememberedEmail();
    _set(AuthStatus.signedIn);
  }

  /// Re-reads the profile so the greeting name and trial days stay current.
  ///
  /// Keeps the previous profile on failure — a network blip must not drop the
  /// player's name back to "friend".
  Future<void> refreshProfile() async {
    if (_status != AuthStatus.signedIn) return;
    try {
      final fresh = await _auth.currentProfile();
      if (fresh == null) return;
      _profile = fresh;
      notifyListeners();
    } catch (_) {
      // Keep the name we already have.
    }
  }

  Future<void> lock() async {
    await _auth.lock();
    _profile = null;
    _set(AuthStatus.locked);
  }

  /// Ends the session but keeps this device's account — next screen is Daily
  /// Login (name + PIN), not a fresh email prompt.
  Future<void> signOut() async {
    await _auth.lock();
    _profile = null;
    _rememberedName = await _auth.rememberedName();
    _rememberedEmail = await _auth.rememberedEmail();
    final hasAccount = await _auth.hasLocalAccount();
    _set(hasAccount ? AuthStatus.locked : AuthStatus.needsAccount);
  }

  /// Leave the remembered account on this device and return to Welcome
  /// (create / sign in with a different email).
  Future<void> useAnotherAccount() async {
    await _auth.clearLocalAccount();
    _profile = null;
    _rememberedName = null;
    _rememberedEmail = null;
    _set(AuthStatus.needsAccount);
  }

  // Recovery passthroughs.
  Future<void> sendRecoveryCode({String? email}) =>
      _auth.sendRecoveryCode(email: email);

  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) =>
      _auth.verifyRecoveryCode(email: email, code: code);

  Future<void> setNewPinAndSignIn({required String pin}) async {
    await _auth.setNewPin(pin: pin);
    _profile = null;
    _rememberedName = await _auth.rememberedName();
    _rememberedEmail = await _auth.rememberedEmail();
    _set(AuthStatus.locked);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
