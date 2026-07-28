import '../host_actions.dart';
import '../mouth_animation.dart';

/// Asset paths + layout constants for Guy Smiley puppet layers.
abstract final class HostAssets {
  static const artWidth = 880.0;
  static const artHeight = 1348.0;

  // ---- Body -----------------------------------------------------------------
  static const bodyIdle = 'assets/images/host/host-idle.png';

  /// Welcome talk poses — lower face (mouth + cheeks/jaw) from natural talk
  /// sources; hair/suit/silhouette stay exact idle so color/height never jump.
  static const welcomeTalkDir = 'assets/images/host/talk/welcome';

  static const welcomeClosed = '$welcomeTalkDir/welcome_closed.png';
  static const welcomeMid = '$welcomeTalkDir/welcome_mid.png';
  static const welcomeWide = '$welcomeTalkDir/welcome_wide.png';
  static const welcomeWide2 = '$welcomeTalkDir/welcome_wide2.png';
  static const welcomeOpen = '$welcomeTalkDir/welcome_open.png';
  static const welcomeOo = '$welcomeTalkDir/welcome_oo.png';

  static const welcomeTalkPoses = [
    welcomeClosed,
    welcomeMid,
    welcomeWide,
    welcomeWide2,
    welcomeOpen,
    welcomeOo,
  ];

  static const bodyExplain =
      'assets/images/host/actions/frames/welcome-wave/00.png';

  static const bodyWelcome1 =
      'assets/images/host/actions/frames/welcome-wave/01.png';

  static const bodyWelcome2 =
      'assets/images/host/actions/frames/welcome-wave/02.png';

  static const bodyExcited =
      'assets/images/host/actions/frames/welcome-wave/02.png';

  static const welcomeFrames = [
    'assets/images/host/actions/frames/welcome-wave/00.png',
    'assets/images/host/actions/frames/welcome-wave/01.png',
    'assets/images/host/actions/frames/welcome-wave/02.png',
  ];

  // ---- Mouth visemes (idle gameplay lipsync) --------------------------------
  static const visemeDir = 'assets/images/host/mouth/visemes';

  static String viseme(String name) => '$visemeDir/$name.png';

  static const visemeNames = [
    'closed',
    'small',
    'medium',
    'teeth',
    'wide',
    'oh',
    'oo',
  ];

  // ---- Eyes -----------------------------------------------------------------
  static const eyesHalf = 'assets/images/host/mouth/blink_half.png';
  static const eyesClosed = 'assets/images/host/mouth/blink_closed.png';

  // Mouth patch ROI on idle art (normalised 0..1).
  static const mouthLeft = 0.361364;
  static const mouthTop = 0.222552;
  static const mouthWidth = 0.193182;
  static const mouthHeight = 0.092730;

  /// Precache idle + welcome talk poses (the live welcome path).
  static List<String> get allPrecache => [
        bodyIdle,
        ...welcomeTalkPoses,
        for (final v in visemeNames) viseme(v),
      ];

  /// True when the body PNG already has a drawn mouth (skip viseme overlay).
  static bool hasBakedMouth(String bodyAsset) {
    if (bodyAsset.contains('/talk/welcome/')) return true;
    if (bodyAsset.contains('-talk-')) return true;
    if (bodyAsset.contains('welcome-wave')) return true;
    if (bodyAsset.contains('green-flag-wave')) return true;
    if (bodyAsset.contains('red-flag-shake')) return true;
    if (bodyAsset.contains('golden-card-reveal')) return true;
    if (bodyAsset.contains('winner-announce')) return true;
    return false;
  }
}

/// Picks a welcome full-body talk pose from amplitude.
///
/// Tuned for fluid lipsync (short holds, early opens) so speech reads like a
/// continuous mouth — not a slow pose slideshow.
class WelcomeTalkAnimator {
  String _current = HostAssets.welcomeClosed;
  double _holdUntilSec = 0;

  String get current => _current;

  void reset() {
    _current = HostAssets.welcomeClosed;
    _holdUntilSec = 0;
  }

