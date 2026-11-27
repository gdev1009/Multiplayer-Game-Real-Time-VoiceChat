import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/computer_play.dart';

void main() {
  group('ComputerPlayLevel', () {
    test('the same turn always waits the same length', () {
      const args = (
        wordIndex: 4,
        exchangeCount: 2,
        guessing: true,
        afterWrong: false,
      );
      expect(
        ComputerPlayLevel.medium.pauseFor(
          wordIndex: args.wordIndex,
          exchangeCount: args.exchangeCount,
          guessing: args.guessing,
          afterWrong: args.afterWrong,
        ),
        ComputerPlayLevel.medium.pauseFor(
          wordIndex: args.wordIndex,
          exchangeCount: args.exchangeCount,
          guessing: args.guessing,
          afterWrong: args.afterWrong,
        ),
      );
    });

    test('a miss on the board adds a little reading time', () {
      final calm = ComputerPlayLevel.medium.pauseFor(
        wordIndex: 1,
        exchangeCount: 0,
        guessing: true,
        afterWrong: false,
      );
      final after = ComputerPlayLevel.medium.pauseFor(
        wordIndex: 1,
        exchangeCount: 0,
        guessing: true,
        afterWrong: true,
      );
      expect(after - calm, const Duration(seconds: 2));
    });

    test('some turns are slower, and not every turn', () {
      for (final level in ComputerPlayLevel.values) {
        final waits = <int>{};
        for (var word = 0; word < 40; word++) {
          for (var exchange = 0; exchange < 4; exchange++) {
            for (final guessing in const [false, true]) {
              waits.add(
                level
                    .pauseFor(
                      wordIndex: word,
                      exchangeCount: exchange,
                      guessing: guessing,
                      afterWrong: false,
                    )
                    .inMilliseconds,
              );
            }
          }
        }
        expect(waits.length, greaterThan(1), reason: level.name);
      }
    });

    test('Easy waits longer than Hard on the same turn', () {
      for (var word = 0; word < 12; word++) {
        final easy = ComputerPlayLevel.easy.pauseFor(
          wordIndex: word,
          exchangeCount: 1,
          guessing: true,
          afterWrong: false,
        );
        final hard = ComputerPlayLevel.hard.pauseFor(
          wordIndex: word,
          exchangeCount: 1,
          guessing: true,
          afterWrong: false,
        );
        expect(easy, greaterThan(hard), reason: 'word $word');
      }
    });
  });
}
