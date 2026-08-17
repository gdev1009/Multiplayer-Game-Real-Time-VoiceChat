import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/game/game_engine.dart';
import '../features/host/mouth_animation.dart';
import '../features/host/host_audio.dart';
import '../features/host/host_voice_scripts.dart';
import '../features/host/voice_envelope.dart';
import 'audio_service.dart';
import 'elevenlabs_tts_service.dart';

/// Drives all game sound: the looping theme, the announcer /
/// effect cues, and the Guy Smiley voice lines — plus the player's mute and
/// volume preferences, persisted across sessions.
///
/// Voice lines prefer live ElevenLabs TTS (Ronna's Game Show Host voice) with
/// on-disk cache, and fall back to bundled Piper MP3s when offline / unkeyed.
class AudioController extends ChangeNotifier {
  AudioController({
    SoundOutput? output,
    SharedPreferences? prefs,
    ElevenLabsTtsService? tts,
  })  : _out = output ?? AudioService(),
        _prefs = prefs,
        _tts = tts ?? ElevenLabsTtsService() {
    _load();
  }

  final SoundOutput _out;
  final ElevenLabsTtsService _tts;
  SharedPreferences? _prefs;

  // --- persisted settings ----------------------------------------------------
  static const _kMuted = 'audio.muted';
  static const _kMusic = 'audio.musicVolume';
  static const _kSfx = 'audio.sfxVolume';
  static const _kVoice = 'audio.voiceVolume';
  static const _kVolumeBoostV2 = 'audio.volumeBoostV2';

  bool _muted = false;
  // Music sits under the show so voice / SFX can stay at full media volume.
  double _musicVolume = 0.48;
  double _sfxVolume = 1.0;
  double _voiceVolume = 1.0;
  /// Temporary duck while the mic is open — never written to prefs.
  double _voiceDuck = 1.0;
  bool _themePlaying = false;

  // --- lipsync ---------------------------------------------------------------
  bool _voicePlaying = false;
  bool _hostIntroPlaying = false;
  String? _voiceAsset;
  double _mouthOpen = 0;
  double _mouthSmoothed = 0;
  DateTime? _voiceStartedAt;
  VoiceEnvelope? _voiceEnvelope;
  Timer? _lipsyncTimer;
  int _voiceGeneration = 0;
  /// Bumped by [stopHostSpeech] so an in-flight [playCue] abandons TTS / voice.
  int _cueEpoch = 0;

  bool get voicePlaying => _voicePlaying;
  /// True while the long game-start welcome / rules line is running.
  bool get hostIntroPlaying => _hostIntroPlaying;
  String? get voiceAsset => _voiceAsset;
  double get mouthOpen => _mouthOpen;
  bool get muted => _muted;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  double get voiceVolume => _voiceVolume;
  bool get elevenLabsReady => _tts.isConfigured;

  double get _effectiveMusic => _muted ? 0 : _musicVolume;
  double get _effectiveSfx => _muted ? 0 : _sfxVolume;
  double get _effectiveVoice => _muted ? 0 : _voiceVolume * _voiceDuck;

