import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../models/character.dart';
import '../../services/audio_controller.dart';
import '../../services/speech_input_service.dart';
import '../character/character_controller.dart';
import '../host/host_stage.dart';
import '../host/sound_settings.dart';
import '../host/studio_stage.dart';
import '../lobby/lobby_controller.dart';
import '../prizes/prize_controller.dart';
import '../../models/prize.dart';
import 'game_engine.dart';
import 'gameplay_controller.dart';
import 'word_input.dart';

/// Stage looks keyed by role. If my seat is still missing a look, fill it from
/// the signed-in player's saved character (same fallback the lobby uses).
Map<String, Character> _stageCharacters(
  BuildContext context,
  GameplayController controller,
) {
  final looks = Map<String, Character>.of(controller.charactersByRole);
  final myRole = controller.myRole;
  Character? saved;
  try {
    saved = context.watch<CharacterController>().saved;
  } on ProviderNotFoundException {
    saved = null;
  }
  if (myRole == null || saved == null || saved.base == null) return looks;
  final existing = looks[myRole];
  if (existing == null || existing.base == null) {
    looks[myRole] = saved;
  } else {
    // Same person → prefer the live saved look (lobby / creator stay in sync).
    final seatName =
        (controller.state?.names[myRole] ?? existing.displayName).trim().toLowerCase();
    final savedName = saved.displayName.trim().toLowerCase();
    if (seatName.isNotEmpty && seatName == savedName) {
      looks[myRole] = saved;
    }
  }
  return looks;
}

/// The live gameplay screen.
///
/// Presents the two desks (Team A / Team B) with an animated Guy Smiley in the
/// middle, a scoreboard, the host's turn banner, the shared clue/guess feed, and
/// the speak-or-type input. The host narrates the whole game aloud: the
/// [AudioController] plays the opening theme + announcer intro, round/steal/
/// correct/halftime/winner cues, and — if a player drops — the full-screen
/// disconnect alarm. A sound button in the app bar opens mute / volume controls.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    this.disconnectSignal,
    this.studioPass = false,
  });

  /// Optional signal that fires the disconnect alarm. When it emits a non-null
  /// message the alarm overlay appears (the real-time presence layer, or the
  /// demo, feeds it). Null keeps the alarm dormant.
  final ValueListenable<String?>? disconnectSignal;

  /// When true, hide scoreboards, sound control, and the clue dock so the
  /// stage matches the television-set Studio Pass reference. Live play keeps
  /// this false; screenshot demos set it true.
  final bool studioPass;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  MatchState? _prevState;
  bool _startedShow = false;
  bool _awardedPrizes = false;
  String? _alarmMessage;

  @override
  void initState() {
    super.initState();
    widget.disconnectSignal?.addListener(_onDisconnectSignal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<GameplayController>();
    controller.inputBlocked = () {
      try {
        final audio = context.read<AudioController>();
        // Hold the show while Guy is speaking (intro or any host line) so
        // lines aren't cut off mid-word (halftime, etc.).
        return audio.hostIntroPlaying || audio.voicePlaying;
      } catch (_) {
        return false;
      }
    };
  }

  @override
  void dispose() {
    widget.disconnectSignal?.removeListener(_onDisconnectSignal);
    // Hush the room when leaving the game.
    _audioMaybe?.stopAll();
    super.dispose();
  }

  AudioController? get _audioMaybe {
    try {
      return context.read<AudioController>();
    } catch (_) {
      return null;
    }
  }

  void _onDisconnectSignal() {
    final message = widget.disconnectSignal?.value;
    if (message == null) return;
    _audioMaybe?.playDisconnectAlarm();
    setState(() => _alarmMessage = message);
  }

  /// Feed each game-state change to the host audio (after the frame so playback
  /// never blocks the build).
  void _reactToAudio(MatchState state) {
    final audio = _audioMaybe;
    if (audio == null) return;
    final prev = _prevState;
    if (identical(prev, state)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_startedShow) {
        _startedShow = true;
        audio.markHostIntroStarted();
        audio.reactToTransition(null, state); // opens the show (theme + intro)
      } else {
        audio.reactToTransition(prev, state);
      }
    });
    _prevState = state;
  }

  /// Soft-records Prize Room stats once when the match ends.
  void _maybeAwardPrizes(GameplayController controller, MatchState state) {
    if (!state.isOver || _awardedPrizes) return;
    _awardedPrizes = true;
    final myRole = controller.myRole;
    final myTeam = myRole == null || myRole.isEmpty ? null : myRole[0];
    final winner = state.winningTeam;
    final MatchOutcome outcome;
    if (winner == null) {
      outcome = MatchOutcome.tie;
    } else if (controller.isLocal) {
      // Local demos: host sits on Team A.
      outcome = winner == 'A' ? MatchOutcome.win : MatchOutcome.loss;
    } else if (myTeam != null && myTeam == winner) {
      outcome = MatchOutcome.win;
    } else {
      outcome = MatchOutcome.loss;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<PrizeController>().recordMatchResult(outcome: outcome);
      } catch (_) {
        // PrizeController not in tree (demos) — ignore.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameplayController>();
    final state = controller.state;
    var introPlaying = false;
    try {
      introPlaying = context.watch<AudioController>().hostIntroPlaying;
    } catch (_) {}
    if (state != null) {
      _reactToAudio(state);
      _maybeAwardPrizes(controller, state);
    }

    return AppPage(
      studioFocus: true,
      child: state == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _MatchBody(
                  state: state,
                  controller: controller,
                  introPlaying: introPlaying,
                ),
                if (!widget.studioPass && _audioMaybe != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: const CircleBorder(),
                      child: const SoundButton(),
                    ),
                  ),
                if (_alarmMessage != null)
                  DisconnectAlarm(
                    message: _alarmMessage!,
                    onDismiss: () => setState(() => _alarmMessage = null),
                  ),
              ],
            ),
    );
  }
}

