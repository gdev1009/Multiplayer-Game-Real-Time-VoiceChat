import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/game/game_engine.dart';
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

  bool _muted = false;
  double _musicVolume = 0.6;
  double _sfxVolume = 0.9;
  double _voiceVolume = 1.0;
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
  double get _effectiveVoice => _muted ? 0 : _voiceVolume;

  Future<void> _load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _muted = _prefs?.getBool(_kMuted) ?? false;
      _musicVolume = _prefs?.getDouble(_kMusic) ?? 0.6;
      _sfxVolume = _prefs?.getDouble(_kSfx) ?? 0.9;
      _voiceVolume = _prefs?.getDouble(_kVoice) ?? 1.0;
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
    _lipsyncTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
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
        raw = (0.22 + (math.sin(t * 13.5).abs() * 0.55)).clamp(0.0, 1.0);
      } else {
        raw = VoiceEnvelopes.sample(env, elapsed);
      }
      final target = raw < 0.08
          ? 0.0
          : raw < 0.32
              ? 0.12 + (raw - 0.08) * 1.1
              : (0.38 + (raw - 0.32) * 1.15).clamp(0.0, 1.0);
      // Smooth so welcome PNG / overlay doesn't flicker every frame.
      _mouthSmoothed += (target - _mouthSmoothed) * 0.42;
      final next = _mouthSmoothed < 0.05 ? 0.0 : _mouthSmoothed;
      if ((next - _mouthOpen).abs() > 0.01) {
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
  static int _estimateMs(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    // ~165 wpm game-show pace + padding.
    return (words.length * 360 + 800).clamp(1800, 90000);
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
    final sounds = HostAudio.soundsFor(cue);
    final sfxVol = sounds.isAlarm ? (_muted ? 0.9 : _sfxVolume) : _effectiveSfx;
    final isIntro = cue == SoundCue.gameStart;

    if (isIntro) {
      _hostIntroPlaying = true;
      notifyListeners();
    }

    if (sounds.stopMusic) {
      _themePlaying = false;
      await _out.stopLoop();
    } else if (sounds.music != null) {
      _themePlaying = true;
      await _out.playLoop(sounds.music!, _effectiveMusic);
    }

    for (final effect in sounds.effects) {
      await _out.playOneShot(effect, sfxVol);
    }

    final line = HostVoiceScripts.lineFor(cue);
    final fallback = HostVoiceScripts.fallbackAssetFor(cue) ?? sounds.voice;
    if (line == null && fallback == null) {
      if (isIntro) {
        _hostIntroPlaying = false;
        notifyListeners();
      }
      return;
    }

    final ducked = _themePlaying ? _effectiveMusic * 0.14 : null;
    if (ducked != null) await _out.setLoopVolume(ducked);

    try {
      String? filePath;
      if (line != null) {
        filePath = await _tts.synthesizeToFile(line);
      }

      if (filePath != null) {
        final env = VoiceEnvelope.synthetic(
          filePath,
          durationMs: _estimateMs(line!),
        );
        await _beginLipsync(filePath, envelope: env);
        await _out.playOneShot(
          filePath,
          (_effectiveVoice * 1.15).clamp(0.0, 1.0),
          voice: true,
          fromFile: true,
        );
      } else if (fallback != null) {
        await _beginLipsync(fallback);
        await _out.playOneShot(
          fallback,
          (_effectiveVoice * 1.15).clamp(0.0, 1.0),
          voice: true,
        );
      }
    } finally {
      _endLipsync();
      if (isIntro) {
        _hostIntroPlaying = false;
        notifyListeners();
      }
      if (ducked != null) await _out.setLoopVolume(_effectiveMusic);
    }
  }

  Future<void> playDisconnectAlarm() => playCue(SoundCue.disconnect);

  Future<void> stopAll() async {
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
