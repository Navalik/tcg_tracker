import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcg_tracker/services/auth_email_support.dart';

void main() {
  group('normalizeAuthEmail', () {
    test('trims and lowercases email', () {
      expect(normalizeAuthEmail('  USER@Example.COM '), 'user@example.com');
    });
  });

  group('isValidAuthEmail', () {
    test('accepts a simple valid email', () {
      expect(isValidAuthEmail('user@example.com'), isTrue);
    });

    test('rejects malformed email', () {
      expect(isValidAuthEmail('userexample.com'), isFalse);
    });
  });

  group('isValidCreateAccountPassword', () {
    test('accepts password matching all requirements', () {
      expect(isValidCreateAccountPassword('Abcdef1!'), isTrue);
    });

    test('rejects password without uppercase', () {
      expect(isValidCreateAccountPassword('abcdef1!'), isFalse);
    });

    test('rejects password without number', () {
      expect(isValidCreateAccountPassword('Abcdefg!'), isFalse);
    });

    test('rejects password without ascii symbol', () {
      expect(isValidCreateAccountPassword('Abcdefg1'), isFalse);
    });

    test('rejects password with only unicode symbol', () {
      expect(isValidCreateAccountPassword('Abcdef1\u20AC'), isFalse);
    });
  });

  group('password requirement helpers', () {
    test('detects minimum length', () {
      expect(isPasswordLongEnough('Abc123!'), isFalse);
      expect(isPasswordLongEnough('Abcd123!'), isTrue);
    });

    test('detects uppercase', () {
      expect(hasPasswordUppercase('abcd123!'), isFalse);
      expect(hasPasswordUppercase('Abcd123!'), isTrue);
    });

    test('detects digit', () {
      expect(hasPasswordDigit('Abcdefg!'), isFalse);
      expect(hasPasswordDigit('Abcdef1!'), isTrue);
    });

    test('detects ascii symbol', () {
      expect(hasPasswordAsciiSymbol('Abcdef12'), isFalse);
      expect(hasPasswordAsciiSymbol('Abcdef1!'), isTrue);
    });
  });

  group('hasOnlySupportedPasswordCharacters', () {
    test('accepts printable ascii password characters', () {
      expect(hasOnlySupportedPasswordCharacters(r'Abcd1234!?@#'), isTrue);
    });

    test('rejects unicode symbols', () {
      expect(hasOnlySupportedPasswordCharacters('Abcd1234\u20AC'), isFalse);
    });

    test('rejects accented letters', () {
      expect(hasOnlySupportedPasswordCharacters('\u00C0bcd1234!'), isFalse);
    });
  });

  group('shouldTreatAsInvalidEmailPassword', () {
    test('accepts invalid credentials errors', () {
      final error = FirebaseAuthException(code: 'invalid-login-credentials');
      expect(shouldTreatAsInvalidEmailPassword(error), isTrue);
    });

    test('rejects unrelated auth errors', () {
      final error = FirebaseAuthException(code: 'network-request-failed');
      expect(shouldTreatAsInvalidEmailPassword(error), isFalse);
    });
  });
}