  Future<void> _load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _muted = _prefs?.getBool(_kMuted) ?? false;
      _musicVolume = _prefs?.getDouble(_kMusic) ?? 0.48;
      _sfxVolume = _prefs?.getDouble(_kSfx) ?? 1.0;
      _voiceVolume = _prefs?.getDouble(_kVoice) ?? 1.0;
      // Older Speak-duck bug persisted 0 — treat as "use default" (mute is separate).
      if (_voiceVolume <= 0.001) {
        _voiceVolume = 1.0;
        await _prefs?.setDouble(_kVoice, _voiceVolume);
      }
      // One-time lift for installs that still have the quieter defaults saved.
      final boosted = _prefs?.getBool(_kVolumeBoostV2) ?? false;
      if (!boosted) {
        if (_musicVolume >= 0.65 && _musicVolume <= 0.75) {
          _musicVolume = 0.48;
          await _prefs?.setDouble(_kMusic, _musicVolume);
        }
        if (_sfxVolume < 1.0) {
          _sfxVolume = 1.0;
          await _prefs?.setDouble(_kSfx, _sfxVolume);
        }
        if (_voiceVolume < 1.0) {
          _voiceVolume = 1.0;
          await _prefs?.setDouble(_kVoice, _voiceVolume);
        }
        await _prefs?.setBool(_kVolumeBoostV2, true);
      }
      notifyListeners();
    } catch (err) {
      debugPrint('AudioController._load failed (ignored): $err');
    }
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    notifyListeners();
    await _prefs?.setBool(_kMuted, value);
    await _out.setLoopVolume(_effectiveMusic);
    if (value) {
      _cueEpoch++;
      await _out.stopAll();
      _hostIntroPlaying = false;
      _endLipsync();
      if (_themePlaying) await _out.playLoop(HostAudio.themeMusic, 0);
    } else if (_themePlaying) {
      await _out.playLoop(HostAudio.themeMusic, _effectiveMusic);
    }
  }

  Future<void> toggleMuted() => setMuted(!_muted);

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0, 1);
    notifyListeners();
    await _prefs?.setDouble(_kMusic, _musicVolume);
    await _out.setLoopVolume(_effectiveMusic);
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value.clamp(0, 1);
    notifyListeners();
    await _prefs?.setDouble(_kSfx, _sfxVolume);
  }

  Future<void> setVoiceVolume(double value) async {
    _voiceVolume = value.clamp(0, 1);
    notifyListeners();
    await _prefs?.setDouble(_kVoice, _voiceVolume);
  }

  /// Duck music (and mute Guy) while the player uses Speak — does **not**
  /// persist volume preferences (the old path wrote voice=0 to prefs and left
  /// Guy silent for the rest of the session).
  Future<void> beginSpeechInputDuck() async {
    _voiceDuck = 0;
    notifyListeners();
    await stopHostSpeech();
    await _out.stopAll();
    await _out.releaseForSpeechInput();
    // Let the OS actually release the playback session before STT starts.
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  /// Restore levels and re-claim the audio session after speech recognition
  /// (Android often keeps focus until we reconfigure).
  Future<void> endSpeechInputDuck() async {
    _voiceDuck = 1;
    // Recover from older builds that persisted voice volume as 0 while ducking.
    if (_voiceVolume <= 0.001) {
      _voiceVolume = 1.0;
      await _prefs?.setDouble(_kVoice, _voiceVolume);
    }
    notifyListeners();
    await _out.reconfigureAudioSession();
    await _out.setLoopVolume(_effectiveMusic);
  }

  Future<void> _beginLipsync(
    String asset, {
    VoiceEnvelope? envelope,
  }) async {
    final gen = ++_voiceGeneration;
    _voicePlaying = true;
    _voiceAsset = asset;
    _voiceStartedAt = DateTime.now();
    _mouthOpen = 0.12;
    _mouthSmoothed = 0.12;
    _voiceEnvelope = envelope ?? await VoiceEnvelopes.forAsset(asset);
    if (gen != _voiceGeneration) return;
    _lipsyncTimer?.cancel();
    _lipsyncTimer = Timer.periodic(
      const Duration(milliseconds: MouthTiming.tickMs),
      (_) {
      final started = _voiceStartedAt;
      final env = _voiceEnvelope;
      if (started == null || env == null) return;
      final elapsed = DateTime.now().difference(started);
      double raw;
      if (elapsed.inMilliseconds >= env.durationMs) {
        // Keep a soft chatter until playback finishes (_endLipsync).
        if (!_voicePlaying) {
          if (_mouthOpen != 0) {
            _mouthOpen = 0;
            _mouthSmoothed = 0;
            notifyListeners();
          }
          return;
        }
        final t = elapsed.inMilliseconds / 1000.0;
        final cycle = (t * 3.2) % 1.0;
        if (cycle < 0.14 || cycle >= 0.72) {
          raw = 0.0;
        } else if (cycle < 0.32 || cycle >= 0.58) {
          raw = 0.24;
        } else {
          raw = 0.40;
        }
      } else {
        raw = VoiceEnvelopes.sample(env, elapsed);
      }
      final target = raw.clamp(0.0, 1.0);
      _mouthSmoothed +=
          (target - _mouthSmoothed) * MouthTiming.maxSmoothing;
      final next =
          _mouthSmoothed < 0.05 ? 0.0 : _mouthSmoothed.clamp(0.0, 1.0);
      if ((next - _mouthOpen).abs() > 0.015) {
        _mouthOpen = next;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _endLipsync() {
    _voiceGeneration++;
    _lipsyncTimer?.cancel();
    _lipsyncTimer = null;
    _voicePlaying = false;
    _voiceAsset = null;
    _voiceStartedAt = null;
    _voiceEnvelope = null;
    _mouthOpen = 0;
    _mouthSmoothed = 0;
    notifyListeners();
  }

  /// Rough duration for synthetic lipsync when we don't have an envelope file.
  /// Accounts for Guy's slower playback rate so the mouth keeps moving.
  static int _estimateMs(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    // ~165 wpm game-show pace + padding, stretched by deeper playback rate.
    final base = (words.length * 360 + 800).clamp(1800, 90000);
    return (base / _hostPlaybackRate).round().clamp(1800, 90000);
  }

  Future<void> startTheme() async {
    _themePlaying = true;
    await _out.playLoop(HostAudio.themeMusic, _effectiveMusic);
  }

  Future<void> stopTheme() async {
    _themePlaying = false;
    await _out.stopLoop();
  }

  Future<void> reactToTransition(MatchState? prev, MatchState next) async {
    for (final cue in HostAudio.cuesForTransition(prev, next)) {
      await playCue(cue);
    }
  }

  /// Call as soon as the play screen opens so clue input stays locked while
  /// the long welcome line is still loading / synthesizing.
  void markHostIntroStarted() {
    if (_hostIntroPlaying) return;
    _hostIntroPlaying = true;
    notifyListeners();
  }

  Future<void> playCue(SoundCue cue) async {
    final epoch = _cueEpoch;
    final sounds = HostAudio.soundsFor(cue);
    final sfxVol = sounds.isAlarm ? (_muted ? 0.9 : _sfxVolume) : _effectiveSfx;
    final isIntro = cue == SoundCue.gameStart;
    final line = HostVoiceScripts.lineFor(cue);
    final fallback = HostVoiceScripts.fallbackAssetFor(cue) ?? sounds.voice;
    // Correct + winner only: hold crowd until Guy finishes speaking.
    final crowdAfterVoice =
        cue == SoundCue.correct || cue == SoundCue.winner;

    // Prefetch welcome TTS while the opening bed plays so there is no silent
    // gap after the music ends (video25).
    Future<String?>? ttsFuture;
    if (isIntro) {
      _hostIntroPlaying = true;
      notifyListeners();
      if (line != null) {
        ttsFuture = _tts.synthesizeToFile(line);
      }
      await _playOpeningBed();
      if (epoch != _cueEpoch) return;
    }

    if (sounds.stopMusic) {
      _themePlaying = false;
      await _out.stopLoop();
    } else if (sounds.music != null) {
      _themePlaying = true;
      await _out.playLoop(sounds.music!, _effectiveMusic);
    }
    if (epoch != _cueEpoch) return;

    final crowdEffects = <String>[];
    if (!isIntro) {
      for (final effect in sounds.effects) {
        if (epoch != _cueEpoch) return;
        final isCrowd =
            effect.contains('cheer') || effect.contains('applause');
        if (crowdAfterVoice && isCrowd) {
          crowdEffects.add(effect);
          continue;
        }
        final vol = isCrowd ? (sfxVol * _crowdBoost).clamp(0.0, 1.0) : sfxVol;
        if (isCrowd) {
          unawaited(
            _out.playOneShot(effect, vol, awaitCompletion: true),
          );
        } else if (effect.contains('buzzer')) {
          // Wrong / timeout: ring continuously for exactly 3s, then Guy.
          unawaited(_out.playOneShot(effect, vol));
          await Future<void>.delayed(HostAudio.buzzerHold);
          if (epoch != _cueEpoch) return;
          await _out.stopSfx();
        } else {
          unawaited(_out.playOneShot(effect, vol));
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
    }
    if (epoch != _cueEpoch) return;

    if (line == null && fallback == null) {
      if (crowdEffects.isNotEmpty && epoch == _cueEpoch) {
        await _playCrowdBed(crowdEffects, sfxVol, epoch);
      }
      if (isIntro) {
        _hostIntroPlaying = false;
        await _startThemeAfterIntro();
        notifyListeners();
      }
      return;
    }

    final ducked = _themePlaying ? _effectiveMusic * 0.06 : null;
    if (ducked != null) await _out.setLoopVolume(ducked);

    try {
      if (epoch != _cueEpoch) return;

      String? filePath;
      if (line != null) {
        filePath = ttsFuture != null
            ? await ttsFuture
            : await _tts.synthesizeToFile(line);
      }
      if (epoch != _cueEpoch) return;

      if (filePath != null) {
        final env = VoiceEnvelope.synthetic(
          filePath,
          durationMs: _estimateMs(line!),
        );
        await _beginLipsync(filePath, envelope: env);
        if (epoch != _cueEpoch) {
          _endLipsync();
          return;
        }
        await _out.playOneShot(
          filePath,
          (_effectiveVoice * _hostVoiceBoost).clamp(0.0, 1.0),
          voice: true,
          fromFile: true,
          playbackRate: _hostPlaybackRate,
        );
      } else if (fallback != null) {
        await _beginLipsync(fallback);
        if (epoch != _cueEpoch) {
          _endLipsync();
          return;
        }
        await _out.playOneShot(
          fallback,
          (_effectiveVoice * _hostVoiceBoost).clamp(0.0, 1.0),
          voice: true,
          playbackRate: _hostPlaybackRate,
        );
      }
    } finally {
      if (epoch == _cueEpoch) {
        _endLipsync();
      }
      if (isIntro && epoch == _cueEpoch) {
        _hostIntroPlaying = false;
        await _startThemeAfterIntro();
        notifyListeners();
      }
      if (ducked != null) await _out.setLoopVolume(_effectiveMusic);
    }

    // Crowd cheer only after Guy confirms (correct / winner).
    if (crowdEffects.isNotEmpty && epoch == _cueEpoch) {
      await _playCrowdBed(crowdEffects, sfxVol, epoch);
    }
  }

  Future<void> _playCrowdBed(
    List<String> effects,
    double sfxVol,
    int epoch,
  ) async {
    final vol = (sfxVol * _crowdBoost).clamp(0.0, 1.0);
    for (final effect in effects) {
      if (epoch != _cueEpoch) return;
      await _out.playOneShot(
        effect,
        vol,
        awaitCompletion: true,
        maxWait: HostAudio.crowdAfterVoiceMax,
      );
    }
  }

  /// Cue-and-prize bed (~10–15s), then Guy's welcome. Waits for real playback
  /// completion so the handoff never cuts early or late.
  Future<void> _playOpeningBed() async {
    if (_muted || _effectiveMusic <= 0) return;
    if (_out.isSilent) {
      await _out.playMusicOnce(HostAudio.openingBed, 0);
      return;
    }
    await _out.playMusicOnce(
      HostAudio.openingBed,
      _effectiveMusic,
      maxWait: HostAudio.openingBedDuration + const Duration(seconds: 2),
    );
  }

  /// Deeper Guy (Ronna) — slight rate drop. Volume uses the media stream at full.
  static const double _hostPlaybackRate = 0.93;
  static const double _hostVoiceBoost = 1.0;
  /// Crowd at full media volume (values over 1 are clamped by the player).
  static const double _crowdBoost = 1.0;

  Future<void> _startThemeAfterIntro() async {
    _themePlaying = true;
    await _out.playLoop(HostAudio.themeMusic, _effectiveMusic);
  }

  Future<void> playDisconnectAlarm() => playCue(SoundCue.disconnect);

  /// Player tapped a control — hush Guy immediately and cancel any pending cue.
  Future<void> stopHostSpeech() async {
    _cueEpoch++;
    _hostIntroPlaying = false;
    _endLipsync();
    await _out.stopVoice();
    notifyListeners();
  }

  Future<void> stopAll() async {
    _cueEpoch++;
    _themePlaying = false;
    _hostIntroPlaying = false;
    _endLipsync();
    await _out.stopAll();
  }

  @override
  void dispose() {
    _lipsyncTimer?.cancel();
    _tts.dispose();
    _out.dispose();
    super.dispose();
  }
}
