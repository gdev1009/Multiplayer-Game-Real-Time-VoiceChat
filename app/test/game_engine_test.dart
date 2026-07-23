import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/game_engine.dart';
import 'package:match_word/features/game/word_bank.dart';

/// Four players, one per role, so feed entries and banners have names.
const _names = {'A1': 'Alice', 'A2': 'Amir', 'B1': 'Bea', 'B2': 'Ben'};

/// A deterministic word list: index 0 = 'One', 1 = 'Two', ...
List<String> _words(int n) =>
    List.generate(n, (i) => 'Word${i + 1}');

MatchState _startGame({
  MatchConfig config = const MatchConfig(wordsPerHalf: 2, maxExchanges: 3),
}) {
  return MatchEngine.start(
    words: _words(config.totalWords),
    names: _names,
    config: config,
  );
}

/// Plays the current word to a correct guess by whichever team is on the clock,
/// giving one clue then guessing the real word, then advancing off the resolved
/// beat to the next word.
MatchState _guessCorrect(MatchState s) {
  s = MatchEngine.submitClue(s, 'hint');
  s = MatchEngine.submitGuess(s, s.secretWord);
  return MatchEngine.nextWord(s);
}

void main() {
  group('role assignment + halftime switch', () {
    test('first half: role 1 clues, role 2 guesses', () {
      expect(MatchEngine.clueGiverRole('A', GamePhase.firstHalf), 'A1');
      expect(MatchEngine.guesserRole('A', GamePhase.firstHalf), 'A2');
      expect(MatchEngine.clueGiverRole('B', GamePhase.firstHalf), 'B1');
      expect(MatchEngine.guesserRole('B', GamePhase.firstHalf), 'B2');
    });

    test('second half: roles switch (role 2 clues, role 1 guesses)', () {
      expect(MatchEngine.clueGiverRole('A', GamePhase.secondHalf), 'A2');
      expect(MatchEngine.guesserRole('A', GamePhase.secondHalf), 'A1');
      expect(MatchEngine.clueGiverRole('B', GamePhase.secondHalf), 'B2');
      expect(MatchEngine.guesserRole('B', GamePhase.secondHalf), 'B1');
    });

    test('teams alternate who opens each word', () {
      expect(MatchEngine.startingTeamForWord(0), 'A');
      expect(MatchEngine.startingTeamForWord(1), 'B');
      expect(MatchEngine.startingTeamForWord(2), 'A');
      expect(MatchEngine.startingTeamForWord(3), 'B');
    });
  });

  group('start', () {
    test('opens on Team A, first half, awaiting a clue', () {
      final s = _startGame();
      expect(s.phase, GamePhase.firstHalf);
      expect(s.wordIndex, 0);
      expect(s.cluingTeam, 'A');
      expect(s.step, TurnStep.awaitingClue);
      expect(s.scoreA, 0);
      expect(s.scoreB, 0);
      expect(s.clueGiverName, 'Alice');
      expect(s.guesserName, 'Amir');
      expect(s.feed, isEmpty);
      expect(s.isTurnActive, isTrue);
    });
  });

  group('clue + correct guess', () {
    test('records the clue and awaits a guess', () {
      var s = _startGame();
      s = MatchEngine.submitClue(s, 'fruit');
      expect(s.step, TurnStep.awaitingGuess);
      expect(s.pendingClue, 'fruit');
      expect(s.feed.single.kind, PlayKind.clue);
      expect(s.feed.single.role, 'A1');
      expect(s.feed.single.playerName, 'Alice');
    });

    test('correct guess scores the full word value and pauses on a resolved beat', () {
      var s = _startGame(); // wordValue defaults to 5
      s = MatchEngine.submitClue(s, 'fruit');
      s = MatchEngine.submitGuess(s, s.secretWord.toUpperCase()); // case-insensitive
      expect(s.scoreA, 5);
      expect(s.scoreB, 0);
      expect(s.lastOutcome, WordOutcome.guessed);
      expect(s.isResolved, isTrue);
      expect(s.wordIndex, 0); // not advanced until nextWord
      expect(s.feed.last.correct, isTrue);

      s = MatchEngine.nextWord(s);
      expect(s.wordIndex, 1); // advanced to the next word
      expect(s.cluingTeam, 'B'); // word 1 opens with Team B
      expect(s.step, TurnStep.awaitingClue);
    });
  });

  group('steal mechanic', () {
    test('guessing the clue is a foul and steals', () {
      var s = _startGame();
      s = MatchEngine.submitClue(s, 'fruit');
      s = MatchEngine.submitGuess(s, 'FRUIT'); // same as clue
      expect(s.cluingTeam, 'B');
      expect(s.lastOutcome, WordOutcome.wrong);
      expect(s.feed.last.correct, isFalse);
      expect(s.hostLine.toLowerCase(), contains('foul'));
      expect(s.scoreA, 0);
    });

    test('a wrong guess hands control to the other team for less value', () {
      var s = _startGame();
      s = MatchEngine.submitClue(s, 'fruit');
      s = MatchEngine.submitGuess(s, 'wrong');
      expect(s.cluingTeam, 'B'); // steal — other team now clues
      expect(s.lastOutcome, WordOutcome.wrong);
      expect(s.step, TurnStep.awaitingClue);
      expect(s.exchangeCount, 1);
      expect(s.wordValue, 4); // value dropped by one
      expect(s.pendingClue, isNull);

      // Team B steals it: they earn the reduced value.
      s = MatchEngine.submitClue(s, 'hint');
      s = MatchEngine.submitGuess(s, s.secretWord);
      expect(s.scoreB, 4);
      expect(s.scoreA, 0);
      expect(s.isResolved, isTrue);
    });
  });

  group('auto-reveal', () {
    test('word reveals for no points after maxExchanges failed guesses', () {
      // maxExchanges = 3
      var s = _startGame();
      for (var i = 0; i < 3; i++) {
        s = MatchEngine.submitClue(s, 'hint$i');
        s = MatchEngine.submitGuess(s, 'nope$i');
      }
      expect(s.lastOutcome, WordOutcome.revealed);
      expect(s.isResolved, isTrue);
      expect(s.scoreA, 0);
      expect(s.scoreB, 0);
      s = MatchEngine.nextWord(s);
      expect(s.wordIndex, 1); // moved on to the next word
    });
  });

  group('halftime + role switch + game over', () {
    test('reaches halftime after the first half of words', () {
      var s = _startGame(); // wordsPerHalf = 2
      s = _guessCorrect(s); // word 0 -> Team A
      expect(s.phase, GamePhase.firstHalf);
      s = _guessCorrect(s); // word 1 -> now at halftime
      expect(s.phase, GamePhase.halftime);
      expect(s.isHalftime, isTrue);
      expect(s.isTurnActive, isFalse);
    });

    test('second half deals a fresh word with switched roles', () {
      var s = _startGame();
      s = _guessCorrect(s);
      s = _guessCorrect(s);
      expect(s.phase, GamePhase.halftime);
      s = MatchEngine.beginSecondHalf(s);
      expect(s.phase, GamePhase.secondHalf);
      expect(s.step, TurnStep.awaitingClue);
      // Word index 2 -> Team A opens, but now role A2 gives the clue.
      expect(s.cluingTeam, 'A');
      expect(s.clueGiverRole, 'A2');
      expect(s.guesserRole, 'A1');
      expect(s.clueGiverName, 'Amir');
    });

    test('plays through to game over and picks a winner', () {
      var s = _startGame();
      s = _guessCorrect(s); // A +5
      s = _guessCorrect(s); // B +5  -> halftime, tied 5-5
      s = MatchEngine.beginSecondHalf(s);
      s = _guessCorrect(s); // A +5  -> 10-5
      s = _guessCorrect(s); // B +5  -> 10-10 tie? word3 opens with B
      expect(s.phase, GamePhase.gameOver);
      expect(s.isOver, isTrue);
      // A won words 0 and 2, B won words 1 and 3 -> 10-10 tie.
      expect(s.scoreA, 10);
      expect(s.scoreB, 10);
      expect(s.winningTeam, isNull); // tie
    });

    test('a clear winner is reported', () {
      var s = _startGame();
      // Word 0 (Team A): A guesses right -> A +5
      s = _guessCorrect(s);
      // Word 1 (Team B): B fails, A steals -> A scores again
      s = MatchEngine.submitClue(s, 'hint');
      s = MatchEngine.submitGuess(s, 'wrong'); // B wrong -> steal to A
      s = MatchEngine.submitClue(s, 'hint');
      s = MatchEngine.submitGuess(s, s.secretWord); // A right (value 4)
      s = MatchEngine.nextWord(s); // off the resolved beat -> halftime
      expect(s.phase, GamePhase.halftime);
      s = MatchEngine.beginSecondHalf(s);
      s = _guessCorrect(s); // word2 Team A -> A
      s = _guessCorrect(s); // word3 Team B -> B
      expect(s.isOver, isTrue);
      expect(s.winningTeam, 'A');
      expect(s.scoreA, greaterThan(s.scoreB));
    });
  });

  group('guarding invalid actions', () {
    test('guessing before a clue is a no-op', () {
      final s = _startGame();
      final same = MatchEngine.submitGuess(s, 'early');
      expect(identical(same, s), isTrue);
    });

    test('empty clue/guess is ignored', () {
      var s = _startGame();
      final afterEmptyClue = MatchEngine.submitClue(s, '   ');
      expect(identical(afterEmptyClue, s), isTrue);
      s = MatchEngine.submitClue(s, 'ok');
      final afterEmptyGuess = MatchEngine.submitGuess(s, '');
      expect(identical(afterEmptyGuess, s), isTrue);
    });

    test('beginSecondHalf only works at halftime', () {
      final s = _startGame();
      expect(identical(MatchEngine.beginSecondHalf(s), s), isTrue);
    });

    test('nextWord is a no-op at halftime (cannot skip to game over)', () {
      var s = _startGame();
      s = _guessCorrect(s);
      s = _guessCorrect(s);
      expect(s.phase, GamePhase.halftime);
      final stuck = MatchEngine.nextWord(s);
      expect(identical(stuck, s), isTrue);
      expect(stuck.phase, GamePhase.halftime);
    });
  });

  group('WordBank', () {
    test('deals the requested number of distinct words', () {
      final dealt = WordBank.deal(8, random: Random(1));
      expect(dealt, hasLength(8));
      expect(dealt.toSet(), hasLength(8));
    });

    test('never runs short even if more than the bank is requested', () {
      final huge = WordBank.deal(WordBank.words.length + 5, random: Random(2));
      expect(huge, hasLength(WordBank.words.length + 5));
    });
  });
}
