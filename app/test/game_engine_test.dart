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

  // Ronna (Aug 2026): "about 3/4 of the way through it gives the team that's
  // opposite to me two or three turns in a row."
  group('no team gets two turns in a row', () {
    test('the word after a steal opens with the team that did not steal', () {
      var s = _startGame(
        config: const MatchConfig(wordsPerHalf: 4, maxExchanges: 3),
      );
      expect(s.cluingTeam, 'A');
      // A clues, A's guesser misses -> B steals and wins the word.
      s = MatchEngine.submitClue(s, 'first');
      s = MatchEngine.submitGuess(s, 'wrong');
      expect(s.cluingTeam, 'B', reason: 'steal moves control to B');
      s = MatchEngine.submitClue(s, 'second');
      s = MatchEngine.submitGuess(s, s.secretWord);
      s = MatchEngine.nextWord(s);
      // B held the floor last, so A must open the next word.
      expect(s.cluingTeam, 'A');
    });

    test('a full game never gives one team two clue turns running', () {
      var s = _startGame(
        config: const MatchConfig(wordsPerHalf: 8, maxExchanges: 4),
      );
      // Every team that is handed the floor, in order, across a whole game.
      final turns = <String>[];
      var clue = 0;
      while (!s.isOver) {
        if (s.isHalftime) {
          s = MatchEngine.beginSecondHalf(s);
          continue;
        }
        turns.add(s.cluingTeam);
        s = MatchEngine.submitClue(s, 'clue${clue++}');
        // Miss every third word so steals are sprinkled through the game —
        // the pattern that produced Ronna's "two or three turns in a row".
        final miss = s.wordIndex % 3 == 0 && s.exchangeCount == 0;
        s = MatchEngine.submitGuess(s, miss ? 'nope' : s.secretWord);
        if (s.isResolved) s = MatchEngine.nextWord(s);
      }
      expect(turns.length, greaterThan(16), reason: 'played a full game');
      for (var i = 1; i < turns.length; i++) {
        expect(
          turns[i],
          isNot(turns[i - 1]),
          reason: 'team ${turns[i]} clued twice running at turn $i: $turns',
        );
      }
    });

    test('the second half opens with the team that did not close the first', () {
      var s = _startGame();
      s = _guessCorrect(s); // A wins word 0
      s = _guessCorrect(s); // B wins word 1 -> halftime
      expect(s.phase, GamePhase.halftime);
      expect(s.cluingTeam, 'B');
      s = MatchEngine.beginSecondHalf(s);
      expect(s.cluingTeam, 'A');
    });
  });

  // Ronna (Aug 2026): "the opposition is getting the same clue that we gave and
  // then we give that same clue again. They have to give a new clue every time."
  group('a clue may only be used once per word', () {
    test('re-using a clue on the same word is refused', () {
      var s = _startGame();
      s = MatchEngine.submitClue(s, 'Teapot');
      s = MatchEngine.submitGuess(s, 'wrong'); // steal to B
      expect(s.step, TurnStep.awaitingClue);
      final before = s;
      s = MatchEngine.submitClue(s, 'teapot'); // same clue, different case
      expect(s.step, TurnStep.awaitingClue, reason: 'still needs a new clue');
      expect(s.pendingClue, isNull);
      expect(s.feed.length, before.feed.length);
      expect(s.hostLine, contains('already been used'));
    });

    test('a different clue is accepted after a steal', () {
      var s = _startGame();
      s = MatchEngine.submitClue(s, 'Teapot');
      s = MatchEngine.submitGuess(s, 'wrong');
      s = MatchEngine.submitClue(s, 'Kettle');
      expect(s.step, TurnStep.awaitingGuess);
      expect(s.pendingClue, 'Kettle');
    });

    test('the same clue is fine again on a later word', () {
      var s = _startGame();
      s = _guessCorrect(s); // word 0 used the clue 'hint'
      expect(s.usedClues, isEmpty, reason: 'feed resets per word');
      s = MatchEngine.submitClue(s, 'hint');
      expect(s.step, TurnStep.awaitingGuess);
    });
  });

  // Ronna (Aug 2026): "the clue word needs to be visible to BOTH clue givers".
  group('both clue-givers see the word', () {
    test('either team\'s clue-giver counts, guessers never do', () {
      final s = _startGame();
      expect(s.isClueGiverRole('A1'), isTrue);
      expect(s.isClueGiverRole('B1'), isTrue);
      expect(s.isClueGiverRole('A2'), isFalse);
      expect(s.isClueGiverRole('B2'), isFalse);
      expect(s.isClueGiverRole(null), isFalse);
    });

    test('the halftime role switch moves who may see it', () {
      var s = _startGame();
      s = _guessCorrect(s);
      s = _guessCorrect(s);
      s = MatchEngine.beginSecondHalf(s);
      expect(s.isClueGiverRole('A2'), isTrue);
      expect(s.isClueGiverRole('B2'), isTrue);
      expect(s.isClueGiverRole('A1'), isFalse);
      expect(s.isClueGiverRole('B1'), isFalse);
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
      // A must offer a *new* clue — 'hint' is already spent on this word.
      s = MatchEngine.submitClue(s, 'another');
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

  group('a timed-out guess', () {
    test('hands the word to the other team when exchanges remain', () {
      var s = _startGame();
      s = MatchEngine.submitClue(s, 'hint');
      expect(s.step, TurnStep.awaitingGuess);
      final timed = MatchEngine.timeoutGuess(s);
      expect(timed.cluingTeam, 'B');
      expect(timed.step, TurnStep.awaitingClue);
      expect(timed.lastOutcome, WordOutcome.wrong);
      expect(timed.feed.last.text, 'TIME');
    });

    test('reveals the word on the final exchange', () {
      var s = _startGame(config: const MatchConfig(wordsPerHalf: 2, maxExchanges: 2));
      s = MatchEngine.submitClue(s, 'hint');
      s = MatchEngine.submitGuess(s, 'miss');
      s = MatchEngine.submitClue(s, 'hint2');
      expect(s.exchangeCount, 1);
      final timed = MatchEngine.timeoutGuess(s);
      expect(timed.lastOutcome, WordOutcome.revealed);
      expect(timed.step, TurnStep.resolved);
    });
  });

  group('WordBank', () {
    test('deals the requested number of distinct words', () {
      final dealt = WordBank.deal(16, random: Random(1));
      expect(dealt, hasLength(16));
      expect(dealt.toSet(), hasLength(16));
    });

    test('never runs short even if more than the bank is requested', () {
      final huge = WordBank.deal(WordBank.words.length + 5, random: Random(2));
      expect(huge, hasLength(WordBank.words.length + 5));
    });
  });
}
