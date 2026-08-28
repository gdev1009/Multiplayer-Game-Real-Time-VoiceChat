import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/game/game_engine.dart';
import 'package:match_word/features/host/host_audio.dart';

/// Plays a whole match with the engine, collecting the audio cues each
/// transition fires — this is how the host "narrates" the game (Milestone 6).
void main() {
  const names = {'A1': 'Sunny', 'A2': 'Walter', 'B1': 'Rosa', 'B2': 'Mabel'};
  // 16 words (8 per half); teams alternate who opens (A on even indices, B on odd).
  final words = [
    'Flower', 'Slipper', 'Clock', 'Robin', 'Sandwich', 'Quilt',
    'Holiday', 'Garden', 'Teapot', 'Mirror', 'Apple', 'Honey',
    'Puppy', 'Rainbow', 'Bicycle', 'Candle',
  ];

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
      expect(HostAudio.themeMusic, 'audio/theme_gentle.mp3');
    });

    test('the looping bed is the gentle one, not the brass theme', () {
      // Ronna (Aug 2026): "The music at the end of the game is pretty light and
      // easy going. I like that. I think we should use that throughout the
      // game" — and earlier, the horns "get annoying very quickly". The brass
      // theme is kept as an asset but must never be the loop.
      expect(HostAudio.themeMusic, isNot(HostAudio.brassTheme));
      for (final cue in SoundCue.values) {
        final sounds = HostAudio.soundsFor(cue);
        expect(sounds.music, isNot(HostAudio.brassTheme), reason: '$cue');
        expect(sounds.effects, isNot(contains(HostAudio.brassTheme)),
            reason: '$cue');
      }
    });

    test('game start opens with the cue-and-prize bed before Guy speaks', () {
      final s = HostAudio.soundsFor(SoundCue.gameStart);
      expect(s.music, isNull); // looping theme starts after the welcome
      expect(s.effects, contains(HostAudio.openingBed));
      expect(HostAudio.openingBedDuration.inSeconds, inInclusiveRange(10, 15));
    });

    test('winner keeps the theme running under a single crowd bed', () {
      final s = HostAudio.soundsFor(SoundCue.winner);
      expect(s.stopMusic, isFalse);
      expect(s.music, HostAudio.themeMusic);
      expect(s.effects, contains('audio/cheer.mp3'));
      expect(s.effects, isNot(contains('audio/applause.mp3')));
    });

    test('only the disconnect alarm stops the music', () {
      for (final cue in SoundCue.values) {
        expect(
          HostAudio.soundsFor(cue).stopMusic,
          cue == SoundCue.disconnect,
          reason: '$cue',
        );
      }
    });

    test('correct plays ding + cheer and keeps Guy voice asset', () {
      final ok = HostAudio.soundsFor(SoundCue.correct);
      expect(ok.effects, contains('audio/ding.mp3'));
      expect(ok.effects, contains('audio/cheer.mp3'));
      expect(ok.effects, isNot(contains('audio/applause.mp3')));
      expect(ok.voice, 'audio/voice/nice_guess.mp3');
    });

    test('steal uses a single long buzzer asset for 3s', () {
      final bad = HostAudio.soundsFor(SoundCue.steal);
      expect(bad.effects, equals(['audio/buzzer_long.mp3']));
      expect(bad.effects, isNot(contains('audio/cheer.mp3')));
      expect(HostAudio.buzzerHold, const Duration(seconds: 3));
    });

    test('reveal opens with a single long buzzer bed', () {
      final r = HostAudio.soundsFor(SoundCue.reveal);
      expect(r.effects.where((e) => e.contains('buzzer')).length, 1);
      expect(r.effects.first, 'audio/buzzer_long.mp3');
      expect(r.effects, contains('audio/reveal.mp3'));
    });

    test('winner plays one crowd bed after Guy', () {
      final w = HostAudio.soundsFor(SoundCue.winner);
      expect(w.effects, contains('audio/cheer.mp3'));
      expect(w.effects, isNot(contains('audio/applause.mp3')));
      expect(w.voice, isNotNull);
    });

    test('a timed-out steal uses a shorter buzz than a wrong guess', () {
      expect(HostAudio.timeoutBuzzerHold, lessThan(HostAudio.buzzerHold));
    });

    test('only correct and winner include crowd cheer/applause', () {
      for (final cue in SoundCue.values) {
        final effects = HostAudio.soundsFor(cue).effects;
        final hasCrowd = effects.any(
          (e) => e.contains('cheer') || e.contains('applause'),
        );
        if (cue == SoundCue.correct || cue == SoundCue.winner) {
          expect(hasCrowd, isTrue, reason: '$cue should cheer');
        } else {
          expect(hasCrowd, isFalse, reason: '$cue must not cheer');
        }
      }
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
      // Play the first-half words, each guessed correctly, then advance.
      for (var i = 0; i < const MatchConfig().wordsPerHalf; i++) {
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
