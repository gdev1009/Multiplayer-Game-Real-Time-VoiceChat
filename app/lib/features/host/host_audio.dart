/// Match Word — host + audio cue model.
///
/// This is a **pure Dart** mapping layer with no Flutter or plugin dependency,
/// so the "which sound plays when" logic can be unit-tested in isolation. The
/// concrete playback lives in [AudioController] (services/audio_controller.dart)
/// which turns each [SoundCue] into actual `audioplayers` calls.
///
/// Every cue names an announcer/effect sound (always present, developer-made,
/// royalty-free — see `tools/generate_audio_cues.py`) and, optionally, a Guy
/// Smiley **voice** line. Voice-over clips are a pure drop-in by filename (see
/// `assets/audio/voice/README.md`); until one is present it simply no-ops while
/// the host lipsync animation (envelope-driven mouth overlay) and the effect
/// sound still play.
library;

import '../game/game_engine.dart';

/// A single moment in the show the host reacts to. Ordering is by game flow.
enum SoundCue {
  /// The show opens — announcer intro + rules. Plays once per game.
  gameStart,

  /// A fresh word is dealt and a player is put on the clock.
  roundStart,

  /// A correct guess — the crowd cheers.
  correct,

  /// A wrong guess hands the word to the other team (a steal).
  steal,

  /// The word ran out of exchanges and was revealed for no points.
  reveal,

  /// The halftime role switch.
  halftime,

  /// The winner is announced — applause and fanfare.
  winner,

  /// A player dropped — the disconnect alarm (ALERT + AWOOGA horn).
  disconnect,
}

/// The set of sounds a [SoundCue] triggers, resolved to asset paths.
///
/// [effects] are layered one-shots (they may overlap, e.g. cheer + ding).
/// [music] optionally (re)starts the looping background track.
/// [voice] is the optional host voice-over line (drop-in; no-ops if absent).
class CueSounds {
  const CueSounds({
    this.effects = const [],
    this.voice,
    this.music,
    this.stopMusic = false,
    this.isAlarm = false,
  });

  /// One-shot effect assets to fire (relative to the `assets/` root).
  final List<String> effects;

  /// Optional host voice-over asset (relative to the `assets/` root).
  final String? voice;

  /// Optional looping music asset to (re)start.
  final String? music;

  /// When true, stop the looping music (e.g. during the disconnect alarm).
  final bool stopMusic;

  /// When true this is the emergency alarm — always audible even if muted is
  /// *not* honoured for safety cues (the UI still shows the red flash).
  final bool isAlarm;
}

/// Static catalogue mapping each [SoundCue] to its concrete sounds, plus the
/// pure transition logic that decides which cues a state change should fire.
class HostAudio {
  const HostAudio._();

  static const String _sfx = 'audio';
  static const String _vox = 'audio/voice';

  /// The looping opening/underscore theme (after Guy's welcome).
  static const String themeMusic = '$_sfx/theme.mp3';

  /// Short game-show bed before Guy speaks (Ronna: ~10–15s).
  static const String openingBed = '$_sfx/opening_bed.mp3';

  /// How long to hold the opening bed before the welcome line.
  static const Duration openingBedDuration = Duration(milliseconds: 13000);

  /// Exact buzz length on wrong / timeout before Guy speaks.
  static const Duration buzzerHold = Duration(seconds: 3);

  /// Max cheer / applause bed after Guy speaks on correct / winner (≤8s).
  static const Duration crowdAfterVoiceMax = Duration(milliseconds: 8000);

