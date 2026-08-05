import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/host/assets/host_assets.dart';
import 'package:match_word/features/host/facial_animation.dart';
import 'package:match_word/features/host/host_actions.dart';
import 'package:match_word/features/host/host_animation_state.dart';
import 'package:match_word/features/host/host_controller.dart';
import 'package:match_word/features/host/mouth_animation.dart';
import 'package:match_word/features/game/game_engine.dart';

void main() {
  group('ActionPoseTiming', () {
    test('cycles 00 → 01 → 02 → 01 slowly', () {
      expect(ActionPoseTiming.frameIndex(0.0), 0);
      expect(ActionPoseTiming.frameIndex(0.5), 0);
      expect(ActionPoseTiming.frameIndex(1.0), 1);
      expect(ActionPoseTiming.frameIndex(1.8), 2);
      expect(ActionPoseTiming.frameIndex(2.5), 1);
    });
  });

  group('MouthAnimator', () {
    test('rests closed when not talking', () {
      final anim = MouthAnimator();
      expect(
        anim.tick(nowSec: 1, amplitude: 0, talking: false),
        'closed',
      );
    });

    test('opens while talking', () {
      final anim = MouthAnimator();
      final v = anim.tick(nowSec: 2, amplitude: 0.45, talking: true);
      expect(v, isNot('closed'));
      expect(HostAssets.visemeNames, contains(v));
    });
  });

  group('HostAnimationController lipsync', () {
    late HostAnimationController controller;

    setUp(() => controller = HostAnimationController());
    tearDown(() => controller.dispose());

    void tick({
      HostAnimationState state = HostAnimationState.welcome,
      HostAction action = HostAction.welcome,
      double amp = 0,
      bool voice = false,
      bool opening = true,
    }) {
      controller.tick(
        nowSec: 10,
        lifePhase: 0.5,
        state: state,
        stickyAction: action,
        mouthAmplitude: amp,
        voicePlaying: voice,
        welcomeElapsedSec: 3,
        actionElapsedSec: 3,
        inOpeningBeat: opening,
      );
    }

    test('welcome idle keeps closed talk pose, no overlay', () {
      tick();
      expect(controller.frame.bodyAsset, HostAssets.welcomeClosed);
      expect(controller.frame.showMouthOverlay, isFalse);
      expect(controller.frame.mouthViseme, 'closed');
      expect(controller.frame.blinkAsset, isNull);
    });

    test('welcome speech swaps full talk frame, no overlay', () {
      tick(state: HostAnimationState.speaking, amp: 0.5, voice: true);
      expect(controller.frame.bodyAsset, isNot(HostAssets.welcomeClosed));
      expect(HostAssets.welcomeTalkPoses, contains(controller.frame.bodyAsset));
      expect(controller.frame.showMouthOverlay, isFalse);
    });

    test('gameplay speech swaps full talk frame, no overlay', () {
      tick(
        state: HostAnimationState.speaking,
        action: HostAction.listening,
        amp: 0.45,
        voice: true,
        opening: false,
      );
      expect(HostAssets.welcomeTalkPoses, contains(controller.frame.bodyAsset));
      expect(controller.frame.showMouthOverlay, isFalse);
    });

    test('voice alone drives talk frames even outside speaking state', () {
      tick(state: HostAnimationState.welcome, amp: 0.4, voice: true);
      expect(HostAssets.welcomeTalkPoses, contains(controller.frame.bodyAsset));
      expect(controller.frame.showMouthOverlay, isFalse);
    });
  });

  group('MouthTiming / FacialTiming', () {
    test('fluid lipsync constants', () {
      expect(MouthTiming.holdClosedSec, 0.06);
      expect(MouthTiming.holdOpenSec, 0.08);
      expect(MouthTiming.maxSmoothing, 0.52);
      expect(MouthTiming.tickMs, 33);
      expect(FacialTiming.breathCycleMs, 3200);
    });
  });

  group('WelcomeTalkAnimator', () {
    test('opens quickly while talking', () {
      final anim = WelcomeTalkAnimator();
      final a = anim.tick(nowSec: 1.0, amplitude: 0.45, talking: true);
      expect(a, isNot(HostAssets.welcomeClosed));
      expect(HostAssets.welcomeTalkPoses, contains(a));
    });

    test('steps mid before jumping to open', () {
      final anim = WelcomeTalkAnimator();
      final mid = anim.tick(nowSec: 1.0, amplitude: 0.70, talking: true);
      expect(mid, HostAssets.welcomeMid);
      final wide = anim.tick(nowSec: 1.10, amplitude: 0.70, talking: true);
      expect(
        wide,
        anyOf(HostAssets.welcomeWide, HostAssets.welcomeWide2),
      );
    });

    test('closes when voice stops', () {
      final anim = WelcomeTalkAnimator();
      anim.tick(nowSec: 1.0, amplitude: 0.4, talking: true);
      expect(
        anim.tick(nowSec: 1.2, amplitude: 0, talking: false),
        HostAssets.welcomeClosed,
      );
    });
  });

  group('HostStateResolver', () {
    const names = {'A1': 'Sunny', 'A2': 'Walter', 'B1': 'Rosa', 'B2': 'Mabel'};
    final words = List.generate(8, (i) => 'Word$i');

    MatchState start() => MatchEngine.start(
          words: words,
          names: names,
          config: const MatchConfig(wordsPerHalf: 4),
        );

    test('correct sticky → excited', () {
      expect(
        HostStateResolver.resolve(
          state: start(),
          voicePlaying: false,
          introPlaying: false,
          stickyAction: HostAction.correct,
          inOpeningBeat: false,
        ),
        HostAnimationState.excited,
      );
    });
  });
}
