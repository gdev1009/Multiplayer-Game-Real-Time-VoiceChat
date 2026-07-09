/// A user-facing failure with a calm, large-print-friendly message.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});
  final String message;

  /// Optional machine-readable tag so the UI can react (e.g. 'no_account' to
  /// offer "Create an Account"). Null for generic failures.
  final String? code;

  @override
  String toString() => message;
}
