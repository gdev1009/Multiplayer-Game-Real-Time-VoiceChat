/// Precomputed (or synthetic) amplitude envelopes for host voice lines.
///
/// Sampled while Guy speaks so the mouth overlay can track loudness without
/// live audio metering ([audioplayers] has no amplitude API).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// One voice clip's RMS-style envelope.
class VoiceEnvelope {
  const VoiceEnvelope({
    required this.asset,
    required this.durationMs,
    required this.hopMs,
    required this.samples,
  });

  final String asset;
  final int durationMs;
  final int hopMs;
  final List<double> samples;

  /// Amplitude 0..1 at [elapsed].
  double sampleAt(Duration elapsed) {
    if (samples.isEmpty) return 0;
    final ms = elapsed.inMilliseconds.clamp(0, durationMs);
    final i = (ms / hopMs).floor().clamp(0, samples.length - 1);
    final j = math.min(i + 1, samples.length - 1);
    final t = ((ms - i * hopMs) / hopMs).clamp(0.0, 1.0);
    return samples[i] * (1 - t) + samples[j] * t;
  }

  static VoiceEnvelope synthetic(String asset, {int durationMs = 2500}) {
    const hop = 40;
    final n = math.max(1, durationMs ~/ hop);
    final samples = List<double>.generate(n, (i) {
      final phase = i / n * math.pi * 10;
      final gate = math.sin(i / n * math.pi); // fade in/out
      final syllable = (math.sin(phase).abs() * 0.75 + 0.15);
      return (syllable * gate).clamp(0.0, 1.0);
    });
    return VoiceEnvelope(
      asset: asset,
      durationMs: durationMs,
      hopMs: hop,
      samples: samples,
    );
  }
}

/// Loads envelopes from `assets/audio/voice/envelopes/`.
class VoiceEnvelopes {
  VoiceEnvelopes._();

  static final Map<String, VoiceEnvelope> _cache = {};
  static bool _catalogTried = false;
  static Map<String, String> _catalog = {};

  static String _stemOf(String asset) {
    final name = asset.split('/').last;
    return name.endsWith('.mp3')
        ? name.substring(0, name.length - 4)
        : name;
  }

  static Future<void> _ensureCatalog() async {
    if (_catalogTried) return;
    _catalogTried = true;
    try {
      final raw =
          await rootBundle.loadString('assets/audio/voice/envelopes/catalog.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _catalog = map.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      _catalog = {};
    }
  }

  /// Resolve an envelope for [asset] (e.g. `audio/voice/nice_guess.mp3`).
  static Future<VoiceEnvelope> forAsset(String asset) async {
    final stem = _stemOf(asset);
    final cached = _cache[stem];
    if (cached != null) return cached;

    await _ensureCatalog();
    final path = _catalog[stem] ?? 'audio/voice/envelopes/$stem.json';
    try {
      final raw = await rootBundle.loadString('assets/$path');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final samples = (map['samples'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(growable: false);
      final env = VoiceEnvelope(
        asset: map['asset'] as String? ?? asset,
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 2500,
        hopMs: (map['hopMs'] as num?)?.toInt() ?? 40,
        samples: samples,
      );
      _cache[stem] = env;
      return env;
    } catch (_) {
      final env = VoiceEnvelope.synthetic(asset);
      _cache[stem] = env;
      return env;
    }
  }

  /// Sync sample using a previously loaded / synthetic envelope.
  static double sample(VoiceEnvelope env, Duration elapsed) =>
      env.sampleAt(elapsed);

  /// Talking curve for seat characters (no voice file) — keyed by text length.
  static double seatTalk(Duration elapsed, {required int textLength}) {
    final durMs = (600 + textLength * 90).clamp(800, 2800);
    if (elapsed.inMilliseconds > durMs) return 0;
    final t = elapsed.inMilliseconds / 1000.0;
    // Faster syllable chatter + no DC floor so mouth returns to closed.
    final syllable = math.sin(t * math.pi * 8.5).abs();
    final gate = math.sin(elapsed.inMilliseconds / durMs * math.pi);
    final punch = math.sin(t * math.pi * 17).abs() * 0.35;
    return ((syllable * 0.7 + punch) * gate).clamp(0.0, 1.0);
  }
}
