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
        onError: (e) => debugPrint('SpeechInput error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('SpeechInput status: $s'),
        // Short finalTimeout so a one-word utterance finishes promptly.
        finalTimeout: const Duration(milliseconds: 1200),
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
    Duration listenFor = const Duration(seconds: 12),
    Duration pauseFor = const Duration(milliseconds: 2200),
  }) async {
    if (!await ensureReady()) return null;

    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    final done = Completer<String?>();
    var latest = '';

    try {
      await _speech.listen(
        onResult: (result) {
          latest = result.recognizedWords;
          if (result.finalResult && !done.isCompleted) {
            done.complete(cleanWord(latest));
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          // Keep going through brief noise; our timeout still finishes.
          cancelOnError: false,
          // Dictation catches single words more reliably on phones than
          // confirmation mode (Ronna / mobile: Speak missed words).
          listenMode: ListenMode.dictation,
          autoPunctuation: false,
          enableHapticFeedback: false,
          localeId: _localeId,
        ),
      );
    } catch (e) {
      debugPrint('SpeechInput listen failed: $e');
      return null;
    }

    try {
      final heard = await done.future.timeout(
        listenFor + const Duration(seconds: 2),
        onTimeout: () => cleanWord(latest),
      );
      return heard ?? cleanWord(latest);
    } finally {
      try {
        if (_speech.isListening) {
          await _speech.stop();
        }
      } catch (_) {}
      // Give Android a beat to release the mic before game audio resumes.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void dispose() {
    unawaited(cancel());
  }

  /// First spoken token, title-cased, punctuation stripped.
  static String? cleanWord(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final cleaned = t.replaceAll(RegExp(r"[^\w\s'-]"), ' ');
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final word = parts.first;
    if (word.isEmpty) return null;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }
}
