/// Match Word — core gameplay rules engine.
///
/// This is a **pure Dart** reducer: given a [MatchState] and a player action it
/// returns the next [MatchState]. It holds *all* the game rules — turn order,
/// the steal mechanic, the auto-reveal after a set number of exchanges, scoring,
/// and the first-half / halftime / second-half role switch — with no Flutter or
/// Supabase dependency, so the whole game can be unit-tested and the server
/// (see `supabase/migrations/0007_gameplay.sql`) can mirror the exact same
/// behaviour for its authoritative copy.
///
/// The game is a two-team word game (Password-style). Four players sit at two
/// desks — Team A (roles A1/A2) and Team B (roles B1/B2) — with the host in the
/// middle. For each secret word one team is "on the clock": that team's
/// **clue-giver** gives a one-word clue and their **guesser** makes one guess.
/// A correct guess scores the word's current value; a wrong guess hands control
/// to the other team (a *steal*). After [MatchConfig.maxExchanges] exchanges
/// with nobody guessing, the word is revealed for no points. At halftime the
/// clue-giver and guesser swap roles within each team.
library;

/// Which stage of the game we are in.
enum GamePhase { firstHalf, halftime, secondHalf, gameOver }

/// What the on-the-clock team is expected to do next. [resolved] is a short
/// beat after a word is decided (guessed or revealed) before the next word is
/// dealt, so the host can celebrate and everyone sees the result.
enum TurnStep { awaitingClue, awaitingGuess, resolved }

/// A single line in the shared play feed — a clue or a guess.
enum PlayKind { clue, guess }

/// How the most recent word ended (drives the host's line and the banner).
enum WordOutcome { none, guessed, revealed, wrong }

/// Immutable tuning for a match.
///
/// Defaults aim for a senior-friendly full game of about **20–25 minutes**
/// (Ronna Jul 2026): 8 words per half × 2 halves, with generous guess time.
class MatchConfig {
  const MatchConfig({
    this.wordsPerHalf = 8,
    this.maxExchanges = 5,
    this.wordValue = 5,
    this.guessSeconds = 18,
  })  : assert(wordsPerHalf > 0),
        assert(maxExchanges > 0),
        assert(wordValue > 0),
        assert(guessSeconds > 0);

  /// Number of secret words played in each half (~20–25 min full match).
  final int wordsPerHalf;

  /// Exchanges (clue + guess) allowed on a word before it auto-reveals.
  final int maxExchanges;

  /// Points a freshly dealt word is worth; it drops by one per failed exchange.
  final int wordValue;

  /// Seconds a guesser has before the buzzer (Ronna: ~15–20).
  final int guessSeconds;

  /// Total words across both halves.
  int get totalWords => wordsPerHalf * 2;
}

/// One entry in the shared, real-time play feed.
class PlayEntry {
  const PlayEntry({
    required this.kind,
    required this.team,
    required this.role,
    required this.playerName,
    required this.text,
    required this.wordIndex,
    this.correct,
  });

  final PlayKind kind;

  /// 'A' or 'B' — the team the speaker belongs to.
  final String team;

  /// 'A1' | 'A2' | 'B1' | 'B2' — the speaker's role label.
  final String role;

  final String playerName;
  final String text;
  final int wordIndex;

  /// For a guess: whether it matched the secret word. Null for a clue.
  final bool? correct;
}

/// A pure snapshot of an in-progress match. Everything the UI needs to render a
/// turn, and everything the engine needs to compute the next one, lives here.
class MatchState {
  const MatchState({
    required this.config,
    required this.words,
    required this.names,
    required this.phase,
    required this.wordIndex,
    required this.cluingTeam,
    required this.step,
    required this.exchangeCount,
    required this.scoreA,
    required this.scoreB,
    required this.pendingClue,
    required this.feed,
    required this.lastOutcome,
    required this.hostLine,
  });

  final MatchConfig config;

  /// The secret words for the whole match (length >= [MatchConfig.totalWords]).
  final List<String> words;

  /// Role → player display name, e.g. {'A1': 'Sunny', 'B2': 'Mabel'}.
  final Map<String, String> names;

  final GamePhase phase;

  /// Index into [words] of the word being played (or, at halftime/game-over,
  /// the next word to play).
  final int wordIndex;

  /// The team currently on the clock ('A' or 'B'). Both the clue-giver and the
  /// guesser belong to this team.
  final String cluingTeam;

  final TurnStep step;

  /// How many exchanges have been spent on the current word.
  final int exchangeCount;

  final int scoreA;
  final int scoreB;

