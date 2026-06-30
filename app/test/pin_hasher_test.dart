import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/core/utils/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('verifies a correct PIN', () {
      final salt = PinHasher.generateSalt();
      final hash = PinHasher.hash('1234', salt);
      expect(PinHasher.verify('1234', salt, hash), isTrue);
    });

    test('rejects an incorrect PIN', () {
      final salt = PinHasher.generateSalt();
      final hash = PinHasher.hash('1234', salt);
      expect(PinHasher.verify('0000', salt, hash), isFalse);
    });

    test('same PIN with different salts produces different hashes', () {
      final hashA = PinHasher.hash('1234', PinHasher.generateSalt());
      final hashB = PinHasher.hash('1234', PinHasher.generateSalt());
      expect(hashA, isNot(equals(hashB)));
    });

    test('generates unique salts', () {
      final salts = List.generate(50, (_) => PinHasher.generateSalt());
      expect(salts.toSet().length, salts.length);
    });
  });
}
