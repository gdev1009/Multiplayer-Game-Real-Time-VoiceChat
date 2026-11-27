/// How sharp the computer stand-in players are.
///
/// Medium is the everyday table: they miss some answers, and some turns take
/// a little longer. Easy misses more and waits longer. Hard is sharper, and
/// still misses now and then.
enum ComputerPlayLevel {
  easy,
  medium,
  hard;

  static ComputerPlayLevel fromName(String? raw) {
    for (final level in values) {
      if (level.name == raw) return level;
    }
    return medium;
  }

  String get label => switch (this) {
        easy => 'Easy',
        medium => 'Medium',
        hard => 'Hard',
      };

  String get blurb => switch (this) {
        easy => 'They miss more often, and take their time.',
        medium =>
          'They get some answers wrong, and sometimes think a little longer.',
        hard => 'They are sharper, and still miss now and then.',
      };

  /// Share of guesses that name the secret word. A miss still answers the clue.
  double get guessAccuracy => switch (this) {
        easy => 0.50,
        medium => 0.68,
        hard => 0.88,
      };

  /// Pause before this seat speaks. The same turn always waits the same
  /// length, so a retry does not restart the clock.
  Duration pauseFor({
    required int wordIndex,
    required int exchangeCount,
    required bool guessing,
    required bool afterWrong,
  }) {
    final baseMs = switch (this) {
      easy => 12000,
      medium => 10000,
      hard => 8000,
    };
    final extraMs = switch (this) {
      easy => 3000,
      medium => 3000,
      hard => 2000,
    };
    final slowAt = switch (this) {
      easy => 0.50,
      medium => 0.38,
      hard => 0.20,
    };
    final roll = _roll(wordIndex, exchangeCount, guessing ? 1 : 0);
    final slow = roll < slowAt ? extraMs : 0;
    final read = afterWrong ? 2000 : 0;
    return Duration(milliseconds: baseMs + slow + read);
  }

  static double _roll(int wordIndex, int exchange, int kind) {
    var h = 2166136261 ^ (wordIndex * 131) ^ (exchange * 17) ^ (kind * 97);
    h = (h * 16777619) & 0x7fffffff;
    return (h % 1000) / 1000.0;
  }
}