class _MatchBody extends StatelessWidget {
  const _MatchBody({
    required this.state,
    required this.controller,
    this.introPlaying = false,
  });

  final MatchState state;
  final GameplayController controller;
  final bool introPlaying;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewerRole = controller.isLocal ? null : controller.myRole;
    final showTurnDock =
        !state.isOver && !state.isHalftime && !state.isResolved;
    final amClueGiver = viewerRole == null || viewerRole == state.clueGiverRole;
    final showSecretWord = !introPlaying &&
        showTurnDock &&
        state.isTurnActive &&
        state.step == TurnStep.awaitingClue &&
        amClueGiver &&
        state.secretWord.trim().isNotEmpty;

    // Bottom dock: clue/guess input only. Mystery word is on the stage.
    final panelH = (size.height * 0.095).clamp(74.0, 92.0);
    final panelBottom =
        MediaQuery.paddingOf(context).bottom + 6 + viewInsets.bottom * 0.1;
    final dockReserve = panelH + 14 + viewInsets.bottom * 0.12;

    const margin = 10.0;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Semantics(
          label: state.hostLine,
          child: StudioStage(
            state: state,
            viewerRole: viewerRole,
            // Prefer the local saved look for my seat so lobby + stage match
            // even if mw_game_characters is slow or stale.
            charactersByRole: _stageCharacters(context, controller),
            bottomInset: dockReserve,
            showScoreboards: true,
          ),
        ),
        // Mystery word sits on the marquee — above the upper seat heads
        // (video21: LEMON banner was covering Greg / Rosie).
        if (showSecretWord)
          Positioned(
            left: size.width * 0.20,
            right: size.width * 0.20,
            top: size.height * 0.205,
            height: (size.height * 0.052).clamp(42.0, 56.0),
            child: _StageMysteryWord(word: state.secretWord),
          ),
        if (state.isOver)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: _GameOverPanel(state: state),
            ),
          )
        else if (state.isHalftime)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: _HalftimePanel(state: state, controller: controller),
            ),
          )
        else if (state.isResolved)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: _ResolvedPanel(state: state, controller: controller),
            ),
          )
        else if (showTurnDock) ...[
          if (introPlaying)
            Positioned(
              left: margin,
              right: margin,
              bottom: panelBottom,
              height: panelH,
              child: const _WaitingPanel(
                name: '',
                giving: true,
                message: 'Listen to Guy…',
              ),
            )
          else
            Positioned(
              left: margin,
              right: margin,
              bottom: panelBottom,
              height: panelH,
              child: _InputArea(state: state, controller: controller),
            ),
        ],
      ],
    );
  }
}

/// Large gold plaque under the MATCH WORD marquee — clue-giver only.
class _StageMysteryWord extends StatelessWidget {
  const _StageMysteryWord({required this.word});
  final String word;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xF2281648),
            Color(0xF2160C30),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD36A), width: 2.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD36A).withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              word.toUpperCase(),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 56,
                letterSpacing: 1.4,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared dock chrome so word + waiting/input share identical outer bounds.
class _DockPanel extends StatelessWidget {
  const _DockPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEE160C30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF1B159).withValues(alpha: 0.65),
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: child,
        ),
      ),
    );
  }
}

