import 'dart:math' as math;

/// Viseme-based mouth animation driven by audio amplitude (0..1).
///
/// Maps amplitude → mouth shape with minimum hold times so speech reads
/// naturally instead of flickering like a GIF loop.
class MouthAnimator {
  String _current = 'closed';
  double _holdUntilSec = 0;

  String get current => _current;

  /// Advance mouth state. [talking] false → always closed.
  String tick({
    required double nowSec,
    required double amplitude,
    required bool talking,
  }) {
    if (!talking || amplitude < 0.05) {
      _current = 'closed';
      _holdUntilSec = 0;
      return _current;
    }

    if (nowSec < _holdUntilSec) return _current;

    final next = _pickViseme(amplitude, nowSec);

    if (_current != 'closed' && amplitude < 0.11) {
      _set('closed', nowSec, holdClosed: true);
    } else if (next != _current) {
      _set(next, nowSec, amplitude: amplitude);
    }
    return _current;
  }

  void reset() {
    _current = 'closed';
    _holdUntilSec = 0;
  }

  void _set(
    String viseme,
    double nowSec, {
    double amplitude = 0,
    bool holdClosed = false,
  }) {
    _current = viseme;
    final hold = holdClosed
        ? MouthTiming.holdClosedSec
        : MouthTiming.holdOpenSec + amplitude * 0.04;
    _holdUntilSec = nowSec + hold;
  }

  /// Amplitude-first viseme selection — openings start early so lipsync reads.
  String _pickViseme(double amp, double tSec) {
    if (amp < 0.05) return 'closed';
    if (amp < 0.12) return 'small';
    if (amp < 0.22) {
      return (tSec * 2.2).floor().isEven ? 'small' : 'medium';
    }
    if (amp < 0.34) {
      final i = (tSec * 2.0 + amp * 2).floor() % 3;
      return switch (i) {
        0 => 'medium',
        1 => 'teeth',
        _ => 'oo',
      };
    }
    if (amp < 0.50) {
      final i = (tSec * 1.9 + amp * 2).floor() % 4;
      return switch (i) {
        0 => 'teeth',
        1 => 'wide',
        2 => 'oh',
        _ => 'oo',
      };
    }
    return (tSec * 1.8).floor().isEven ? 'wide' : 'oh';
  }
}

/// Mouth timing — snappy enough to track speech, still readable on device.
abstract final class MouthTiming {
  static const holdClosedSec = 0.06;
  static const holdOpenSec = 0.08;
  static const maxSmoothing = 0.52;
  static const tickMs = 33;
}

/// Smooth raw audio amplitude before feeding [MouthAnimator].
double smoothMouthAmplitude(double current, double target) {
  return current + (target - current) * MouthTiming.maxSmoothing;
}

/// Synthetic syllable envelope when live metering is unavailable.
double syntheticAmplitude(double tSec) {
  // ~3.2–4.0 syllables/s — closer to natural chatter than a slow metronome.
  final rate = 3.2 + 0.8 * (0.5 + 0.5 * math.sin(tSec * 0.35));
  final cycle = (tSec * rate) % 1.0;
  if (cycle < 0.10) return 0;
  if (cycle < 0.20) return 0.28;
  if (cycle < 0.46) {
    return 0.42 + 0.28 * math.sin((cycle - 0.20) / 0.26 * math.pi);
  }
  if (cycle < 0.58) return 0.30;
  return 0;
}
