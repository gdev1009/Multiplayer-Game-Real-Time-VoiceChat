/// Guy Smiley host lines from Ronna's script (docs/Guy Smiley Script.pdf)
/// plus wrap-up lines from her chat notes.
library;

import 'dart:math' as math;

import 'host_audio.dart';

/// Rotating / fixed host voice copy for live ElevenLabs TTS.
abstract final class HostVoiceScripts {
  static final math.Random _rng = math.Random();

  /// Full show open — Ronna's introduction (team Clue Giver / Guesser rules).
  static const String introduction =
      "Ladies and gentlemen… welcome to the studio that makes words come alive… "
      "this… is MATCH WORD! I'm your host, Guy Smiley, and let me tell you, we "
      "are in for a fantastic time today! Here's how we play: one lucky player "
      "on each team becomes the Clue Giver, and it's their job to describe our "
      "mystery word with just one word — without saying the word itself, of "
      "course! The other player on the team is the guesser. Guess it right, and "
      "the points are yours! Get it wrong, and the team has a chance to steal "
      "with their own clue! Are you ready to play? Let's find out who takes "
      "home the win… right here, right now, on MATCH WORD!";

  /// PDF / chat "CORRECT ANSWER RESPONSES".
  static const List<String> correct = [
    'Yes! You got it! Fantastic!',
    "Ding ding ding! That's exactly right!",
    'Look at that! Right on the money!',
    "Oh, beautifully done! That's correct!",
    'Bingo! You nailed it!',
    "That's it! Give that player a round of applause!",
    'Yes indeed! Correct as can be!',
    "Wonderful! You've got the magic touch!",
    "That's the word! Well done, well done!",
    "Absolutely right! You're on fire today!",
    "Perfect! Couldn't have said it better myself!",
    'There it is! Right answer, right there!',
    'You got it, you got it! Fantastic guessing!',
    'Ding! Correct! What a player!',
    'Yes sir, yes ma\'am, that is correct!',
  ];

  /// PDF / chat "WRONG ANSWER RESPONSES".
  static const List<String> wrong = [
    'Ohhh, so close, but not quite!',
    'Buzz! Not this time, folks.',
    'Ohh, too bad! It moves on to the next player now.',
    'Not quite there, but keep that energy up!',
    'Ohh, a good try, but that\'s not it.',
    "Buzz! We'll give someone else a shot at it.",
    'So close, yet so far! On we go.',
    "Ohh, not the word we're looking for today.",
    "That's a miss, but don't you worry!",
    "Buzz! Next player, it's your turn now.",
    'Ohh, tough one! But that\'s not it.',
    'Not quite, but nice try out there!',
    'That one got away! On to the next guess.',
    'Buzz buzz! Time to pass it along.',
    'Ohh, so near! But the word remains a mystery.',
  ];

  /// End-of-match wrap-ups.
  static const List<String> wrapUp = [
    'What a game! Thanks for playing Match Word today — you were wonderful!',
    'Great game, folks! Thanks for joining us — come back soon for more Match Word!',
    "That's a wrap! Thanks for playing at the end of our game today — see you next time on Match Word!",
    'Fantastic show! Thanks for playing Match Word — until next time!',
  ];

  static const List<String> roundStarts = [
    "You're on the clock! Give us your best!",
    "All right — it's your turn! Make it count!",
    'Here we go! One word — make it a good one!',
    "Lights are on you — let's hear it!",
    'Your moment, folks! What have you got?',
  ];

  static const List<String> reveals = [
    "Time's up on that word! Let's reveal it and move on.",
    "Nobody got it — let's show the word and keep the show rolling!",
    "That one stumped the room! Revealing the word… and on we go!",
    "Clock's done! Here's the word — next one coming up!",
  ];

  static const List<String> halftimes = [
    'Halftime! Teams, switch roles — clue givers become guessers!',
    "That's halftime! Swap seats in spirit — clue givers, you're guessing now!",
    'Mid-show break! Roles flip — new clue givers, new energy!',
    "Halftime! Flip those roles and let's light up the second half!",
  ];

  static const List<String> disconnects = [
    'Hold on — we lost a player. Hang tight while we sort this out.',
    "Whoa — someone's dropped off! Stay put, folks, we'll get you back in.",
    "Technical difficulty! One of our players stepped away — hang on!",
  ];

  /// Bundled Piper fallback asset for [cue] (relative to assets/).
  static String? fallbackAssetFor(SoundCue cue) {
    const vox = 'audio/voice';
    return switch (cue) {
      SoundCue.gameStart => '$vox/rules_intro.mp3',
      SoundCue.roundStart => '$vox/your_turn.mp3',
      SoundCue.correct => '$vox/nice_guess.mp3',
      SoundCue.steal => '$vox/good_try.mp3',
      SoundCue.reveal => '$vox/word_revealed.mp3',
      SoundCue.halftime => '$vox/halftime.mp3',
      SoundCue.winner => '$vox/winner.mp3',
      SoundCue.disconnect => '$vox/disconnect.mp3',
    };
  }

  static String _pick(List<String> lines) => lines[_rng.nextInt(lines.length)];

  /// Pick the spoken line for [cue]. Banks rotate so Guy never sounds stuck.
  static String? lineFor(SoundCue cue) {
    return switch (cue) {
      SoundCue.gameStart => introduction,
      SoundCue.roundStart => _pick(roundStarts),
      SoundCue.correct => _pick(correct),
      SoundCue.steal => _pick(wrong),
      SoundCue.reveal => _pick(reveals),
      SoundCue.halftime => _pick(halftimes),
      SoundCue.winner => _pick(wrapUp),
      SoundCue.disconnect => _pick(disconnects),
    };
  }
}
