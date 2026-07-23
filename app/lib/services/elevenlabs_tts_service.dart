/// ElevenLabs Text-to-Speech with on-disk cache.
///
/// Reads `ELEVENLABS_API_KEY` + `ELEVENLABS_VOICE_ID` from dotenv (or
/// `--dart-define`). Returns a local MP3 path, or null when TTS is unavailable
/// so callers can fall back to bundled Piper clips.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ElevenLabsTtsService {
  ElevenLabsTtsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _modelId = 'eleven_multilingual_v2';
  static const _base = 'https://api.elevenlabs.io/v1';

  String? get apiKey {
    const fromDefine = String.fromEnvironment('ELEVENLABS_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    try {
      final v = dotenv.env['ELEVENLABS_API_KEY']?.trim();
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  String get voiceId {
    const fromDefine = String.fromEnvironment('ELEVENLABS_VOICE_ID');
    if (fromDefine.isNotEmpty) return fromDefine;
    try {
      final v = dotenv.env['ELEVENLABS_VOICE_ID']?.trim();
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return 'DHeX7CCuOXUPRpnb0AdT'; // Ronna's Game Show Host voice
  }

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  Future<Directory> _cacheDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/elevenlabs_tts_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _cacheKey(String text) {
    final bytes = utf8.encode('$voiceId|$_modelId|$text');
    return sha256.convert(bytes).toString();
  }

  /// Returns a local file path to an MP3 of [text], or null on failure.
  Future<String?> synthesizeToFile(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (!isConfigured) {
      debugPrint('ElevenLabsTts: no API key — using bundled voice fallback');
      return null;
    }

    try {
      final dir = await _cacheDir();
      final path = '${dir.path}/${_cacheKey(trimmed)}.mp3';
      final cached = File(path);
      if (await cached.exists() && await cached.length() > 256) {
        return path;
      }

      final uri = Uri.parse('$_base/text-to-speech/$voiceId?output_format=mp3_44100_128');
      final res = await _client
          .post(
            uri,
            headers: {
              'xi-api-key': apiKey!,
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: jsonEncode({
              'text': trimmed,
              'model_id': _modelId,
              'voice_settings': {
                'stability': 0.45,
                'similarity_boost': 0.8,
                'style': 0.35,
                'use_speaker_boost': true,
              },
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'ElevenLabsTts: HTTP ${res.statusCode} ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}',
        );
        return null;
      }
      if (res.bodyBytes.length < 256) {
        debugPrint('ElevenLabsTts: empty/short audio body');
        return null;
      }
      await cached.writeAsBytes(res.bodyBytes, flush: true);
      return path;
    } catch (err) {
      debugPrint('ElevenLabsTts.synthesize failed (ignored): $err');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
