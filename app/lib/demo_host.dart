// Standalone demo entry for the Milestone 6 Guy Smiley host + audio system.
//
// Mounts the real PlayScreen with a *local* gameplay controller AND a real
// AudioController (backed by a silent no-op sound output for headless capture),
// so the host narration cues, the animated Guy Smiley, the sound button /
// mute + volume sheet, and the full-screen disconnect alarm can all be
// exercised and screenshotted WITHOUT a live backend, sign-in, or real audio
// device. Developer/demo tool only — never shipped (real entry is lib/main.dart).
//
// A small floating "Simulate disconnect" button (demo-only) fires the alarm so
// the recording can show the red-flash + AWOOGA sequence on cue.
//
// Run for the web with:
//   flutter run -d web-server -t lib/demo_host.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/game/ai_player.dart';
import 'features/game/game_engine.dart';
import 'features/game/gameplay_controller.dart';
import 'features/game/play_screen.dart';
import 'features/game/word_bank.dart';
import 'services/audio_controller.dart';
import 'services/audio_service.dart';

/// A no-op [SoundOutput] so the demo runs (and captures) with no real audio
/// device and no plugin calls — the cue *logic* still fires and is observable.
class _SilentOutput implements SoundOutput {
  @override
  Future<void> configure() async {}
  @override
  Future<void> playLoop(String asset, double volume) async {}
  @override
  Future<void> stopLoop() async {}
  @override
  Future<void> setLoopVolume(double volume) async {}
  @override
  Future<void> playOneShot(String asset, double volume,
      {bool voice = false, double playbackRate = 1.0, bool fromFile = false}) async {}
  @override
  Future<void> stopAll() async {}
  @override
  void dispose() {}
}

final ValueNotifier<String?> _disconnectSignal = ValueNotifier<String?>(null);

void main() {
  final names = const {
    'A1': 'Rosa',
    'A2': 'Walter',
    'B1': 'Grace',
    'B2': 'Mabel',
  };
  final controller = GameplayController()
    ..startLocal(
      names: names,
      words: WordBank.deal(8, random: Random(20260629)),
      config: const MatchConfig(),
      myRole: 'A1',
      aiByRole: const {
        'A1': false,
        'A2': true,
        'B1': true,
        'B2': true,
      },
      charactersByRole: {
        for (final e in names.entries)
          e.key: AiPlayer.lookFor('${e.key}:${e.value}', e.value),
      },
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
        title: 'Match Word — Host & Audio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          body: PlayScreen(
            disconnectSignal: _disconnectSignal,
            studioPass: true,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _disconnectSignal.value =
                'Rosa lost connection. We\'ll pause while she comes back.',
            icon: const Icon(Icons.wifi_off_rounded),
            label: const Text('Simulate disconnect'),
          ),
        ),
      ),
    ),
  );
}
