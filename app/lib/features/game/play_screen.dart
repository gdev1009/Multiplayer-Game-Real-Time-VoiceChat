import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../services/audio_controller.dart';
import '../host/host_stage.dart';
import '../host/sound_settings.dart';
import '../host/studio_stage.dart';
import 'game_engine.dart';
import 'gameplay_controller.dart';
import 'word_input.dart';

/// The live gameplay screen (Milestones 5–6).
///
/// Presents the two desks (Team A / Team B) with an animated Guy Smiley in the
/// middle, a scoreboard, the host's turn banner, the shared clue/guess feed, and
/// the speak-or-type input. The host narrates the whole game aloud: the
/// [AudioController] plays the opening theme + announcer intro, round/steal/
/// correct/halftime/winner cues, and — if a player drops — the full-screen
/// disconnect alarm. A sound button in the app bar opens mute / volume controls.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, this.disconnectSignal});

  /// Optional signal that fires the disconnect alarm. When it emits a non-null
  /// message the alarm overlay appears (the real-time presence layer, or the
  /// demo, feeds it). Null keeps the alarm dormant.
  final ValueListenable<String?>? disconnectSignal;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  MatchState? _prevState;
  bool _startedShow = false;
  String? _alarmMessage;

  @override
  void initState() {
    super.initState();
    widget.disconnectSignal?.addListener(_onDisconnectSignal);
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
        audio.reactToTransition(null, state); // opens the show (theme + intro)
      } else {
        audio.reactToTransition(prev, state);
      }
    });
    _prevState = state;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameplayController>();
    final state = controller.state;
    if (state != null) _reactToAudio(state);

    return AppPage(
      title: 'Match Word',
      actions: _audioMaybe == null ? null : const [SoundButton()],
      child: state == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _MatchBody(state: state, controller: controller),
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
  const _MatchBody({required this.state, required this.controller});

  final MatchState state;
  final GameplayController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        StudioStage(
          state: state,
          viewerRole: controller.isLocal ? null : controller.myRole,
          charactersByRole: controller.charactersByRole,
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.isOver)
          _GameOverPanel(state: state)
        else if (state.isHalftime)
          _HalftimePanel(state: state, controller: controller)
        else ...[
          _TurnBanner(state: state),
          const SizedBox(height: AppSpacing.md),
          if (state.feed.isNotEmpty) ...[
            _Feed(state: state),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.isResolved)
            _ResolvedPanel(state: state, controller: controller)
          else
            _InputArea(state: state, controller: controller),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// The prominent "it's your turn" banner naming the player *and* their role.
class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    final giving = state.step == TurnStep.awaitingClue;
    final name = giving ? state.clueGiverName : state.guesserName;
    final action = giving ? 'give a one-word clue' : 'make your guess';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lavenderSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.deepPurpleLight, width: 2),
      ),
      child: Column(
        children: [
          Text(
            '$name, it\'s your turn!',
            style: AppText.title.copyWith(color: AppColors.deepPurple),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text('Time to $action.',
              style: AppText.body, textAlign: TextAlign.center,),
          if (state.pendingClue != null && !giving) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Clue: “${state.pendingClue}”',
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

/// The shared, real-time clue/guess feed.
class _Feed extends StatelessWidget {
  const _Feed({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    // Show the most recent handful, newest at the bottom.
    final entries = state.feed.length > 6
        ? state.feed.sublist(state.feed.length - 6)
        : state.feed;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.divider, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in entries) _FeedLine(entry: e),
        ],
      ),
    );
  }
}

class _FeedLine extends StatelessWidget {
  const _FeedLine({required this.entry});
  final PlayEntry entry;

  @override
  Widget build(BuildContext context) {
    final isGuess = entry.kind == PlayKind.guess;
    final correct = entry.correct == true;
    final icon = !isGuess
        ? Icons.lightbulb_outline_rounded
        : (correct ? Icons.check_circle_rounded : Icons.cancel_outlined);
    final color = !isGuess
        ? AppColors.deepPurple
        : (correct ? AppColors.success : AppColors.error);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppText.body,
                children: [
                  TextSpan(
                    text: '${entry.playerName}: ',
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: entry.text,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return WordInput(
      key: ValueKey('${state.wordIndex}-${state.step}-${state.cluingTeam}'),
      label: giving ? 'Your one-word clue' : 'Your guess',
      hint: giving ? 'A word that hints at it…' : 'What is the word?',
      onSubmit: giving ? controller.submitClue : controller.submitGuess,
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
    final action = giving ? 'give a one-word clue' : 'make a guess';
    final text = message ??
        'Waiting for ${name.isEmpty ? 'the next player' : name} to $action…';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warmBeige,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}

/// After a word is decided, a calm result + "Next word" button.
class _ResolvedPanel extends StatelessWidget {
  const _ResolvedPanel({required this.state, required this.controller});
  final MatchState state;
  final GameplayController controller;

  @override
  Widget build(BuildContext context) {
    final guessed = state.lastOutcome == WordOutcome.guessed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: guessed ? AppColors.lavenderSoft : AppColors.warmBeige,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: guessed ? AppColors.success : AppColors.gold,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                guessed ? Icons.stars_rounded : Icons.visibility_rounded,
                color: guessed ? AppColors.success : AppColors.gold,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  guessed
                      ? 'Nice work! On to the next word.'
                      : 'The word was revealed. On to the next word.',
                  style: AppText.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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
              const Icon(Icons.swap_horiz_rounded,
                  size: 64, color: AppColors.deepPurple,),
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
              Text('Score: ${state.scoreA} – ${state.scoreB}',
                  style: AppText.title,),
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
          const Icon(Icons.emoji_events_rounded,
              size: 88, color: AppColors.gold,),
          const SizedBox(height: AppSpacing.sm),
          Text(
            winner == null ? "It's a tie!" : 'Team $winner wins!',
            style: AppText.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Final score: ${state.scoreA} – ${state.scoreB}',
              style: AppText.title,),
          const SizedBox(height: AppSpacing.md),
          const Text('Thanks for playing Match Word!',
              style: AppText.body, textAlign: TextAlign.center,),
          const SizedBox(height: AppSpacing.lg),
          BigButton(
            label: 'Back to home',
            icon: Icons.home_rounded,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }
}