  /// The clue awaiting a guess, or null when awaiting a clue.
  final String? pendingClue;

  /// The full shared play feed, oldest first.
  final List<PlayEntry> feed;

  /// How the previous word ended (for the banner/host line).
  final WordOutcome lastOutcome;

  /// A warm, senior-friendly line the host "says" about the current state.
  final String hostLine;

  /// True once the match is over.
  bool get isOver => phase == GamePhase.gameOver;

  /// True while the game pauses at halftime for the role switch.
  bool get isHalftime => phase == GamePhase.halftime;

  /// True on the short beat after a word is decided, before the next is dealt.
  bool get isResolved => step == TurnStep.resolved;

  /// Whether a clue or guess is currently expected from the on-the-clock team.
  bool get isTurnActive =>
      (phase == GamePhase.firstHalf || phase == GamePhase.secondHalf) &&
      step != TurnStep.resolved;

  /// The secret word in play (empty at halftime/game-over out of range).
  String get secretWord =>
      wordIndex >= 0 && wordIndex < words.length ? words[wordIndex] : '';

  /// Points the current word is worth right now (drops as exchanges are used).
  int get wordValue =>
      (config.wordValue - exchangeCount).clamp(1, config.wordValue);

  /// The clue-giver's role for the on-the-clock team, honouring the halftime
  /// switch (role "1" gives clues in the first half, role "2" in the second).
  String get clueGiverRole => MatchEngine.clueGiverRole(cluingTeam, phase);

  /// The guesser's role for the on-the-clock team.
  String get guesserRole => MatchEngine.guesserRole(cluingTeam, phase);

  String get clueGiverName => names[clueGiverRole] ?? 'Player $clueGiverRole';
  String get guesserName => names[guesserRole] ?? 'Player $guesserRole';

  /// 'A', 'B', or null for a tie — valid once [isOver].
  String? get winningTeam {
    if (scoreA == scoreB) return null;
    return scoreA > scoreB ? 'A' : 'B';
  }

  /// Human-friendly word counter, e.g. "Word 3 of 8".
  String get wordLabel {
    final shown = (wordIndex + 1).clamp(1, config.totalWords);
    return 'Word $shown of ${config.totalWords}';
  }

  MatchState copyWith({
    GamePhase? phase,
    int? wordIndex,
    String? cluingTeam,
    TurnStep? step,
    int? exchangeCount,
    int? scoreA,
    int? scoreB,
    Object? pendingClue = _noChange,
    List<PlayEntry>? feed,
    WordOutcome? lastOutcome,
    String? hostLine,
  }) {
    return MatchState(
      config: config,
      words: words,
      names: names,
      phase: phase ?? this.phase,
      wordIndex: wordIndex ?? this.wordIndex,
      cluingTeam: cluingTeam ?? this.cluingTeam,
      step: step ?? this.step,
      exchangeCount: exchangeCount ?? this.exchangeCount,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
      pendingClue:
          pendingClue == _noChange ? this.pendingClue : pendingClue as String?,
      feed: feed ?? this.feed,
      lastOutcome: lastOutcome ?? this.lastOutcome,
      hostLine: hostLine ?? this.hostLine,
    );
  }

  static const Object _noChange = Object();
}

/// Pure transition functions for a match. Every method returns a new
/// [MatchState]; none of them mutate their input.
class MatchEngine {
  const MatchEngine._();

  /// The team that opens a given word — teams alternate who starts.
  static String startingTeamForWord(int wordIndex) =>
      wordIndex.isEven ? 'A' : 'B';

  /// The clue-giver role for [team] in [phase] (role switch at halftime).
  static String clueGiverRole(String team, GamePhase phase) =>
      '$team${phase == GamePhase.secondHalf ? '2' : '1'}';

  /// The guesser role for [team] in [phase].
  static String guesserRole(String team, GamePhase phase) =>
      '$team${phase == GamePhase.secondHalf ? '1' : '2'}';

  /// Normalises text for a case/whitespace/punctuation-insensitive comparison
  /// (mirrors `mw_norm_word` in SQL so client + server grade the same way).
  static String normalize(String value) {
    final spaced = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return spaced.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  }

  /// Whether [guess] matches [word] after normalisation.
  static bool isCorrect(String guess, String word) =>
      normalize(guess) == normalize(word) && normalize(word).isNotEmpty;

  /// True when the guesser repeats the pending clue (a foul).
  static bool isClueFoul(String guess, String? pendingClue) =>
      pendingClue != null &&
      pendingClue.trim().isNotEmpty &&
      isCorrect(guess, pendingClue);

