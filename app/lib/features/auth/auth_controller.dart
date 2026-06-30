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

  /// Decides the first screen on launch.
  Future<void> bootstrap() async {
    _rememberedName = await _auth.rememberedName();
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
    _set(AuthStatus.signedIn);
  }

  Future<void> dailyLogin({
    required String firstName,
    required String pin,
  }) async {
    _profile = await _auth.dailyLogin(firstName: firstName, pin: pin);
    _set(AuthStatus.signedIn);
  }

  Future<void> lock() async {
    await _auth.lock();
    _profile = null;
    _set(AuthStatus.locked);
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
    _set(AuthStatus.locked);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
