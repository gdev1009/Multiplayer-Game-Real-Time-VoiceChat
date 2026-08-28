import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/host/host_audio.dart';
import 'package:match_word/services/audio_controller.dart';
import 'package:match_word/services/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the controller asked the audio backend to do.
class _FakeOutput implements SoundOutput {
  final List<String> calls = <String>[];
  String? loopAsset;
  double? loopVolume;
  bool loopRunning = false;

  @override
  bool get isSilent => true;

  @override
  Future<void> configure() async {}

  @override
  Future<void> ensureLoop(String asset, double volume) async {
    if (loopRunning && loopAsset == asset) {
      calls.add('ensureLoop($asset, $volume)');
      loopVolume = volume;
      return;
    }
    await playLoop(asset, volume);
  }

  @override
  Future<void> playLoop(String asset, double volume) async {
    calls.add('playLoop($asset, $volume)');
    loopAsset = asset;
    loopVolume = volume;
    loopRunning = true;
  }

  @override
  Future<void> playMusicOnce(
    String asset,
    double volume, {
    Duration maxWait = const Duration(seconds: 16),
  }) async {
    calls.add('playMusicOnce($asset)');
  }

  @override
  Future<void> stopLoop() async {
    calls.add('stopLoop');
    loopRunning = false;
  }

  @override
  Future<void> setLoopVolume(double volume) async {
    calls.add('setLoopVolume($volume)');
    loopVolume = volume;
  }

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
    calls.add('playOneShot($asset, rate=$playbackRate)');
  }

  @override
  Future<void> stopVoice() async => calls.add('stopVoice');

  @override
  Future<void> stopSfx() async => calls.add('stopSfx');

  @override
  Future<void> stopAll() async {
    calls.add('stopAll');
    loopRunning = false;
  }

  @override
  Future<void> releaseForSpeechInput() async =>
      calls.add('releaseForSpeechInput');

  @override
  Future<void> reconfigureAudioSession() async =>
      calls.add('reconfigureAudioSession');

  @override
  void dispose() {}
}

Future<AudioController> _controller(
  _FakeOutput out, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final controller = AudioController(
    output: out,
    prefs: await SharedPreferences.getInstance(),
  );
  // Let the async _load() settle before assertions.
  await Future<void>.delayed(Duration.zero);
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ronna (Aug 2026): "The 'Mike' voice option kills the background music
  // entirely" / "background music should play continuously through the whole
  // game, not just at intervals".
  group('using the mic does not kill the background music', () {
    test('the theme is playing again after a Speak turn', () async {
      final out = _FakeOutput();
      final audio = await _controller(out);

      await audio.startTheme();
      expect(out.loopRunning, isTrue);

      // The play screen ducks, then tears the session down for the recogniser.
      await audio.beginSpeechInputDuck();
      await audio.stopAll();
      expect(out.loopRunning, isFalse, reason: 'mic teardown stops the loop');

      await audio.endSpeechInputDuck();
      expect(out.loopRunning, isTrue, reason: 'music must come back');
      expect(out.loopAsset, HostAudio.themeMusic);
      expect(out.loopVolume, greaterThan(0));
    });

    test('a second Speak turn still restores the music', () async {
      final out = _FakeOutput();
      final audio = await _controller(out);
      await audio.startTheme();

      for (var turn = 0; turn < 2; turn++) {
        await audio.beginSpeechInputDuck();
        await audio.stopAll();
        await audio.endSpeechInputDuck();
        expect(out.loopRunning, isTrue, reason: 'turn $turn');
      }
    });

    test('the mic does not start music that was never playing', () async {
      final out = _FakeOutput();
      final audio = await _controller(out);

      await audio.beginSpeechInputDuck();
      await audio.stopAll();
      await audio.endSpeechInputDuck();
      expect(out.loopRunning, isFalse);
    });

    test('Guy is audible again after the mic closes', () async {
      final out = _FakeOutput();
      final audio = await _controller(out);
      await audio.beginSpeechInputDuck();
      await audio.endSpeechInputDuck();
      expect(audio.voiceVolume, greaterThan(0));
    });
  });

  // Ronna (Aug 2026): "The music is too loud… when the horns or trumpets come
  // in, it gets annoying very quickly."
  group('the music bed sits under the show', () {
    test('music is quieter than voice and effects by default', () async {
      final out = _FakeOutput();
      final audio = await _controller(out);
      expect(audio.musicVolume, lessThan(audio.voiceVolume));
      expect(audio.musicVolume, lessThan(audio.sfxVolume));
      expect(audio.musicVolume, lessThanOrEqualTo(0.4));
      expect(audio.musicVolume, greaterThan(0));
    });

    test('a louder saved bed is trimmed once', () async {
      final out = _FakeOutput();
      // The old default that testers already have persisted.
      final audio = await _controller(out, prefs: {'audio.musicVolume': 0.62});
      expect(audio.musicVolume, lessThanOrEqualTo(0.4));
    });

    test('a level the player chose themselves is left alone', () async {
      final out = _FakeOutput();
      final audio = await _controller(
        out,
        prefs: {'audio.musicVolume': 0.2, 'audio.musicTrimV4': true},
      );
      expect(audio.musicVolume, closeTo(0.2, 0.001));
    });

    test('the loop is not restarted when the same bed is already playing', () async {
      final out = _FakeOutput();
      final audio = await _controller(out);
      await audio.startTheme();
      final starts = out.calls.where((c) => c.startsWith('playLoop')).length;
      await audio.startTheme();
      expect(out.calls.where((c) => c.startsWith('playLoop')).length, starts);
      expect(out.calls.any((c) => c.startsWith('ensureLoop')), isTrue);
    });

    test('muting silences the bed without losing the saved level', () async {
      final out = _FakeOutput();
      final audio = await _controller(out);
      final chosen = audio.musicVolume;
      await audio.setMuted(true);
      expect(out.loopVolume, 0);
      await audio.setMuted(false);
      expect(audio.musicVolume, chosen);
    });
  });
}
