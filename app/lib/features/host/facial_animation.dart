import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'assets/host_assets.dart';
import 'host_animation_state.dart';

/// Blink phases for the eyes layer.
enum BlinkPhase { open, halfDown, closed, halfUp }

/// Manages blink, head, eyebrow, and breathing motion.
class FacialAnimator {
  FacialAnimator({math.Random? random}) : _rng = random ?? math.Random();

  final math.Random _rng;

  BlinkPhase _blink = BlinkPhase.open;
  double _blinkUntilSec = 0;
  double _nextBlinkAtSec = 0;
  bool _scheduled = false;

  BlinkPhase get blinkPhase => _blink;

  String? get blinkAsset => switch (_blink) {
        BlinkPhase.open => null,
        BlinkPhase.halfDown || BlinkPhase.halfUp => HostAssets.eyesHalf,
        BlinkPhase.closed => HostAssets.eyesClosed,
      };

  void reset(double nowSec) {
    _blink = BlinkPhase.open;
    _blinkUntilSec = 0;
    _scheduleBlink(nowSec);
  }

  void _scheduleBlink(double nowSec) {
    const span =
        FacialTiming.blinkMaxIntervalSec - FacialTiming.blinkMinIntervalSec;
    _nextBlinkAtSec =
        nowSec + FacialTiming.blinkMinIntervalSec + _rng.nextDouble() * span;
    _scheduled = true;
  }

  void tickBlink(double nowSec) {
    if (!_scheduled) {
      _scheduleBlink(nowSec);
    }
    if (_blink != BlinkPhase.open) {
      if (nowSec < _blinkUntilSec) return;
      switch (_blink) {
        case BlinkPhase.halfDown:
          _blink = BlinkPhase.closed;
          _blinkUntilSec = nowSec + FacialTiming.blinkClosedSec;
        case BlinkPhase.closed:
          _blink = BlinkPhase.halfUp;
          _blinkUntilSec = nowSec + FacialTiming.blinkHalfUpSec;
        case BlinkPhase.halfUp:
          _blink = BlinkPhase.open;
          _scheduleBlink(nowSec);
        case BlinkPhase.open:
          break;
      }
      return;
    }
    if (nowSec >= _nextBlinkAtSec) {
      _blink = BlinkPhase.halfDown;
      _blinkUntilSec = nowSec + FacialTiming.blinkHalfDownSec;
    }
  }

  double headRotation({
    required double nowSec,
    required double welcomeLookBias,
    required bool speaking,
    required double mouthAmplitude,
  }) {
    final drift = math.sin(nowSec * 0.28) * FacialTiming.headIdleRad;
    final nod = speaking && mouthAmplitude > 0.38
        ? math.sin(nowSec * math.pi * 1.1) * FacialTiming.headNodRad
        : 0.0;
    return (welcomeLookBias + drift + nod).clamp(-0.052, 0.052);
  }

  double eyebrowRaise({
    required bool excited,
    required bool speaking,
    required double mouthAmplitude,
    required double nowSec,
  }) {
    if (excited) return 0.55 + 0.15 * math.sin(nowSec * 2.0);
    if (speaking && mouthAmplitude > 0.45) {
      return 0.25 + 0.15 * math.sin(nowSec * 1.8);
    }
    return 0;
  }

  ({Offset offset, double scale, double shoulderSway}) bodyMotion({
    required double lifePhase,
    required bool speaking,
    required bool excited,
  }) {
    // Size stays locked — tiny idle breath only (speaking must not zoom/bob).
    final energy = excited ? 1.1 : 1.0;
    final bob = math.sin(lifePhase * math.pi) * FacialTiming.breathBobPx * energy;
    final sway =
        math.sin(lifePhase * math.pi * 0.9) * FacialTiming.swayPx * energy;
    return (
      offset: Offset(sway * 0.35, -bob * 0.35),
      scale: 1.0,
      shoulderSway: sway * 0.35,
    );
  }

  /// Welcome look: left → center → right → center (slow, ~±2°).
  static double welcomeHeadLook(double elapsedSec, bool inOpeningBeat) {
    if (!inOpeningBeat || elapsedSec > WelcomeTimeline.returnIdle + 2.0) {
      return 0;
    }
    if (elapsedSec < 1.0) return 0;
    if (elapsedSec < 2.2) return -FacialTiming.headLookRad;
    if (elapsedSec < 3.6) return 0;
    if (elapsedSec < 5.0) return FacialTiming.headLookRad;
    if (elapsedSec < 6.5) return -FacialTiming.headLookRad * 0.5;
    return 0;
  }
}

/// Face / breath timing — slow announcer pace.
abstract final class FacialTiming {
  static const breathCycleMs = 3200;
  static const breathBobPx = 2.2;
  static const swayPx = 1.4;

  static const headIdleRad = 0.026;
  static const headNodRad = 0.035;
  static const headLookRad = 0.035;

  static const blinkMinIntervalSec = 4.0;
  static const blinkMaxIntervalSec = 7.5;
  static const blinkHalfDownSec = 0.07;
  static const blinkClosedSec = 0.09;
  static const blinkHalfUpSec = 0.07;
}

/// One-shot welcome stage script (seconds from welcome beat start).
///
/// Welcome is idle + mouth only — no gesture wave choreography.
abstract final class WelcomeTimeline {
  static const appearEnd = 0.0;
  static const micEnd = 0.0;
  static const gestureStart = 0.0;
  static const gestureEnd = 0.0;
  static const returnIdle = 0.0;
}

/// Always idle — wave / motion-line frames are not used for welcome.
({HostBodyPose pose, int welcomeFrame}) welcomeBody({
  required double elapsedSec,
  required HostAnimationState state,
  required bool inOpeningBeat,
}) {
  return (pose: HostBodyPose.idle, welcomeFrame: 0);
}
