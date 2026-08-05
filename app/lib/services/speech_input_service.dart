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

  bool get isAvailable => _ready;
  bool get isListening => _speech.isListening;

  Future<bool> ensureReady() async {
    if (_ready) return true;
    if (_initAttempted && !_ready) {
      // Allow one more try after a failed init (permission denied then granted).
      _initAttempted = false;
    }
    if (_initAttempted) return _ready;
    _initAttempted = true;
    try {
      _ready = await _speech.initialize(
        onError: (e) => debugPrint('SpeechInput error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('SpeechInput status: $s'),
      );
    } catch (e) {
      debugPrint('SpeechInput init failed: $e');
      _ready = false;
    }
    return _ready;
  }

  /// Listen for a short phrase and return a cleaned single word, or null.
  Future<String?> listenForWord({
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!await ensureReady()) return null;

    if (_speech.isListening) {
      await _speech.stop();
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
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          localeId: 'en_US',
        ),
      );
    } catch (e) {
      debugPrint('SpeechInput listen failed: $e');
      return null;
    }

    try {
      final heard = await done.future.timeout(
        listenFor + const Duration(seconds: 1),
        onTimeout: () => cleanWord(latest),
      );
      return heard;
    } finally {
      try {
        if (_speech.isListening) {
          await _speech.stop();
        }
      } catch (_) {}
      // Give Android a beat to release the mic before game audio resumes.
      await Future<void>.delayed(const Duration(milliseconds: 250));
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
