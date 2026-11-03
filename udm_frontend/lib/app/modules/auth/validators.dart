/// Client-side form rules that mirror the server's own validators, so a student
/// is told about a problem before the request round-trips. The API stays
/// authoritative: whatever slips through here comes back as a field error.
abstract class AuthValidators {
  static const int minimumPasswordLength = 10;
  static const int maximumNameLength = 150;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(text)) return 'That does not look like an email address.';
    return null;
  }

  static String? fullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Tell us what to call you.';
    if (text.length > maximumNameLength) return 'Use at most $maximumNameLength characters.';
    return null;
  }

  /// Only the length is checked here. Similarity, common-password and
  /// all-digits rules live in Django's validators and are reported on submit.
  static String? password(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    if (value!.length < minimumPasswordLength) return 'Use at least $minimumPasswordLength characters.';
    return null;
  }

  static String? Function(String?) matches(String other) => (String? value) =>
      value == other ? null : 'The passwords do not match.';
}
