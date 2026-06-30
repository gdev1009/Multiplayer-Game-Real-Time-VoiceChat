import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/core/utils/validators.dart';

void main() {
  group('Validators.firstName', () {
    test('rejects empty and too-short names', () {
      expect(Validators.firstName(''), isNotNull);
      expect(Validators.firstName('A'), isNotNull);
    });
    test('accepts a normal name', () {
      expect(Validators.firstName('Ronna'), isNull);
    });
  });

  group('Validators.email', () {
    test('rejects malformed email', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
    test('accepts a valid email', () {
      expect(Validators.email('ronna@example.com'), isNull);
    });
  });

  group('Validators.pin', () {
    test('requires exactly 4 digits', () {
      expect(Validators.pin('123'), isNotNull);
      expect(Validators.pin('12345'), isNotNull);
      expect(Validators.pin('12a4'), isNotNull);
    });
    test('accepts 4 digits', () {
      expect(Validators.pin('4821'), isNull);
    });
  });
}
