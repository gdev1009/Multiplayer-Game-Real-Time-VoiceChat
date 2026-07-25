import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A tiny audio backend abstraction so the [AudioController] (and its cue logic)
/// can be unit-tested with a fake, and so the concrete [audioplayers] player is
/// the *only* place that depends on the plugin.
///
/// All methods are best-effort: a missing asset or a platform without audio
/// must never throw into the game loop.
abstract class SoundOutput {
  /// Configure the global audio session (silent-mode behaviour, focus, etc.).
  Future<void> configure();

  /// When true, [AudioController] skips real-time waits (opening bed, etc.).
  bool get isSilent => false;

  /// Start (or restart) the looping background track at [asset], [volume] 0..1.
  Future<void> playLoop(String asset, double volume);

  /// Play a one-shot music bed (non-looping) and wait until it finishes
  /// (or [maxWait] elapses). Used for the opening cue before Guy speaks.
  Future<void> playMusicOnce(
    String asset,
    double volume, {
    Duration maxWait = const Duration(seconds: 16),
  });

  /// Stop the looping background track.
  Future<void> stopLoop();

  /// Live-update the looping track's volume (for the music slider / mute).
  Future<void> setLoopVolume(double volume);

  /// Fire a one-shot sound. When [voice] is true it plays on the dedicated
  /// voice channel (a new voice line interrupts the previous one); otherwise it
  /// plays on a small rotating pool so effects can overlap (e.g. cheer + ding).
  /// [playbackRate] below 1.0 lowers pitch (Guy Smiley reads deeper).
  /// [asset] is normally an AssetSource path; when [fromFile] is true it is an
  /// absolute filesystem path (ElevenLabs cache).
  Future<void> playOneShot(
    String asset,
    double volume, {
    bool voice = false,
    double playbackRate = 1.0,
    bool fromFile = false,
  });

  /// Stop everything immediately.
  Future<void> stopAll();

  void dispose();
}

/// The real [SoundOutput], backed by the `audioplayers` plugin.
///
/// - One looping player for music (theme).
/// - One dedicated player for host voice (a new line replaces the old).
/// - A small round-robin pool for effects so short cues can overlap.
///
/// The audio session uses the iOS *ambient* category so the app **respects the
/// hardware silent switch** (a guiding-principle requirement — no surprise
/// noise for seniors), and ducks rather than stops other audio on Android.
class AudioService implements SoundOutput {
  AudioService({int sfxVoices = 4})
      : _sfxPool = List.generate(sfxVoices, (_) => AudioPlayer());

  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  final List<AudioPlayer> _sfxPool;
  int _next = 0;
  bool _configured = false;

  @override
  bool get isSilent => false;

  @override
  Future<void> configure() async {
    if (_configured) return;
    _configured = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (err) {
      debugPrint('AudioService.configure failed (ignored): $err');
    }
  }

  @override
  Future<void> playLoop(String asset, double volume) async {
    await configure();
    try {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(volume);
      await _music.play(AssetSource(asset), volume: volume);
    } catch (err) {
      debugPrint('AudioService.playLoop($asset) failed (ignored): $err');
    }
  }

  @override
  Future<void> playMusicOnce(
    String asset,
    double volume, {
    Duration maxWait = const Duration(seconds: 16),
  }) async {
    await configure();
    try {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.release);
      await _music.setVolume(volume.clamp(0.0, 1.0));
      await _music.play(AssetSource(asset), volume: volume.clamp(0.0, 1.0));
      try {
        await _music.onPlayerComplete.first.timeout(maxWait);
      } catch (_) {
        try {
          await _music.stop();
        } catch (_) {}
      }
    } catch (err) {
      debugPrint('AudioService.playMusicOnce($asset) failed (ignored): $err');
    } finally {
      try {
        await _music.setReleaseMode(ReleaseMode.loop);
      } catch (_) {}
    }
  }

  @override
  Future<void> stopLoop() async {
    try {
      await _music.stop();
    } catch (_) {}
  }

  @override
  Future<void> setLoopVolume(double volume) async {
    try {
      await _music.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> playOneShot(
    String asset,
    double volume, {
    bool voice = false,
    double playbackRate = 1.0,
    bool fromFile = false,
  }) async {
    await configure();
    try {
      final source = fromFile ? DeviceFileSource(asset) : AssetSource(asset);
      if (voice) {
        await _voice.stop();
        await _voice.setPlaybackRate(playbackRate.clamp(0.5, 1.5));
        await _voice.setVolume(volume.clamp(0.0, 1.0));
        await _voice.play(source, volume: volume.clamp(0.0, 1.0));
        // Hold the game beat until Guy finishes speaking so the next action
        // never cuts him off mid-line. Long intros can exceed 30s.
        try {
          await _voice.onPlayerComplete.first.timeout(
            const Duration(seconds: 90),
          );
        } catch (_) {}
        return;
      }
      final player = _sfxPool[_next];
      _next = (_next + 1) % _sfxPool.length;
      await player.stop();
      await player.play(source, volume: volume);
    } catch (err) {
      debugPrint('AudioService.playOneShot($asset) failed (ignored): $err');
    }
  }

  @override
  Future<void> stopAll() async {
    try {
      await _music.stop();
      await _voice.stop();
      for (final p in _sfxPool) {
        await p.stop();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _music.dispose();
    _voice.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
  }
}