/// The speak-or-type entry, shown only on the on-the-clock player's own device.
/// Everyone else sees a calm "waiting for …" note so two people can't type into
/// the same turn (and the computer-filled seats are played by the host).
class _InputArea extends StatelessWidget {
  const _InputArea({required this.state, required this.controller});
  final MatchState state;
  final GameplayController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isMyTurn) {
      return _WaitingPanel(
        name: controller.onClockName,
        giving: state.step == TurnStep.awaitingClue,
      );
    }
    final giving = state.step == TurnStep.awaitingClue;
    SpeechInputService? speech;
    AudioController? audio;
    try {
      speech = context.read<SpeechInputService>();
    } on ProviderNotFoundException {
      speech = null;
    }
    try {
      audio = context.read<AudioController>();
    } on ProviderNotFoundException {
      audio = null;
    }
    return WordInput(
      key: ValueKey('${state.wordIndex}-${state.step}-${state.cluingTeam}'),
      label: giving ? 'One-word clue' : 'Guess',
      hint: giving ? 'A word that hints at it…' : 'What is the word?',
      onSubmit: giving ? controller.submitClue : controller.submitGuess,
      compact: true,
      onSpeakRequested: speech == null
          ? null
          : () async {
              // Duck studio bed so the mic hears the player clearly.
              final a = audio;
              final prevMusic = a?.musicVolume ?? 0.55;
              final prevVoice = a?.voiceVolume ?? 0.9;
              if (a != null && !a.muted) {
                await a.setMusicVolume((prevMusic * 0.08).clamp(0.0, 1.0));
                await a.setVoiceVolume(0);
              }
              try {
                return await speech!.listenForWord();
              } finally {
                if (a != null && !a.muted) {
                  await a.setMusicVolume(prevMusic);
                  await a.setVoiceVolume(prevVoice);
                }
              }
            },
    );
  }
}

/// Shown on the devices that are *not* on the clock, so only the active player
/// types this turn.
class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({required this.name, required this.giving, this.message});
  final String name;
  final bool giving;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ??
        (giving
            ? 'Waiting for ${name.isEmpty ? 'clue' : name}…'
            : 'Waiting for ${name.isEmpty ? 'guess' : name}…');
    return _DockPanel(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              giving ? Icons.edit_rounded : Icons.psychology_alt_rounded,
              size: 28,
              color: const Color(0xFFE8B84A),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: Colors.white,
                  height: 1.05,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _leaveToHome(BuildContext context) async {
  try {
    await context.read<LobbyController>().leave();
  } catch (_) {
    // Local / demo sessions have no lobby — still pop home.
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
}

/// After a word is decided, a calm result + "Next word" button.
class _ResolvedPanel extends StatelessWidget {
  const _ResolvedPanel({required this.state, required this.controller});
  final MatchState state;
  final GameplayController controller;

  @override
  Widget build(BuildContext context) {
    final guessed = state.lastOutcome == WordOutcome.guessed;
    final secret = state.secretWord.trim();
    final headline = guessed
        ? (secret.isEmpty
            ? 'Nice work! On to the next word.'
            : 'Yes — it was “$secret”!')
        : (secret.isEmpty
            ? 'Time’s up — on to the next word.'
            : 'Time’s up! The word was “$secret”.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: guessed ? AppColors.lavenderSoft : AppColors.warmBeige,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: guessed ? AppColors.success : AppColors.gold,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                guessed ? Icons.stars_rounded : Icons.visibility_rounded,
                color: guessed ? AppColors.success : AppColors.gold,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  headline,
                  style: AppText.body.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BigButton(
          label: 'Next word',
          icon: Icons.arrow_forward_rounded,
          isLoading: controller.busy,
          onPressed: controller.busy ? null : controller.nextWord,
        ),
      ],
    );
  }
}

/// The halftime pause with the role-switch reminder and a continue button.
class _HalftimePanel extends StatelessWidget {
  const _HalftimePanel({required this.state, required this.controller});
  final MatchState state;
  final GameplayController controller;

  @override
  Widget build(BuildContext context) {
    final newClueA =
        state.names[MatchEngine.clueGiverRole('A', GamePhase.secondHalf)];
    final newClueB =
        state.names[MatchEngine.clueGiverRole('B', GamePhase.secondHalf)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.stageGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: AppColors.tileShadow,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                size: 64,
                color: AppColors.deepPurple,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Halftime!', style: AppText.display),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Teams switch it up for the second half.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
              if (newClueA != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$newClueA, you\'re now the clue-giver for Team A.',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ],
              if (newClueB != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$newClueB, you\'re now the clue-giver for Team B.',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Score: ${state.scoreA} – ${state.scoreB}',
                style: AppText.title,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (controller.isLocal || controller.isHost)
          BigButton(
            label: 'Start second half',
            icon: Icons.play_arrow_rounded,
            isLoading: controller.busy,
            onPressed: controller.busy ? null : controller.beginSecondHalf,
          )
        else
          const _WaitingPanel(
            name: 'the host',
            giving: false,
            message: 'Waiting for the host to start the second half…',
          ),
      ],
    );
  }
}

/// The winner celebration at the end of the match.
class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    final winner = state.winningTeam;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.stageGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            size: 88,
            color: AppColors.gold,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            winner == null ? "It's a tie!" : 'Team $winner wins!',
            style: AppText.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Final score: ${state.scoreA} – ${state.scoreB}',
            style: AppText.title,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            winner == null
                ? 'Thanks for playing Match Word!'
                : 'A clay trophy is waiting on your shelf — see you next game!',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'Back to home',
            icon: Icons.home_rounded,
            onPressed: () => _leaveToHome(context),
          ),
        ],
      ),
    );
  }
}