  /// The concrete sounds for [cue].
  static CueSounds soundsFor(SoundCue cue) {
    switch (cue) {
      case SoundCue.gameStart:
        // Opening bed is played specially *before* Guy's welcome; looping
        // theme starts after he finishes (see AudioController.playCue).
        return const CueSounds(
          effects: [openingBed],
          voice: '$_vox/rules_intro.mp3',
        );
      case SoundCue.roundStart:
        return const CueSounds(
          effects: ['$_sfx/round_start.mp3'],
          voice: '$_vox/your_turn.mp3',
        );
      case SoundCue.correct:
        // Correct: ding → Guy confirms → crowd cheer (deferred in AudioController).
        return const CueSounds(
          effects: [
            '$_sfx/ding.mp3',
            '$_sfx/cheer.mp3',
          ],
          voice: '$_vox/nice_guess.mp3',
        );
      case SoundCue.steal:
        // Wrong guess / timed-out steal — one continuous long buzzer, then Guy.
        return const CueSounds(
          effects: ['$_sfx/buzzer_long.mp3'],
          voice: '$_vox/good_try.mp3',
        );
      case SoundCue.reveal:
        // Timed out with no points — long buzzer, then reveal sting + Guy.
        return const CueSounds(
          effects: [
            '$_sfx/buzzer_long.mp3',
            '$_sfx/reveal.mp3',
          ],
          voice: '$_vox/word_revealed.mp3',
        );
      case SoundCue.halftime:
        return const CueSounds(
          effects: ['$_sfx/halftime.mp3'],
          voice: '$_vox/halftime.mp3',
        );
      case SoundCue.winner:
        // Game end: fanfare → Guy wrap-up → crowd (cheer deferred in AudioController).
        return const CueSounds(
          effects: [
            '$_sfx/winner.mp3',
            '$_sfx/cheer.mp3',
            '$_sfx/applause.mp3',
          ],
          voice: '$_vox/winner.mp3',
          // Ronna (Aug 2026): the theme and the crowd should send the show off,
          // so the music keeps running under the wrap-up instead of cutting.
          music: themeMusic,
        );
      case SoundCue.disconnect:
        return const CueSounds(
          effects: ['$_sfx/alert.mp3', '$_sfx/awooga.mp3'],
          voice: '$_vox/disconnect.mp3',
          stopMusic: true,
          isAlarm: true,
        );
    }
  }

  /// The cues a transition from [prev] to [next] should fire, in play order.
  ///
  /// A null [prev] means the match just began, so the show opens. This is a
  /// pure function of the two states — no side effects — so it is unit-tested
  /// directly (see test/host_audio_test.dart).
  static List<SoundCue> cuesForTransition(MatchState? prev, MatchState next) {
    // The show opens on the very first state.
    if (prev == null) {
      return const [SoundCue.gameStart];
    }

    final cues = <SoundCue>[];

    // Winner fanfare — fire once when the game ends.
    if (next.isOver && !prev.isOver) {
      cues.add(SoundCue.winner);
      return cues;
    }

    // Halftime — fire once on entering the break.
    if (next.isHalftime && !prev.isHalftime) {
      cues.add(SoundCue.halftime);
      return cues;
    }

    // Word outcomes — a correct guess, a miss/steal, or a reveal.
    if (next.lastOutcome == WordOutcome.guessed &&
        prev.lastOutcome != WordOutcome.guessed) {
      cues.add(SoundCue.correct);
    } else if (next.lastOutcome == WordOutcome.wrong &&
        prev.lastOutcome != WordOutcome.wrong) {
      cues.add(SoundCue.steal);
    } else if (next.lastOutcome == WordOutcome.revealed &&
        prev.lastOutcome != WordOutcome.revealed) {
      cues.add(SoundCue.reveal);
    }

    // A steal — control passed to the other team on a wrong guess (still live).
    // Prefer the lastOutcome cue above; keep this as a fallback when the server
    // clears last_outcome before the client sees 'wrong'.
    final stole = next.lastOutcome != WordOutcome.wrong &&
        next.step == TurnStep.awaitingClue &&
        !next.isResolved &&
        (next.phase == GamePhase.firstHalf ||
            next.phase == GamePhase.secondHalf) &&
        next.exchangeCount > prev.exchangeCount &&
        next.cluingTeam != prev.cluingTeam;
    if (stole) cues.add(SoundCue.steal);

    // A fresh word/turn was dealt (new word, or the second half kicked off).
    final newTurn = next.step == TurnStep.awaitingClue &&
        !next.isResolved &&
        (next.phase == GamePhase.firstHalf ||
            next.phase == GamePhase.secondHalf) &&
        !stole &&
        (next.wordIndex != prev.wordIndex ||
            (prev.isHalftime && !next.isHalftime));
    if (newTurn) cues.add(SoundCue.roundStart);

    return cues;
  }
}