  /// [talking] false → closed smile welcome pose (still the presenting stance).
  String tick({
    required double nowSec,
    required double amplitude,
    required bool talking,
  }) {
    if (!talking) {
      _current = HostAssets.welcomeClosed;
      _holdUntilSec = 0;
      return _current;
    }

    if (amplitude < 0.04) {
      if (_current != HostAssets.welcomeClosed) {
        _set(HostAssets.welcomeClosed, nowSec, holdClosed: true);
      }
      return _current;
    }

    final target = _pick(amplitude, nowSec);

    // Emphasize peaks: break a hold early when loudness jumps a lot.
    final holding = nowSec < _holdUntilSec;
    if (holding) {
      final jump = _openness(target) - _openness(_current);
      if (jump < 2 && amplitude < 0.55) return _current;
    }

    if (target != _current) {
      // Prefer a one-step transition so mid ↔ open doesn't flash.
      final stepped = _stepToward(_current, target);
      _set(stepped, nowSec, amplitude: amplitude);
    } else if (!holding && amplitude < 0.10) {
      _set(HostAssets.welcomeClosed, nowSec, holdClosed: true);
    }
    return _current;
  }

  void _set(
    String asset,
    double nowSec, {
    double amplitude = 0,
    bool holdClosed = false,
  }) {
    _current = asset;
    final hold = holdClosed
        ? MouthTiming.holdClosedSec
        : MouthTiming.holdOpenSec + amplitude * 0.04;
    _holdUntilSec = nowSec + hold;
  }

  String _pick(double amp, double tSec) {
    // Open early and often — reference lipsync spends little time fully closed.
    if (amp < 0.08) return HostAssets.welcomeClosed;
    if (amp < 0.18) return HostAssets.welcomeMid;
    if (amp < 0.32) {
      return (tSec * 2.4).floor().isEven
          ? HostAssets.welcomeWide
          : HostAssets.welcomeWide2;
    }
    if (amp < 0.48) {
      return (tSec * 2.1).floor().isEven
          ? HostAssets.welcomeWide2
          : HostAssets.welcomeOpen;
    }
    return (tSec * 2.0).floor().isEven
        ? HostAssets.welcomeOpen
        : HostAssets.welcomeOo;
  }

  static int _openness(String asset) {
    if (asset == HostAssets.welcomeClosed) return 0;
    if (asset == HostAssets.welcomeMid) return 1;
    if (asset == HostAssets.welcomeWide || asset == HostAssets.welcomeWide2) {
      return 2;
    }
    return 3; // open / oo
  }

  static String _stepToward(String from, String to) {
    final a = _openness(from);
    final b = _openness(to);
    if ((b - a).abs() <= 1) return to;
    if (b > a) {
      return switch (a) {
        0 => HostAssets.welcomeMid,
        1 => HostAssets.welcomeWide,
        _ => HostAssets.welcomeOpen,
      };
    }
    return switch (a) {
      3 => HostAssets.welcomeWide,
      2 => HostAssets.welcomeMid,
      _ => HostAssets.welcomeClosed,
    };
  }
}

/// Senior-friendly action pose cycling (00 → 01 → 02 → 01).
abstract final class ActionPoseTiming {
  static const cycleSec = 2.8;
  static const excitedHoldSec = 1.8;

  static int frameIndex(double elapsedSec) {
    final t = elapsedSec < 0 ? 0.0 : elapsedSec;
    final u = (t % cycleSec) / cycleSec;
    final phase = u * 4.0;
    if (phase < 1) return 0;
    if (phase < 2) return 1;
    if (phase < 3) return 2;
    return 1;
  }

  static String talkLevel(double amplitude) {
    if (amplitude < 0.14) return 'closed';
    if (amplitude < 0.32) return 'mid';
    return 'open';
  }
}

String hostActionBodyAsset({
  required HostAction action,
  required double elapsedSec,
  required bool talking,
  required double mouthAmplitude,
}) {
  final frames = HostActions.framesFor(action);
  final idx =
      ActionPoseTiming.frameIndex(elapsedSec).clamp(0, frames.length - 1);
  final base = frames[idx];

  if (!talking || mouthAmplitude < 0.08) return base;
  if (action == HostAction.listening || action == HostAction.welcome) {
    return base;
  }

  final level = ActionPoseTiming.talkLevel(mouthAmplitude);
  if (level == 'closed' && idx != 1) return base;

  final stem = HostActions.frameStems[action]!;
  final pad = idx.toString().padLeft(2, '0');
  return 'assets/images/host/actions/frames/$stem/$pad-talk-$level.png';
}

enum HostBodyPose {
  idle,
  explain,
  welcome,
  excited,
}

String hostBodyAsset(HostBodyPose pose, {int welcomeFrameIndex = 0}) {
  return switch (pose) {
    HostBodyPose.idle => HostAssets.bodyIdle,
    HostBodyPose.explain => HostAssets.bodyExplain,
    HostBodyPose.welcome => HostAssets.welcomeFrames[
        welcomeFrameIndex.clamp(0, HostAssets.welcomeFrames.length - 1)],
    HostBodyPose.excited => HostAssets.bodyExcited,
  };
}
