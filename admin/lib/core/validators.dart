/// Form validators. They mirror the database CHECK rules so problems show
/// up in the form before anything is sent.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, {String field = 'This field'}) =>
      (value == null || value.trim().isEmpty) ? '$field is required.' : null;

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    return _email.hasMatch(value.trim()) ? null : 'Enter a valid email.';
  }

  static String? optionalEmail(String? value) =>
      (value == null || value.trim().isEmpty) ? null : email(value);

  /// At least 10 characters with a letter and a number.
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.length < 10) return 'Use at least 10 characters.';
    if (!RegExp('[A-Za-z]').hasMatch(text) || !RegExp('[0-9]').hasMatch(text)) {
      return 'Use letters and at least one number.';
    }
    return null;
  }

  static String? maxLength(String? value, int max) =>
      (value != null && value.length > max)
      ? 'Keep it under $max characters.'
      : null;

  /// WhatsApp number with country code, digits only: 919876543210.
  static String? whatsapp(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^[0-9]{10,13}$').hasMatch(value.trim())
        ? null
        : 'Digits only, with country code (e.g. 919876543210).';
  }

  /// GST number: 15 capital letters or digits (the form upper-cases what is typed).
  static String? gstNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^[0-9A-Za-z]{15}$').hasMatch(value.trim())
        ? null
        : 'A GST number has 15 letters and digits.';
  }
}
