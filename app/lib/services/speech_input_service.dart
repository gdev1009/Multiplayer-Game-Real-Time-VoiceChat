import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Device speech recognition for one-word clues and guesses.
///
/// Seniors can tap Speak, say a word, then confirm/edit in the text field
/// before Send. Typing always remains available.
class SpeechInputService {
  SpeechInputService();

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  bool _initAttempted = false;
  String? _localeId;

  Completer<String?>? _session;
  String _latest = '';
  bool _heardListening = false;
  DateTime? _listenStartedAt;

  /// Seniors need time to start speaking and finish a single word.
  static const Duration defaultListenFor = Duration(seconds: 15);
  static const Duration defaultPauseFor = Duration(seconds: 3);

  bool get isAvailable => _ready;
  bool get isListening => _speech.isListening;

  Future<bool> ensureReady() async {
    if (_ready) return true;
    if (_initAttempted && !_ready) {
      // Allow another try after a failed init (permission denied then granted).
      _initAttempted = false;
    }
    if (_initAttempted) return _ready;
    _initAttempted = true;
    try {
      _ready = await _speech.initialize(
        onError: (e) {
          debugPrint('SpeechInput error: ${e.errorMsg}');
          final msg = e.errorMsg.toLowerCase();
          if (msg.contains('no_match') ||
              msg.contains('speech_timeout') ||
              msg.contains('client')) {
            _finishSession();
          }
        },
        onStatus: _onStatus,
        // Give the OS time to deliver a final transcript after a pause.
        finalTimeout: const Duration(seconds: 5),
      );
      if (_ready) {
        _localeId = await _pickLocale();
      }
    } catch (e) {
      debugPrint('SpeechInput init failed: $e');
      _ready = false;
    }
    return _ready;
  }

  void _onStatus(String status) {
    debugPrint('SpeechInput status: $status');
    if (status == SpeechToText.listeningStatus) {
      _heardListening = true;
      _listenStartedAt ??= DateTime.now();
      return;
    }
    if (status == SpeechToText.doneStatus) {
      _finishSession();
      return;
    }
    // Do **not** finish on a brief notListening blip before the mic is ready —
    // that was cutting sessions off with no words heard.
    if (status == SpeechToText.notListeningStatus && _heardListening) {
      final started = _listenStartedAt;
      if (started != null &&
          DateTime.now().difference(started) <
              const Duration(milliseconds: 800)) {
        return;
      }
      if (_latest.trim().isNotEmpty) {
        _finishSession();
      }
    }
  }

  void _finishSession() {
    final session = _session;
    if (session == null || session.isCompleted) return;
    session.complete(cleanWord(_latest));
  }

  /// Prefer an English voice pack when present; otherwise OS default.
  Future<String?> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;
      for (final prefer in ['en_US', 'en_GB', 'en_AU', 'en_CA', 'en_IN']) {
        for (final loc in locales) {
          if (loc.localeId == prefer) return prefer;
        }
      }
      for (final loc in locales) {
        if (loc.localeId.toLowerCase().startsWith('en')) {
          return loc.localeId;
        }
      }
      return locales.first.localeId;
    } catch (e) {
      debugPrint('SpeechInput locales failed: $e');
      return null;
    }
  }

  /// Listen for a short phrase and return a cleaned single word, or null.
  Future<String?> listenForWord({
    Duration listenFor = defaultListenFor,
    Duration pauseFor = defaultPauseFor,
  }) async {
    if (!await ensureReady()) return null;

    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    _latest = '';
    _heardListening = false;
    _listenStartedAt = null;
    final session = Completer<String?>();
    _session = session;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.trim().isNotEmpty) {
            _latest = result.recognizedWords;
          }
          if (result.finalResult && _latest.trim().isNotEmpty) {
            _finishSession();
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.search,
          autoPunctuation: false,
          enableHapticFeedback: false,
          localeId: _localeId,
        ),
      );
    } catch (e) {
      debugPrint('SpeechInput listen failed: $e');
      _session = null;
      return null;
    }

    try {
      final heard = await session.future.timeout(
        listenFor + const Duration(seconds: 3),
        onTimeout: () => cleanWord(_latest),
      );
      return heard ?? cleanWord(_latest);
    } finally {
      _session = null;
      _listenStartedAt = null;
      try {
        if (_speech.isListening) {
          await _speech.stop();
        }
      } catch (_) {}
      // Give Android a beat to release the mic before game audio resumes.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> cancel() async {
    _finishSession();
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void dispose() {
    unawaited(cancel());
  }

  static const _fillers = {
    'um',
    'uh',
    'ah',
    'er',
    'the',
    'a',
    'an',
    'like',
    'please',
  };

  /// First spoken token, title-cased, punctuation stripped.
  static String? cleanWord(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final cleaned = t.replaceAll(RegExp(r"[^\w\s'-]"), ' ');
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final chosen = parts.firstWhere(
      (p) => !_fillers.contains(p.toLowerCase()),
      orElse: () => parts.first,
    );
    if (chosen.isEmpty) return null;
    return chosen[0].toUpperCase() + chosen.substring(1).toLowerCase();
  }
}
