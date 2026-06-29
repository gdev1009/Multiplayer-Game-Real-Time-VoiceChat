/// Simple input validators with friendly, large-print-ready messages.
class Validators {
  Validators._();

  /// Returns an error message, or null if the name is acceptable.
  static String? firstName(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Please enter your first name.';
    if (value.length < 2) return 'That name looks a little short.';
    if (value.length > 30) return 'That name is a little too long.';
    return null;
  }

  /// Returns an error message, or null if the email looks valid.
  static String? email(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Please enter your email address.';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(value)) {
      return 'Please check your email address.';
    }
    return null;
  }

  /// Returns an error message, or null if the PIN is exactly 4 digits.
  static String? pin(String? input) {
    final value = (input ?? '').trim();
    if (value.length != 4) return 'Your PIN must be 4 numbers.';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
      return 'Your PIN must be 4 numbers.';
    }
    return null;
  }
}
