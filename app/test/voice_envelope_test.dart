import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/host/voice_envelope.dart';

void main() {
  test('VoiceEnvelope.sampleAt interpolates bins', () {
    const env = VoiceEnvelope(
      asset: 'audio/voice/test.mp3',
      durationMs: 200,
      hopMs: 100,
      samples: [0.0, 1.0, 0.0],
    );
    expect(env.sampleAt(Duration.zero), 0.0);
    expect(env.sampleAt(const Duration(milliseconds: 50)), closeTo(0.5, 0.01));
    expect(env.sampleAt(const Duration(milliseconds: 100)), 1.0);
  });

  test('seatTalk rises then falls', () {
    final mid = VoiceEnvelopes.seatTalk(
      const Duration(milliseconds: 400),
      textLength: 8,
    );
    final late = VoiceEnvelopes.seatTalk(
      const Duration(milliseconds: 5000),
      textLength: 8,
    );
    expect(mid, greaterThan(0.05));
    expect(late, 0);
  });
}
