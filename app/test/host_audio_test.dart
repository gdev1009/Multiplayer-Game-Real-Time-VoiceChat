import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/game_engine.dart';
import 'package:match_word/features/host/host_audio.dart';

/// Plays a whole match with the engine, collecting the audio cues each
/// transition fires — this is how the host "narrates" the game (Milestone 6).
void main() {
  const names = {'A1': 'Sunny', 'A2': 'Walter', 'B1': 'Rosa', 'B2': 'Mabel'};
  // 8 words; teams alternate who opens (A on even indices, B on odd).
  final words = ['Flower', 'Slipper', 'Clock', 'Robin', 'Sandwich', 'Quilt',
      'Holiday', 'Garden',];

  MatchState start() =>
      MatchEngine.start(words: words, names: names, config: const MatchConfig());

  group('HostAudio.soundsFor', () {
    test('every cue maps to at least one effect and a valid theme', () {
      for (final cue in SoundCue.values) {
        final sounds = HostAudio.soundsFor(cue);
        expect(sounds.effects, isNotEmpty, reason: '$cue has no effect');
        for (final e in sounds.effects) {
          expect(e, startsWith('audio/'));
        }
        if (sounds.voice != null) {
          expect(sounds.voice, startsWith('audio/voice/'));
        }
      }
      expect(HostAudio.themeMusic, 'audio/theme.mp3');
    });

    test('game start opens with the cue-and-prize bed before Guy speaks', () {
      final s = HostAudio.soundsFor(SoundCue.gameStart);
      expect(s.music, isNull); // looping theme starts after the welcome
      expect(s.effects, contains(HostAudio.openingBed));
      expect(HostAudio.openingBedDuration.inSeconds, inInclusiveRange(10, 15));
    });

    test('winner stops the music and plays applause', () {
      final s = HostAudio.soundsFor(SoundCue.winner);
      expect(s.stopMusic, isTrue);
      expect(s.effects, contains('audio/applause.mp3'));
    });

    test('correct plays ding + cheer; steal plays buzzer', () {
      final ok = HostAudio.soundsFor(SoundCue.correct);
      expect(ok.effects, contains('audio/ding.mp3'));
      expect(ok.effects, contains('audio/cheer.mp3'));
      final bad = HostAudio.soundsFor(SoundCue.steal);
      expect(bad.effects, contains('audio/buzzer.mp3'));
    });

    test('disconnect is flagged as an alarm (plays even when muted)', () {
      final s = HostAudio.soundsFor(SoundCue.disconnect);
      expect(s.isAlarm, isTrue);
      expect(s.stopMusic, isTrue);
      expect(s.effects, containsAll(['audio/alert.mp3', 'audio/awooga.mp3']));
    });
  });

  group('HostAudio.cuesForTransition', () {
    test('the very first state opens the show', () {
      expect(HostAudio.cuesForTransition(null, start()),
          [SoundCue.gameStart],);
    });

    test('a correct guess fires the correct cue once', () {
      final s0 = start();
      final clued = MatchEngine.submitClue(s0, 'Petals');
      final guessed = MatchEngine.submitGuess(clued, 'Flower');
      expect(guessed.lastOutcome, WordOutcome.guessed);
      expect(HostAudio.cuesForTransition(clued, guessed),
          contains(SoundCue.correct),);
    });

    test('a wrong guess (steal) fires the steal cue', () {
      final s0 = start(); // Team A opens word 0
      final clued = MatchEngine.submitClue(s0, 'Petals');
      final stolen = MatchEngine.submitGuess(clued, 'Wrongword');
      // Control passed to Team B, still awaiting a clue → a steal.
      expect(stolen.cluingTeam, isNot(clued.cluingTeam));
      expect(HostAudio.cuesForTransition(clued, stolen),
          contains(SoundCue.steal),);
    });

    test('dealing the next word fires roundStart, not a steal', () {
      final s0 = start();
      final clued = MatchEngine.submitClue(s0, 'Petals');
      final resolved = MatchEngine.submitGuess(clued, 'Flower');
      final next = MatchEngine.nextWord(resolved);
      expect(next.wordIndex, 1);
      final cues = HostAudio.cuesForTransition(resolved, next);
      expect(cues, contains(SoundCue.roundStart));
      expect(cues, isNot(contains(SoundCue.steal)));
    });

    test('entering halftime fires the halftime cue exactly once', () {
      var s = start();
      // Play the 4 first-half words, each guessed correctly, then advance.
      for (var i = 0; i < 4; i++) {
        s = MatchEngine.submitClue(s, 'clue');
        s = MatchEngine.submitGuess(s, s.secretWord);
        final before = s;
        s = MatchEngine.nextWord(s);
        if (s.isHalftime) {
          expect(HostAudio.cuesForTransition(before, s),
              contains(SoundCue.halftime),);
        }
      }
      expect(s.isHalftime, isTrue);
    });

    test('the finale fires the winner cue once', () {
      var s = start();
      MatchState? prev;
      // Drive a full game: clue+correct each word, advancing through halftime.
      while (!s.isOver) {
        if (s.isHalftime) {
          prev = s;
          s = MatchEngine.beginSecondHalf(s);
          continue;
        }
        if (s.isResolved) {
          prev = s;
          s = MatchEngine.nextWord(s);
          continue;
        }
        s = MatchEngine.submitClue(s, 'clue');
        prev = s;
        s = MatchEngine.submitGuess(s, s.secretWord);
        if (s.isResolved) {
          prev = s;
          s = MatchEngine.nextWord(s);
        }
      }
      expect(s.isOver, isTrue);
      expect(HostAudio.cuesForTransition(prev, s), contains(SoundCue.winner));
    });
  });
}
