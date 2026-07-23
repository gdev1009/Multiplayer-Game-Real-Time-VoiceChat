/// Guy Smiley host lines from Ronna's script (docs/Guy Smiley Script.pdf)
/// plus wrap-up lines from her chat notes.
library;

import 'dart:math' as math;

import 'host_audio.dart';

/// Rotating / fixed host voice copy for live ElevenLabs TTS.
abstract final class HostVoiceScripts {
  static final math.Random _rng = math.Random();

  /// Full show open — PDF "GUY SMILEY - INTRODUCTION".
  static const String introduction =
      "Ladies and gentlemen… welcome to the studio that makes words come alive… "
      "this… is MATCH WORD! I'm your host, Guy Smiley, and let me tell you, we "
      "are in for a fantastic time today! Here's how we play: we've got two teams, "
      "and each team has a Clue Giver and a Guesser. The mystery word starts with "
      "one team — their Clue Giver gives a clue, and their Guesser tries to guess "
      "the word! Get it right, and the points are yours! But if the Guesser can't "
      "get it… don't worry, it's not over! The word moves over to the other team, "
      "their Clue Giver adds a brand new clue, and their Guesser gets their own "
      "shot at it! Back and forth it goes, for up to eight rounds! And if nobody's "
      "cracked it by then, we move on to a brand new word! Are you ready to play? "
      "Let's find out who takes home the win… right here, right now, on MATCH WORD!";

  /// PDF "CORRECT ANSWER RESPONSES".
  static const List<String> correct = [
    'Yes! You got it! Fantastic!',
    "That's exactly right! Well done!",
    'Look at that! Right on the money!',
    "Oh, beautifully done! That's correct!",
    'Bingo! You nailed it!',
    "That's it! Give that player a round of applause!",
    'Yes indeed! Correct as can be!',
    'Wonderful! You got it!',
    "That's the word! Well done, well done!",
    "Absolutely right! You're on fire today!",
    "Perfect! Couldn't have said it better myself!",
    'There it is! Right answer, right there!',
    'You got it, you got it! Fantastic guessing!',
    'Correct! What a player!',
    'Yes sir, yes ma\'am, that is correct!',
  ];

  /// PDF "WRONG ANSWER RESPONSES" (steal / pass to other team).
  static const List<String> wrong = [
    "Sorry, that's not it! Let's go over to the other team!",
    "Oh, that's too bad! The other team gets a shot now!",
    'Better luck next time! Passing it over to the other side!',
    "Ohh, so close — but let's see what the other team can do!",
    'Not quite! Over to the other Clue Giver now!',
    "Aww, that's a tough one! Other team, you're up!",
    "Sorry, not the word! Let's give the other side a chance!",
    "Oh no, that's not it! The other team's turn now!",
    'Better luck next round! Over to the other Clue Giver!',
    "Ohh, nice try, but no! Let's see if the other team can crack it!",
    "That's too bad! Passing it along to the other side!",
    "Sorry, that's a miss! The other team gets their shot!",
    "Ohh, so near! But it's the other team's turn now!",
    "Not this time! Let's hand it over to the other team!",
    "Oh, sorry, that's too bad! Over to the other Clue Giver now!",
  ];

  /// End-of-match wrap-ups (Ronna: thanks for playing / great game).
  static const List<String> wrapUp = [
    'What a game! Thanks for playing Match Word today — you were wonderful!',
    'Great game, folks! Thanks for joining us — come back soon for more Match Word!',
    "That's a wrap! Thanks for playing at the end of our game today — see you next time on Match Word!",
    'Fantastic show! Thanks for playing Match Word — until next time!',
  ];

  static const String roundStart = "You're on the clock! Give us your best!";
  static const String reveal =
      "Time's up on that word! Let's reveal it and move on.";
  static const String halftime =
      "Halftime! Teams, switch roles — clue givers become guessers!";
  static const String disconnect =
      "Hold on — we lost a player. Hang tight while we sort this out.";

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

  /// Pick the spoken line for [cue]. Correct/wrong/wrap-up rotate.
  static String? lineFor(SoundCue cue) {
    return switch (cue) {
      SoundCue.gameStart => introduction,
      SoundCue.roundStart => roundStart,
      SoundCue.correct => correct[_rng.nextInt(correct.length)],
      SoundCue.steal => wrong[_rng.nextInt(wrong.length)],
      SoundCue.reveal => reveal,
      SoundCue.halftime => halftime,
      SoundCue.winner => wrapUp[_rng.nextInt(wrapUp.length)],
      SoundCue.disconnect => disconnect,
    };
  }
}
