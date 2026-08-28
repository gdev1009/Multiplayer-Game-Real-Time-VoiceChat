import 'dart:async';

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

  /// Start the loop only when [asset] is not already playing — keeps the bed
  /// continuous instead of restarting from the top on every cue.
  Future<void> ensureLoop(String asset, double volume);

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
  /// When [awaitCompletion] is true, wait until the one-shot finishes (cheer),
  /// or until [maxWait] elapses — whichever comes first.
  Future<void> playOneShot(
    String asset,
    double volume, {
    bool voice = false,
    double playbackRate = 1.0,
    bool fromFile = false,
    bool awaitCompletion = false,
    Duration maxWait = const Duration(seconds: 50),
  });

  /// Stop the host voice channel only (music / SFX keep playing).
  Future<void> stopVoice();

  /// Stop effect one-shots only (buzzer bed, ding, etc.). Voice / music keep going.
  Future<void> stopSfx();

  /// Stop everything immediately.
  Future<void> stopAll();

  /// Drop exclusive media focus so device speech recognition can use the mic.
  Future<void> releaseForSpeechInput();

  /// Re-apply the audio session after speech recognition releases the mic.
  Future<void> reconfigureAudioSession();

  void dispose();
}

/// The real [SoundOutput], backed by the `audioplayers` plugin.
///
/// - One looping player for music (theme).
/// - One dedicated player for host voice (a new line replaces the old).
/// - A small round-robin pool for effects so short cues can overlap.
///
/// The audio session uses the iOS *playback* category so Guy, the buzzer, and
/// cheer stay on the media volume path (seniors often miss ambient/silent-mode
/// audio). Android uses the media usage stream with full audio focus.
class AudioService implements SoundOutput {
  AudioService({int sfxVoices = 4})
      : _sfxPool = List.generate(sfxVoices, (_) => AudioPlayer());

  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();
  final List<AudioPlayer> _sfxPool;
  int _next = 0;
  bool _configured = false;
  String? _loopAsset;
  bool _loopActive = false;
  Completer<void>? _voiceWait;

  @override
  bool get isSilent => false;

  @override
  Future<void> configure() async {
    if (_configured) return;
    _configured = true;
    try {
      // Playback (not ambient): uses the media volume slider and ignores the
      // hardware silent switch so Guy / buzzer / cheer stay audible for seniors
      // (Ronna: still too quiet on reviews).
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (err) {
      debugPrint('AudioService.configure failed (ignored): $err');
      _configured = false;
    }
  }

  @override
  Future<void> reconfigureAudioSession() async {
    _configured = false;
    await configure();
    // Nudge the voice player so the next line isn't stuck after STT.
    try {
      await _voice.stop();
    } catch (_) {}
  }

  @override
  Future<void> playLoop(String asset, double volume) async {
    await configure();
    try {
      await _music.stop();
      _loopActive = false;
      _loopAsset = null;
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(volume);
      await _music.play(AssetSource(asset), volume: volume);
      _loopAsset = asset;
      _loopActive = true;
    } catch (err) {
      debugPrint('AudioService.playLoop($asset) failed (ignored): $err');
    }
  }

  @override
  Future<void> ensureLoop(String asset, double volume) async {
    await configure();
    if (_loopActive && _loopAsset == asset) {
      await setLoopVolume(volume);
      return;
    }
    await playLoop(asset, volume);
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
      _loopActive = false;
      _loopAsset = null;
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
    bool awaitCompletion = false,
    Duration maxWait = const Duration(seconds: 50),
  }) async {
    await configure();
    try {
      final source = fromFile ? DeviceFileSource(asset) : AssetSource(asset);
      if (voice) {
        // Cancel any prior voice wait so barge-in / stopHostSpeech unblocks.
        _voiceWait?.complete();
        _voiceWait = Completer<void>();
        final wait = _voiceWait!;
        await _voice.stop();
        await _voice.setPlaybackRate(playbackRate.clamp(0.5, 1.5));
        await _voice.setVolume(volume.clamp(0.0, 1.0));
        await _voice.play(source, volume: volume.clamp(0.0, 1.0));
        // Complete when the line finishes *or* stopVoice() is called.
        late final StreamSubscription<void> sub;
        sub = _voice.onPlayerComplete.listen((_) {
          if (!wait.isCompleted) wait.complete();
        });
        try {
          await wait.future.timeout(const Duration(seconds: 90));
        } catch (_) {
        } finally {
          await sub.cancel();
          if (identical(_voiceWait, wait)) _voiceWait = null;
        }
        return;
      }
      final player = _sfxPool[_next];
      _next = (_next + 1) % _sfxPool.length;
      await player.stop();
      await player.play(source, volume: volume);
      if (awaitCompletion) {
        try {
          await player.onPlayerComplete.first.timeout(maxWait);
        } catch (_) {}
      }
    } catch (err) {
      debugPrint('AudioService.playOneShot($asset) failed (ignored): $err');
    }
  }

  @override
  Future<void> stopVoice() async {
    try {
      await _voice.stop();
    } catch (_) {}
    final wait = _voiceWait;
    if (wait != null && !wait.isCompleted) {
      wait.complete();
    }
  }

  @override
  Future<void> stopSfx() async {
    try {
      for (final p in _sfxPool) {
        await p.stop();
      }
    } catch (_) {}
  }

  @override
  Future<void> stopAll() async {
    try {
      await _music.stop();
      _loopActive = false;
      _loopAsset = null;
      await _voice.stop();
      for (final p in _sfxPool) {
        await p.stop();
      }
    } catch (_) {}
    final wait = _voiceWait;
    if (wait != null && !wait.isCompleted) {
      wait.complete();
    }
  }

  @override
  Future<void> releaseForSpeechInput() async {
    await stopAll();
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.duckOthers,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (err) {
      debugPrint('AudioService.releaseForSpeechInput failed (ignored): $err');
    }
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
