// Standalone demo entry for the Milestone 5 live gameplay screen.
//
// This mounts the real M5 PlayScreen driven by a purely *local* Gameplay
// controller (the pure MatchEngine, no Supabase), so a full game — turns,
// clues, guesses, steals, halftime role-switch, reveals and scoring — can be
// run and screenshotted WITHOUT a live backend or sign-in. It is a
// developer/demo tool only and is never bundled into the shipping app (the
// real entry point remains lib/main.dart).
//
// Run for the web with:
//   flutter run -d web-server -t lib/demo_game.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/game/game_engine.dart';
import 'features/game/gameplay_controller.dart';
import 'features/game/play_screen.dart';
import 'features/game/word_bank.dart';
import 'services/audio_controller.dart';
import 'services/audio_service.dart';

class _SilentOutput implements SoundOutput {
  @override
  bool get isSilent => true;

  @override
  bool get isLoopPlaying => false;
  @override
  Future<void> configure() async {}
  @override
  Future<void> playLoop(String asset, double volume) async {}
  @override
  Future<void> ensureLoop(String asset, double volume) async {}
  @override
  Future<void> playMusicOnce(String asset, double volume,
      {Duration maxWait = const Duration(seconds: 16)}) async {}
  @override
  Future<void> stopLoop() async {}
  @override
  Future<void> setLoopVolume(double volume) async {}
  @override
  Future<void> playOneShot(
    String asset,
    double volume, {
    bool voice = false,
    double playbackRate = 1.0,
    bool fromFile = false,
    bool awaitCompletion = false,
    Duration maxWait = const Duration(seconds: 50),
  }) async {
    if (voice) {
      // Keep lipsync ticking for a beat in silent demos.
      await Future<void>.delayed(const Duration(milliseconds: 1600));
    }
  }
  @override
  Future<void> stopVoice() async {}
  @override
  Future<void> stopSfx() async {}
  @override
  Future<void> reconfigureAudioSession() async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> releaseForSpeechInput() async {}
  @override
  void dispose() {}
}

void main() {
  final controller = GameplayController()
    ..startLocal(
      // A fixed, senior-friendly roster so screenshots read clearly.
      names: const {
        'A1': 'Sunny',
        'A2': 'Walter',
        'B1': 'Rosa',
        'B2': 'Mabel',
      },
      // A seeded RNG so the demo always deals the same words — screenshots stay
      // reproducible across runs.
      words: WordBank.deal(16, random: Random(20260629)),
      config: const MatchConfig(),
    );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameplayController>.value(value: controller),
        ChangeNotifierProvider<AudioController>(
          create: (_) => AudioController(output: _SilentOutput()),
        ),
      ],
      child: MaterialApp(
        title: 'Match Word — Play',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const PlayScreen(studioPass: true),
      ),
    ),
  );
}