  /// Starts a new match. [words] must hold at least [MatchConfig.totalWords]
  /// entries; [names] maps each role (A1/A2/B1/B2) to a display name.
  static MatchState start({
    required List<String> words,
    required Map<String, String> names,
    MatchConfig config = const MatchConfig(),
  }) {
    assert(
      words.length >= config.totalWords,
      'need at least ${config.totalWords} words, got ${words.length}',
    );
    final team = startingTeamForWord(0);
    return MatchState(
      config: config,
      words: List.unmodifiable(words),
      names: Map.unmodifiable(names),
      phase: GamePhase.firstHalf,
      wordIndex: 0,
      cluingTeam: team,
      step: TurnStep.awaitingClue,
      exchangeCount: 0,
      scoreA: 0,
      scoreB: 0,
      pendingClue: null,
      feed: const [],
      lastOutcome: WordOutcome.none,
      hostLine: _clueLine(team, GamePhase.firstHalf, names),
    );
  }

  /// The on-the-clock clue-giver submits a one-word clue.
  static MatchState submitClue(MatchState state, String clue) {
    if (!state.isTurnActive || state.step != TurnStep.awaitingClue) {
      return state;
    }
    final text = clue.trim();
    if (text.isEmpty) return state;

    final entry = PlayEntry(
      kind: PlayKind.clue,
      team: state.cluingTeam,
      role: state.clueGiverRole,
      playerName: state.clueGiverName,
      text: text,
      wordIndex: state.wordIndex,
    );
    return state.copyWith(
      step: TurnStep.awaitingGuess,
      pendingClue: text,
      feed: [...state.feed, entry],
      lastOutcome: WordOutcome.none,
      hostLine: '${state.guesserName}, what is your guess?',
    );
  }

  /// Wrong-guess steal path when the guess clock expires (no typed guess).
  static MatchState timeoutGuess(MatchState state) {
    if (!state.isTurnActive || state.step != TurnStep.awaitingGuess) {
      return state;
    }
    // Calm beat may have already placed a TIME bubble — don't duplicate it.
    final hasTime = state.feed.isNotEmpty &&
        state.feed.last.kind == PlayKind.guess &&
        state.feed.last.role == state.guesserRole &&
        state.feed.last.wordIndex == state.wordIndex &&
        state.feed.last.text.trim().toUpperCase() == 'TIME';
    final feed = hasTime
        ? state.feed
        : [
            ...state.feed,
            PlayEntry(
              kind: PlayKind.guess,
              team: state.cluingTeam,
              role: state.guesserRole,
              playerName: state.guesserName,
              text: 'TIME',
              wordIndex: state.wordIndex,
              correct: false,
            ),
          ];
    final used = state.exchangeCount + 1;
    if (used >= state.config.maxExchanges) {
      return state.copyWith(
        exchangeCount: used,
        step: TurnStep.resolved,
        pendingClue: null,
        feed: feed,
        lastOutcome: WordOutcome.revealed,
        hostLine: 'Time’s up! The word was ${state.secretWord}. No points.',
      );
    }
    final nextTeam = state.cluingTeam == 'A' ? 'B' : 'A';
    return state.copyWith(
      cluingTeam: nextTeam,
      step: TurnStep.awaitingClue,
      exchangeCount: used,
      pendingClue: null,
      feed: feed,
      lastOutcome: WordOutcome.wrong,
      hostLine:
          'Time’s up! A steal! ${_clueLine(nextTeam, state.phase, state.names)}',
    );
  }

