/// A user-facing failure with a calm, large-print-friendly message.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
