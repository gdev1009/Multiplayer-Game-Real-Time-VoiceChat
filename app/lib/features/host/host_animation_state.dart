import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import 'host_actions.dart';

/// High-level announcer states for the welcome / gameplay flow.
enum HostAnimationState {
  idle,
  entering,
  welcome,
  speaking,
  excited,
  waiting,
}

/// Snapshot of all layer values for one animation frame (immutable, cheap).
class HostAnimationFrame {
  const HostAnimationFrame({
    required this.state,
    required this.bodyAsset,
    required this.mouthViseme,
    required this.showMouthOverlay,
    required this.blinkAsset,
    required this.headRotationRad,
    required this.eyebrowRaise,
    required this.bodyOffset,
    required this.bodyScale,
    required this.shoulderSway,
  });

  final HostAnimationState state;
  final String bodyAsset;
  final String mouthViseme;
  final bool showMouthOverlay;
  final String? blinkAsset;
  final double headRotationRad;
  final double eyebrowRaise;
  final Offset bodyOffset;
  final double bodyScale;
  final double shoulderSway;

  static const idle = HostAnimationFrame(
    state: HostAnimationState.idle,
    bodyAsset: 'assets/images/host/host-idle.png',
    mouthViseme: 'closed',
    showMouthOverlay: false,
    blinkAsset: null,
    headRotationRad: 0,
    eyebrowRaise: 0,
    bodyOffset: Offset.zero,
    bodyScale: 1,
    shoulderSway: 0,
  );
}

/// Resolves game + audio context → [HostAnimationState].
abstract final class HostStateResolver {
  static HostAnimationState resolve({
    required MatchState state,
    required bool voicePlaying,
    required bool introPlaying,
    required HostAction stickyAction,
    required bool inOpeningBeat,
  }) {
    if (stickyAction == HostAction.correct ||
        stickyAction == HostAction.winner ||
        stickyAction == HostAction.reveal) {
      return HostAnimationState.excited;
    }

    // Red-flag beat — present, not "excited cheer".
    if (stickyAction == HostAction.wrong) {
      return voicePlaying
          ? HostAnimationState.speaking
          : HostAnimationState.waiting;
    }

    if (introPlaying && inOpeningBeat && !voicePlaying) {
      return HostAnimationState.entering;
    }

    if ((introPlaying || stickyAction == HostAction.welcome) && inOpeningBeat) {
      return voicePlaying
          ? HostAnimationState.speaking
          : HostAnimationState.welcome;
    }

    if (voicePlaying) return HostAnimationState.speaking;

    if (state.isTurnActive) return HostAnimationState.waiting;

    if (stickyAction == HostAction.welcome || inOpeningBeat) {
      return HostAnimationState.welcome;
    }

    return HostAnimationState.idle;
  }
}
