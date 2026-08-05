import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/game_engine.dart';
import 'package:match_word/features/host/host_actions.dart';

void main() {
  const names = {'A1': 'Sunny', 'A2': 'Walter', 'B1': 'Rosa', 'B2': 'Mabel'};
  final words = [
    'Flower',
    'Slipper',
    'Clock',
    'Robin',
    'Sandwich',
    'Quilt',
    'Holiday',
    'Garden',
  ];

  MatchState start() => MatchEngine.start(
        words: words,
        names: names,
        config: const MatchConfig(wordsPerHalf: 4),
      );

  test('every HostAction has transparent PNG frames', () {
    for (final action in HostAction.values) {
      final frames = HostActions.framesFor(action);
      expect(frames, hasLength(HostActions.frameCount));
      for (final asset in frames) {
        expect(asset, startsWith('assets/images/host/actions/frames/'));
        expect(asset, endsWith('.png'));
      }
    }
  });

  test('kickoff uses welcome wave', () {
    expect(HostActions.forState(start()), HostAction.welcome);
  });

  test('active turn uses listening', () {
    final clued = MatchEngine.submitClue(start(), 'Petals');
    expect(HostActions.forState(clued), HostAction.listening);
  });

  test('correct guess uses green flag', () {
    final clued = MatchEngine.submitClue(start(), 'Petals');
    final guessed = MatchEngine.submitGuess(clued, 'Flower');
    expect(guessed.lastOutcome, WordOutcome.guessed);
    expect(HostActions.forState(guessed), HostAction.correct);
  });

  test('wrong guess / steal uses red flag', () {
    final clued = MatchEngine.submitClue(start(), 'Petals');
    final stolen = MatchEngine.submitGuess(clued, 'Wrongword');
    expect(stolen.lastOutcome, WordOutcome.wrong);
    expect(HostActions.forState(stolen), HostAction.wrong);
  });

  test('red flag still resolves when lastOutcome was cleared (legacy server)', () {
    final clued = MatchEngine.submitClue(start(), 'Petals');
    final stolen = MatchEngine.submitGuess(clued, 'Wrongword');
    final legacy = stolen.copyWith(lastOutcome: WordOutcome.none);
    expect(HostActions.forState(legacy), HostAction.wrong);
    final reclued = MatchEngine.submitClue(legacy, 'Fresh');
    expect(HostActions.forState(reclued), HostAction.listening);
  });

  test('reveal uses golden card', () {
    var s = start();
    for (var i = 0; i < 20 && s.lastOutcome != WordOutcome.revealed; i++) {
      if (s.step == TurnStep.awaitingClue) {
        s = MatchEngine.submitClue(s, 'Hint$i');
      } else if (s.step == TurnStep.awaitingGuess) {
        s = MatchEngine.submitGuess(s, 'Nope$i');
      } else {
        break;
      }
    }
    expect(s.lastOutcome, WordOutcome.revealed);
    expect(HostActions.forState(s), HostAction.reveal);
  });

  test('game over uses winner announce', () {
    var s = start();
    for (var i = 0; i < 40 && !s.isOver; i++) {
      if (s.isHalftime) {
        s = MatchEngine.beginSecondHalf(s);
        continue;
      }
      if (s.step == TurnStep.resolved) {
        s = MatchEngine.nextWord(s);
        continue;
      }
      if (s.step == TurnStep.awaitingClue) {
        s = MatchEngine.submitClue(s, 'Hint');
      } else if (s.step == TurnStep.awaitingGuess) {
        s = MatchEngine.submitGuess(s, s.secretWord);
      }
    }
    expect(s.isOver, isTrue);
    expect(HostActions.forState(s), HostAction.winner);
  });
}