  /// The on-the-clock guesser submits a guess. Resolves the word (score / steal
  /// / auto-reveal) and advances the match.
  static MatchState submitGuess(MatchState state, String guess) {
    if (!state.isTurnActive || state.step != TurnStep.awaitingGuess) {
      return state;
    }
    final text = guess.trim();
    if (text.isEmpty) return state;

    // Repeating the clue is a foul — never scores, burns an exchange / steal.
    final foul = isClueFoul(text, state.pendingClue);
    final correct = !foul && isCorrect(text, state.secretWord);
    final entry = PlayEntry(
      kind: PlayKind.guess,
      team: state.cluingTeam,
      role: state.guesserRole,
      playerName: state.guesserName,
      text: text,
      wordIndex: state.wordIndex,
      correct: correct,
    );
    final feed = [...state.feed, entry];

    if (correct) {
      final gained = state.wordValue;
      final scoreA = state.scoreA + (state.cluingTeam == 'A' ? gained : 0);
      final scoreB = state.scoreB + (state.cluingTeam == 'B' ? gained : 0);
      final line = 'Team ${state.cluingTeam} guessed ${state.secretWord}! '
          '+$gained ${gained == 1 ? 'point' : 'points'}.';
      return state.copyWith(
        scoreA: scoreA,
        scoreB: scoreB,
        step: TurnStep.resolved,
        pendingClue: null,
        feed: feed,
        lastOutcome: WordOutcome.guessed,
        hostLine: line,
      );
    }

    // Wrong guess or foul — spend an exchange.
    final used = state.exchangeCount + 1;
    if (used >= state.config.maxExchanges) {
      final line = 'Time’s up! The word was ${state.secretWord}. No points.';
      return state.copyWith(
        exchangeCount: used,
        step: TurnStep.resolved,
        pendingClue: null,
        feed: feed,
        lastOutcome: WordOutcome.revealed,
        hostLine: line,
      );
    }

    // Steal — control passes to the other team for a fresh clue.
    final nextTeam = state.cluingTeam == 'A' ? 'B' : 'A';
    final stealLine = foul
        ? 'Foul! You can’t guess the clue. Steal! '
            '${_clueLine(nextTeam, state.phase, state.names)}'
        : 'A steal! ${_clueLine(nextTeam, state.phase, state.names)}';
    return state.copyWith(
      cluingTeam: nextTeam,
      step: TurnStep.awaitingClue,
      exchangeCount: used,
      pendingClue: null,
      feed: feed,
      lastOutcome: WordOutcome.wrong,
      hostLine: stealLine,
    );
  }

  /// Leaves halftime and deals the first word of the second half (with roles
  /// switched). A no-op outside halftime.
  static MatchState beginSecondHalf(MatchState state) {
    if (state.phase != GamePhase.halftime) return state;
    return _loadWord(state, state.wordIndex, GamePhase.secondHalf);
  }

  // --- internal helpers ------------------------------------------------------

  /// Advances from a resolved word to the next word, halftime, or game-over.
  /// Only valid on the [TurnStep.resolved] beat during an active half
  /// (a no-op at halftime / game-over so a double-tap cannot skip the break).
  static MatchState nextWord(MatchState state) {
    if (state.step != TurnStep.resolved) return state;
    if (state.phase != GamePhase.firstHalf &&
        state.phase != GamePhase.secondHalf) {
      return state;
    }
    return _advanceWord(state);
  }

  /// Ends the current word and moves to the next word, halftime, or game-over.
  static MatchState _advanceWord(MatchState state) {
    final next = state.wordIndex + 1;
    final config = state.config;

    if (next >= config.totalWords) {
      final winner = state.scoreA == state.scoreB
          ? null
          : (state.scoreA > state.scoreB ? 'A' : 'B');
      final line = winner == null
          ? 'It’s a tie — what a game! ${state.scoreA} to ${state.scoreB}.'
          : 'Team $winner wins ${state.scoreA > state.scoreB ? state.scoreA : state.scoreB}'
              ' to ${state.scoreA > state.scoreB ? state.scoreB : state.scoreA}!';
      return state.copyWith(
        phase: GamePhase.gameOver,
        wordIndex: next,
        step: TurnStep.awaitingClue,
        pendingClue: null,
        hostLine: line,
      );
    }

    if (next == config.wordsPerHalf) {
      // Reached halftime — pause for the role switch.
      return state.copyWith(
        phase: GamePhase.halftime,
        wordIndex: next,
        pendingClue: null,
        hostLine: 'Halftime! Teams, switch clue-giver and guesser. '
            'Score: ${state.scoreA} – ${state.scoreB}.',
      );
    }

    return _loadWord(state, next, state.phase);
  }

  /// Deals the word at [index] for [phase]: resets the turn, picks the opening
  /// team, and sets the host's clue prompt.
  static MatchState _loadWord(MatchState state, int index, GamePhase phase) {
    final team = startingTeamForWord(index);
    return state.copyWith(
      phase: phase,
      wordIndex: index,
      cluingTeam: team,
      step: TurnStep.awaitingClue,
      exchangeCount: 0,
      pendingClue: null,
      lastOutcome: WordOutcome.none,
      // Drop prior-word feed so stage bubbles cannot reappear after "Next word".
      feed: const [],
      hostLine: _clueLine(team, phase, state.names),
    );
  }

  /// The host's prompt asking a team's clue-giver for a clue.
  static String _clueLine(String team, GamePhase phase, Map<String, String> names) {
    final role = clueGiverRole(team, phase);
    final name = names[role] ?? 'Player $role';
    return '$name, give a one-word clue.';
  }
}
