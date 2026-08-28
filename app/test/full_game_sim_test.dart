import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/ai_player.dart';
import 'package:match_word/features/game/clue_bank.dart';
import 'package:match_word/features/game/game_engine.dart';
import 'package:match_word/features/game/word_bank.dart';

/// Plays complete games end to end with stand-ins on every seat.
///
/// The individual rules are unit-tested elsewhere; this is the check that they
/// hold *together* over a real game, which is the only thing Ronna actually
/// experiences. It is what would have caught the original complaint — clues
/// that identify nothing, and a "correct" that reads as nonsense.
void main() {
  /// Runs one whole game, returning what happened for the assertions to read.
  ({
    List<
        ({
          int word,
          String team,
          String clue,
          String guess,
          bool correct
        })> plays,
    List<String> openers,
    bool finished,
  }) playGame(int gameSeed) {
    final plays =
        <({int word, String team, String clue, String guess, bool correct})>[];
    final openers = <String>[];

    var state = MatchEngine.start(
      words: WordBank.deal(16, random: Random(gameSeed)),
      names: const {'A1': 'Ann', 'A2': 'Al', 'B1': 'Bea', 'B2': 'Ben'},
    );
    openers.add(state.cluingTeam);

    var guard = 0;
    while (!state.isOver && guard++ < 500) {
      if (state.isHalftime) {
        state = MatchEngine.beginSecondHalf(state);
        openers.add(state.cluingTeam);
        continue;
      }
      if (state.isResolved) {
        final before = state.wordIndex;
        state = MatchEngine.nextWord(state);
        if (!state.isOver && !state.isHalftime && state.wordIndex != before) {
          openers.add(state.cluingTeam);
        }
        continue;
      }

      if (state.step == TurnStep.awaitingClue) {
        final word = state.secretWord;
        final clue = AiPlayer.clueFor(
          word,
          variant: state.wordIndex * 7 + state.exchangeCount,
          avoid: state.usedClues,
        );
        final team = state.cluingTeam;
        final wordIndex = state.wordIndex;
        final next = MatchEngine.submitClue(state, clue);
        // A rejected clue leaves the step unchanged and would spin forever.
        expect(next.step, TurnStep.awaitingGuess,
            reason: 'clue "$clue" for "$word" was rejected: ${next.hostLine}');
        state = next;

        final guess = AiPlayer.guessFor(
          word,
          seed: gameSeed + wordIndex * 13 + state.exchangeCount,
        );
        final correct = MatchEngine.isCorrect(guess, word);
        plays.add((
          word: wordIndex,
          team: team,
          clue: clue,
          guess: guess,
          correct: correct,
        ));
        state = MatchEngine.submitGuess(state, guess);
      } else {
        break; // nothing else should be pending
      }
    }

    return (plays: plays, openers: openers, finished: state.isOver);
  }

  group('a full game of stand-ins holds together', () {
    test('games finish, and every clue is accepted', () {
      for (var seed = 1; seed <= 25; seed++) {
        final game = playGame(seed);
        expect(game.finished, isTrue, reason: 'game $seed never ended');
        expect(game.plays, isNotEmpty);
      }
    });

    test('every clue given identifies the word it is for', () {
      // The heart of Ronna's complaint: a clue must come from the word's own
      // curated set, never a category placeholder like "Person" or "Spot".
      for (var seed = 1; seed <= 25; seed++) {
        for (final play in playGame(seed).plays) {
          final word = WordBank.deal(16, random: Random(seed))[play.word];
          final clues = {
            for (final c in ClueBank.cluesFor(word)) c.toLowerCase(),
          };
          expect(clues, contains(play.clue.toLowerCase()),
              reason: 'clue "${play.clue}" is not a clue for "$word"');
        }
      }
    });

    test('a clue is never reused on the same word', () {
      for (var seed = 1; seed <= 25; seed++) {
        final byWord = <int, List<String>>{};
        for (final play in playGame(seed).plays) {
          final seen = byWord.putIfAbsent(play.word, () => []);
          expect(seen, isNot(contains(play.clue.toLowerCase())),
              reason: 'clue "${play.clue}" repeated on word ${play.word}');
          seen.add(play.clue.toLowerCase());
        }
      }
    });

    test('a guess is never a foul (saying the clue back)', () {
      for (var seed = 1; seed <= 25; seed++) {
        for (final play in playGame(seed).plays) {
          expect(MatchEngine.isClueFoul(play.guess, play.clue), isFalse,
              reason: 'guessed the clue "${play.clue}" back');
        }
      }
    });

    test('a "correct" is only ever called on the real word', () {
      // The bug read as the game agreeing with a nonsense answer. It never
      // actually did — but now the clue makes the right answer reachable.
      for (var seed = 1; seed <= 25; seed++) {
        final words = WordBank.deal(16, random: Random(seed));
        for (final play in playGame(seed).plays) {
          if (play.correct) {
            expect(play.guess.toLowerCase(), words[play.word].toLowerCase());
          }
        }
      }
    });

    test('a wrong answer is still on topic, not a random noun', () {
      var misses = 0;
      for (var seed = 1; seed <= 25; seed++) {
        final words = WordBank.deal(16, random: Random(seed));
        for (final play in playGame(seed).plays) {
          if (play.correct) continue;
          misses++;
          final family = {
            for (final s in ClueBank.siblingsOf(words[play.word]))
              s.toLowerCase(),
          };
          expect(family, contains(play.guess.toLowerCase()),
              reason: '"${play.guess}" is unrelated to "${words[play.word]}"');
        }
      }
      expect(misses, greaterThan(0), reason: 'expected some misses to inspect');
    });

    test('no team ever gives two clues in a row, steals included', () {
      // Ronna: "about 3/4 of the way through it gives the team that's opposite
      // to me two or three turns in a row." The rule she chose is that the
      // floor alternates on who actually went last — so a steal counts as that
      // team's turn, and they do not also open the next word.
      for (var seed = 1; seed <= 25; seed++) {
        final turns = playGame(seed).plays.map((p) => p.team).toList();
        for (var i = 1; i < turns.length; i++) {
          expect(turns[i], isNot(turns[i - 1]),
              reason: 'team ${turns[i]} clued twice running in game $seed');
        }
      }
    });
  });
}
