import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/ai_player.dart';
import 'package:match_word/features/game/word_bank.dart';

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

    // Ronna (Aug 2026): a stand-in echoed the clue the other team just gave.
    test('never repeats a clue already spent on the word', () {
      for (final word in ['garden', 'coffee', 'teapot', 'zzxq']) {
        final used = <String>[];
        // A word can need one clue per exchange before it is revealed.
        for (var i = 0; i < 5; i++) {
          final clue = AiPlayer.clueFor(word, variant: i, avoid: used);
          expect(
            used.map((u) => u.toLowerCase()),
            isNot(contains(clue.toLowerCase())),
            reason: 'repeat on $word after $used',
          );
          expect(clue.trim(), isNotEmpty);
          used.add(clue);
        }
      }
    });

    test('avoid is case-insensitive', () {
      final first = AiPlayer.clueFor('garden');
      final next = AiPlayer.clueFor('garden', avoid: [first.toUpperCase()]);
      expect(next.toLowerCase(), isNot(first.toLowerCase()));
    });

    test('never uses Starts*/Ends*/LetterCount clues', () {
      for (final word in WordBank.words.take(80).followedBy(const [
        'Pink',
        'Pillow',
        'Accelerate',
        'Zebra',
        'zzxqabc',
      ])) {
        for (var v = 0; v < 5; v++) {
          final clue = AiPlayer.clueFor(word, variant: v).toLowerCase();
          expect(clue.startsWith('starts'), isFalse, reason: '$word → $clue');
          expect(clue.startsWith('ends'), isFalse, reason: '$word → $clue');
          expect(clue.contains('letter'), isFalse, reason: '$word → $clue');
        }
      }
    });

    test('pink gets a color-style clue, not StartsP', () {
      final clue = AiPlayer.clueFor('pink');
      expect(clue.toLowerCase(), isNot(equals('startsp')));
      expect(
        ['color', 'blush', 'rose'].contains(clue.toLowerCase()),
        isTrue,
      );
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

    // Ronna (Aug 2026): "the clues and answers didn't make sense when
    // stand-in's played" — a miss used to be an unrelated word from a fixed
    // pool, so the clue "Teapot" could be answered "Bicycle".
    test('a wrong guess relates to the word it is answering', () {
      // 'garden' has a known clue family; a miss must come from it.
      final family = {
        for (var v = 0; v < 8; v++)
          AiPlayer.clueFor('garden', variant: v).toLowerCase(),
      };
      var misses = 0;
      for (var seed = 0; seed < 200; seed++) {
        final guess = AiPlayer.guessFor('garden', seed: seed).toLowerCase();
        if (guess == 'garden') continue;
        misses++;
        expect(family, contains(guess), reason: 'unrelated miss "$guess"');
      }
      expect(misses, greaterThan(0), reason: 'expected some misses to check');
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
      expect(rate, greaterThan(0.75));
      expect(rate, lessThan(0.98));
    });

    test('looksForSeats keeps hair/glasses/hat/outfit unique in a match', () {
      final looks = AiPlayer.looksForSeats('game-video23', [
        (role: 'A1', name: 'Greg'),
        (role: 'A2', name: 'Buddy'),
        (role: 'B1', name: 'Rosie'),
        (role: 'B2', name: 'Pearl'),
      ]);
      expect(looks.length, 4);
      final hairs = looks.values.map((c) => c.hair).whereType<String>().toList();
      expect(hairs.toSet().length, hairs.length);
      final outfits =
          looks.values.map((c) => c.outfit).whereType<String>().toList();
      expect(outfits.toSet().length, outfits.length);
      final glasses =
          looks.values.map((c) => c.glasses ?? '__none__').toList();
      expect(glasses.toSet().length, glasses.length);
      final hats = looks.values.map((c) => c.hat ?? '__none__').toList();
      expect(hats.toSet().length, hats.length);
      // Stable for the same salt.
      final again = AiPlayer.looksForSeats('game-video23', [
        (role: 'A1', name: 'Greg'),
        (role: 'A2', name: 'Buddy'),
        (role: 'B1', name: 'Rosie'),
        (role: 'B2', name: 'Pearl'),
      ]);
      expect(again['B1']!.hat, looks['B1']!.hat);
      expect(again['B2']!.hat, looks['B2']!.hat);
      expect(again['B1']!.hat, isNot(equals(again['B2']!.hat)));
    });

    test('fillNamesForGame varies by game id and skips taken names', () {
      final a = AiPlayer.fillNamesForGame('game-aaa', count: 3, taken: ['Greg']);
      final b = AiPlayer.fillNamesForGame('game-bbb', count: 3, taken: ['Greg']);
      expect(a.length, 3);
      expect(b.length, 3);
      expect(a.toSet().length, 3);
      expect(a, isNot(contains('Greg')));
      expect(a, isNot(equals(b)));
      expect(
        AiPlayer.fillNamesForGame('game-aaa', count: 3, taken: ['Greg']),
        a,
      );
    });
  });
}
