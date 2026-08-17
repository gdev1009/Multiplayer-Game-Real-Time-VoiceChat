import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/services/speech_input_service.dart';

void main() {
  group('SpeechInputService.cleanWord', () {
    test('takes the first spoken token and title-cases it', () {
      expect(SpeechInputService.cleanWord('squirrel'), 'Squirrel');
      expect(SpeechInputService.cleanWord('  SQUIRREL please '), 'Squirrel');
      expect(SpeechInputService.cleanWord('snowman!'), 'Snowman');
    });

    test('skips filler words like um / the', () {
      expect(SpeechInputService.cleanWord('um lemon'), 'Lemon');
      expect(SpeechInputService.cleanWord('the squirrel please'), 'Squirrel');
    });

    test('returns null for empty / punctuation-only input', () {
      expect(SpeechInputService.cleanWord(''), isNull);
      expect(SpeechInputService.cleanWord('   '), isNull);
      expect(SpeechInputService.cleanWord('!!!'), isNull);
    });
  });
}
