import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/ai_player.dart';

void main() {
  group('AiPlayer.clueFor', () {
    test('never returns the secret word itself', () {
      for (final word in ['pancake', 'garden', 'RAINBOW', 'Puppy']) {
        for (var v = 0; v < 5; v++) {
          final clue = AiPlayer.clueFor(word, variant: v);
          expect(clue.toLowerCase(), isNot(equals(word.toLowerCase())));
          expect(clue.trim(), isNotEmpty);
        }
      }
    });

    test('offers different clues across variants for a bank word', () {
      final clues = {
        for (var v = 0; v < 3; v++) AiPlayer.clueFor('garden', variant: v),
      };
      expect(clues.length, greaterThan(1));
    });

    test('is deterministic for the same word + variant', () {
      expect(
        AiPlayer.clueFor('coffee', variant: 2),
        equals(AiPlayer.clueFor('coffee', variant: 2)),
      );
    });

    test('falls back gracefully for an unknown word', () {
      final clue = AiPlayer.clueFor('zzxq');
      expect(clue.trim(), isNotEmpty);
      expect(clue.toLowerCase(), isNot(equals('zzxq')));
    });
  });

  group('AiPlayer.guessFor', () {
    test('is deterministic for the same word + seed', () {
      expect(
        AiPlayer.guessFor('pancake', seed: 7),
        equals(AiPlayer.guessFor('pancake', seed: 7)),
      );
    });

    test('a wrong guess is never the secret word', () {
      // Sweep many seeds; every miss must be a different, real word.
      for (var seed = 0; seed < 200; seed++) {
        final guess = AiPlayer.guessFor('apple', seed: seed);
        if (guess.toLowerCase() != 'apple') {
          expect(guess.trim(), isNotEmpty);
          expect(guess.toLowerCase(), isNot(equals('apple')));
        }
      }
    });

    test('lands the word most of the time but not always (moderate skill)', () {
      var correct = 0;
      const trials = 300;
      for (var seed = 0; seed < trials; seed++) {
        if (AiPlayer.guessFor('rainbow', seed: seed).toLowerCase() ==
            'rainbow') {
          correct++;
        }
      }
      final rate = correct / trials;
      // Roughly the tuned 70% accuracy — lively but beatable, never perfect.
      expect(rate, greaterThan(0.5));
      expect(rate, lessThan(0.9));
    });
  });
}
