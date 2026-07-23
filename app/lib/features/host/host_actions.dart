/// Guy Smiley studio poses — transparent PNG frame strips per host action.
library;

import '../game/game_engine.dart';

/// The six host action clips shipped under `assets/images/host/actions/`.
enum HostAction {
  /// Show open / kickoff / halftime address — waving hello.
  welcome,

  /// Default on-the-clock pose — listening for a clue or guess.
  listening,

  /// Correct guess — green flag wave.
  correct,

  /// Wrong guess / steal — red flag shake.
  wrong,

  /// Word revealed for no points — golden card.
  reveal,

  /// Match over — winner announcement.
  winner,
}

/// Resolves [MatchState] → host action clip for the studio host.
abstract final class HostActions {
  /// Stem folder under `assets/images/host/actions/frames/`.
  static const Map<HostAction, String> frameStems = {
    HostAction.welcome: 'welcome-wave',
    HostAction.listening: 'listening',
    HostAction.correct: 'green-flag-wave',
    HostAction.wrong: 'red-flag-shake',
    HostAction.reveal: 'golden-card-reveal',
    HostAction.winner: 'winner-announce',
  };

  static const int frameCount = 3;

  /// Transparent PNG frames (plate keyed out, suit protected).
  static List<String> framesFor(HostAction action) {
    final stem = frameStems[action]!;
    return List<String>.generate(
      frameCount,
      (i) =>
          'assets/images/host/actions/frames/$stem/${i.toString().padLeft(2, '0')}.png',
    );
  }

  static String webpFor(HostAction action) =>
      'assets/images/host/actions/${frameStems[action]!}.webp';

  static String gifFor(HostAction action) =>
      'assets/images/host/actions/${frameStems[action]!}.gif';

  static bool hasRecentWrongGuess(MatchState state) {
    for (var i = state.feed.length - 1; i >= 0; i--) {
      final e = state.feed[i];
      if (e.wordIndex != state.wordIndex) continue;
      if (e.kind == PlayKind.guess && e.correct == false) return true;
    }
    return false;
  }

  static HostAction forState(MatchState state) {
    if (state.isOver) return HostAction.winner;

    switch (state.lastOutcome) {
      case WordOutcome.guessed:
        return HostAction.correct;
      case WordOutcome.wrong:
        return HostAction.wrong;
      case WordOutcome.revealed:
        return HostAction.reveal;
      case WordOutcome.none:
        if (state.isTurnActive &&
            state.step == TurnStep.awaitingClue &&
            state.exchangeCount > 0 &&
            hasRecentWrongGuess(state) &&
            state.pendingClue == null) {
          return HostAction.wrong;
        }
        break;
    }

    if (state.isHalftime) return HostAction.welcome;
    if (state.wordIndex == 0 && state.feed.isEmpty) {
      return HostAction.welcome;
    }
    return HostAction.listening;
  }
}
