import 'package:firebase_auth/firebase_auth.dart';

String normalizeAuthEmail(String value) => value.trim().toLowerCase();

final RegExp _passwordUppercasePattern = RegExp(r'[A-Z]');
final RegExp _passwordDigitPattern = RegExp(r'\d');
final RegExp _passwordAsciiSymbolPattern = RegExp(
  r'''[!@#$%^&*()_\-+=\[\]{}|\\:;"'<>,.?/~`]''',
);
final RegExp _passwordSupportedCharactersPattern = RegExp(r'^[\x21-\x7E]+$');

bool isValidAuthEmail(String value) {
  final normalized = normalizeAuthEmail(value);
  if (normalized.isEmpty || normalized.length < 3) {
    return false;
  }
  return RegExp(
    r"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$",
    caseSensitive: false,
  ).hasMatch(normalized);
}

bool isPasswordLongEnough(String value) => value.length >= 8;

bool hasPasswordUppercase(String value) =>
    _passwordUppercasePattern.hasMatch(value);

bool hasPasswordDigit(String value) => _passwordDigitPattern.hasMatch(value);

bool hasPasswordAsciiSymbol(String value) =>
    _passwordAsciiSymbolPattern.hasMatch(value);

bool isValidCreateAccountPassword(String value) {
  if (!isPasswordLongEnough(value)) {
    return false;
  }
  return hasPasswordUppercase(value) &&
      hasPasswordDigit(value) &&
      hasPasswordAsciiSymbol(value);
}

bool hasOnlySupportedPasswordCharacters(String value) {
  if (value.isEmpty) {
    return true;
  }
  return _passwordSupportedCharactersPattern.hasMatch(value);
}

bool shouldTreatAsInvalidEmailPassword(Object error) {
  if (error is! FirebaseAuthException) {
    return false;
  }
  return error.code == 'invalid-credential' ||
      error.code == 'wrong-password' ||
      error.code == 'invalid-login-credentials' ||
      error.code == 'user-not-found';
}
