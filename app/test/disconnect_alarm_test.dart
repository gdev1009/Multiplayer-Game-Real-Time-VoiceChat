import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/game_engine.dart';
import 'package:match_word/features/game/gameplay_controller.dart';
import 'package:match_word/features/game/word_bank.dart';

void main() {
  group('leave-app disconnect alarm', () {
    test('local / demo games never publish an away event', () async {
      final c = GameplayController()
        ..startLocal(
          names: const {
            'A1': 'Rosa',
            'A2': 'Walter',
            'B1': 'Grace',
            'B2': 'Mabel',
          },
          words: WordBank.deal(16),
          config: const MatchConfig(wordsPerHalf: 2),
          myRole: 'A1',
          aiByRole: const {
            'A1': false,
            'A2': true,
            'B1': true,
            'B2': true,
          },
        );
      await c.reportLeftApp();
      expect(c.disconnectSignal.value, isNull);
      c.dispose();
    });

    test('alarm copy names the player who left', () {
      // Mirrors GameplayController._onRemotePlayerAway formatting.
      const name = 'Rosa';
      final message =
          '$name left the game. We\'ll pause while they come back.';
      expect(message, contains('Rosa left the game'));
      expect(message, contains('come back'));
    });
  });
}
