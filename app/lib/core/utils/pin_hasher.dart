import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Hashes and verifies 4-digit PINs.
///
/// A PIN is low-entropy, so the hash exists to protect it at rest and to gate
/// access locally. Each PIN gets a unique random salt and many SHA-256 rounds
/// to slow down brute force. The email one-time-code flow is the real account
/// recovery path.
class PinHasher {
  PinHasher._();

  static const int _rounds = 50000;
  static const int _saltBytes = 16;

  /// Generates a fresh random salt, base64-encoded.
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltBytes, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Derives a hash for [pin] using [salt] with stretched SHA-256.
  static String hash(String pin, String salt) {
    var bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < _rounds; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  /// Constant-time-ish verification of [pin] against a stored [expectedHash].
  static bool verify(String pin, String salt, String expectedHash) {
    final computed = hash(pin, salt);
    if (computed.length != expectedHash.length) return false;
    var mismatch = 0;
    for (var i = 0; i < computed.length; i++) {
      mismatch |= computed.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
