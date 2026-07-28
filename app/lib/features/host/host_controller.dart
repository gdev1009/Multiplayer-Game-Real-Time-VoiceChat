import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'assets/host_assets.dart';
import 'facial_animation.dart';
import 'host_actions.dart';
import 'host_animation_state.dart';

/// Announcer animation brain — full-frame talk poses (natural mouths, no overlay).
class HostAnimationController extends ChangeNotifier {
  HostAnimationController();

  final WelcomeTalkAnimator _talk = WelcomeTalkAnimator();
  final FacialAnimator _face = FacialAnimator();

  HostAnimationFrame _frame = HostAnimationFrame.idle;
  HostAnimationFrame get frame => _frame;

  HostAnimationState _state = HostAnimationState.idle;
  HostAnimationState get state => _state;

  void reset() {
    _talk.reset();
    _face.reset(DateTime.now().millisecondsSinceEpoch / 1000.0);
    _frame = HostAnimationFrame.idle;
    _state = HostAnimationState.idle;
    notifyListeners();
  }

  void tick({
    required double nowSec,
    required double lifePhase,
    required HostAnimationState state,
    required HostAction stickyAction,
    required double mouthAmplitude,
    required bool voicePlaying,
    required double welcomeElapsedSec,
    required double actionElapsedSec,
    required bool inOpeningBeat,
  }) {
    _state = state;
    final speaking = state == HostAnimationState.speaking;
    final excited = state == HostAnimationState.excited;
    // Follow the voice clip itself — don't require speaking state first.
    final talking = voicePlaying;

    final bodyAsset = _talk.tick(
      nowSec: nowSec,
      amplitude: mouthAmplitude,
      talking: talking,
    );

    final motion = _face.bodyMotion(
      lifePhase: lifePhase,
      speaking: speaking || talking,
      excited: excited,
    );

    _frame = HostAnimationFrame(
      state: state,
      bodyAsset: bodyAsset,
      mouthViseme: talking ? 'open' : 'closed',
      showMouthOverlay: false,
      blinkAsset: null,
      headRotationRad: 0,
      eyebrowRaise: 0,
      bodyOffset: motion.offset,
      bodyScale: motion.scale,
      shoulderSway: motion.shoulderSway,
    );
  }
}
