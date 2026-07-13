import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/game/game_engine.dart';
import '../features/host/host_audio.dart';
import 'audio_service.dart';

/// Drives all game sound (Milestone 6): the looping theme, the announcer /
/// effect cues, and the Guy Smiley voice lines — plus the player's mute and
/// volume preferences, persisted across sessions.
///
/// It listens to nothing directly; the [PlayScreen] feeds it each game-state
/// transition via [reactToTransition], and the pure [HostAudio] mapper decides
/// which [SoundCue]s to play. Playback goes through the injected [SoundOutput]
/// so the whole controller is testable with a fake backend.
///
/// Guiding principle: **no surprise noise for seniors.** Music and effects
/// honour the mute toggle and the two volume sliders, and the audio session is
/// configured (in [AudioService]) to respect the hardware silent switch.
class AudioController extends ChangeNotifier {
  AudioController({SoundOutput? output, SharedPreferences? prefs})
      : _out = output ?? AudioService(),
        _prefs = prefs {
    _load();
  }

  final SoundOutput _out;
  SharedPreferences? _prefs;

  // --- persisted settings ----------------------------------------------------
  static const _kMuted = 'audio.muted';
  static const _kMusic = 'audio.musicVolume';
  static const _kSfx = 'audio.sfxVolume';

  bool _muted = false;
  double _musicVolume = 0.6;
  double _sfxVolume = 0.9;
  bool _themePlaying = false;

  /// Whether all non-alarm sound is silenced.
  bool get muted => _muted;

  /// Background music level, 0..1 (before the mute toggle is applied).
  double get musicVolume => _musicVolume;

  /// Effects + voice level, 0..1 (before the mute toggle is applied).
  double get sfxVolume => _sfxVolume;

  /// The effective music volume after mute.
  double get _effectiveMusic => _muted ? 0 : _musicVolume;

  /// The effective effect/voice volume after mute.
  double get _effectiveSfx => _muted ? 0 : _sfxVolume;

  Future<void> _load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _muted = _prefs?.getBool(_kMuted) ?? false;
      _musicVolume = _prefs?.getDouble(_kMusic) ?? 0.6;
      _sfxVolume = _prefs?.getDouble(_kSfx) ?? 0.9;
      notifyListeners();
    } catch (err) {
      debugPrint('AudioController._load failed (ignored): $err');
    }
  }

  // --- settings mutations ----------------------------------------------------

  Future<void> setMuted(bool value) async {
    _muted = value;
    notifyListeners();
    await _prefs?.setBool(_kMuted, value);
    await _out.setLoopVolume(_effectiveMusic);
    if (value) {
      // Silence any in-flight effect immediately.
      await _out.stopAll();
      if (_themePlaying) await _out.playLoop(HostAudio.themeMusic, 0);
    } else if (_themePlaying) {
      await _out.playLoop(HostAudio.themeMusic, _effectiveMusic);
    }
  }

  /// Convenience toggle for the mute button.
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

  // --- playback --------------------------------------------------------------

  /// Start the looping opening/underscore theme (idempotent).
  Future<void> startTheme() async {
    _themePlaying = true;
    await _out.playLoop(HostAudio.themeMusic, _effectiveMusic);
  }

  /// Stop the looping theme.
  Future<void> stopTheme() async {
    _themePlaying = false;
    await _out.stopLoop();
  }

  /// React to a game-state change by playing the mapped cues. Call with the
  /// previous and next [MatchState]; pass `null` for [prev] on the first state.
  Future<void> reactToTransition(MatchState? prev, MatchState next) async {
    for (final cue in HostAudio.cuesForTransition(prev, next)) {
      await playCue(cue);
    }
  }

  /// Play a single [SoundCue]: its music change, layered effects, and voice.
  Future<void> playCue(SoundCue cue) async {
    final sounds = HostAudio.soundsFor(cue);

    // The disconnect alarm is a safety cue — it plays even while muted so a
    // senior is never left staring at a frozen game with no idea why.
    final sfxVol = sounds.isAlarm ? (_muted ? 0.9 : _sfxVolume) : _effectiveSfx;

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
    if (sounds.voice != null) {
      await _out.playOneShot(sounds.voice!, sfxVol, voice: true);
    }
  }

  /// Fire the disconnect alarm cue (ALERT + AWOOGA + commentary).
  Future<void> playDisconnectAlarm() => playCue(SoundCue.disconnect);

  /// Stop every sound immediately (e.g. leaving the game screen).
  Future<void> stopAll() async {
    _themePlaying = false;
    await _out.stopAll();
  }

  @override
  void dispose() {
    _out.dispose();
    super.dispose();
  }
}
