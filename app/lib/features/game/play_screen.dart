import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/big_button.dart';
import '../../core/widgets/host_greeting.dart';
import 'game_engine.dart';
import 'gameplay_controller.dart';
import 'word_input.dart';

/// The live gameplay screen (Milestone 5).
///
/// Presents the two desks (Team A / Team B) with Guy Smiley in the middle, a
/// scoreboard, the host's turn banner (greeting the on-the-clock player by name
/// *and* role — "Sunny, Player A1"), the shared clue/guess feed, and the
/// speak-or-type input. Halftime and game-over get their own calm panels.
class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameplayController>();
    final state = controller.state;

    return AppPage(
      title: 'Match Word',
      child: state == null
          ? const Center(child: CircularProgressIndicator())
          : _MatchBody(state: state, controller: controller),
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
        _Scoreboard(state: state),
        const SizedBox(height: AppSpacing.md),
        _Desks(state: state),
        const SizedBox(height: AppSpacing.md),
        HostGreeting(message: state.hostLine),
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

/// The two team scores, big and clear, with the word counter between them.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScoreChip(
            team: 'A',
            score: state.scoreA,
            active: state.isTurnActive && state.cluingTeam == 'A',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            children: [
              Text(state.wordLabel, style: AppText.bodyMuted),
              if (state.isTurnActive)
                Text(
                  'Worth ${state.wordValue}',
                  style: AppText.bodyMuted.copyWith(
                    fontSize: 16,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _ScoreChip(
            team: 'B',
            score: state.scoreB,
            active: state.isTurnActive && state.cluingTeam == 'B',
          ),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.team,
    required this.score,
    required this.active,
  });

  final String team;
  final int score;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: active ? AppColors.brandGradient : null,
        color: active ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: active ? AppColors.gold : AppColors.divider,
          width: active ? 3 : 2,
        ),
        boxShadow: AppColors.tileShadow,
      ),
      child: Column(
        children: [
          Text(
            'Team $team',
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textPrimary,
            ),
          ),
          Text(
            '$score',
            style: AppText.display.copyWith(
              color: active ? Colors.white : AppColors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two desks with Guy Smiley between them, highlighting the clue-giver and
/// guesser for the on-the-clock team.
class _Desks extends StatelessWidget {
  const _Desks({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.stageGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppColors.tileShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _DeskColumn(state: state, team: 'A')),
          const _HostPodium(),
          Expanded(child: _DeskColumn(state: state, team: 'B')),
        ],
      ),
    );
  }
}

class _DeskColumn extends StatelessWidget {
  const _DeskColumn({required this.state, required this.team});
  final MatchState state;
  final String team;

  @override
  Widget build(BuildContext context) {
    final onClock = state.isTurnActive && state.cluingTeam == team;
    final clueRole = MatchEngine.clueGiverRole(team, state.phase);
    final guessRole = MatchEngine.guesserRole(team, state.phase);
    return Column(
      children: [
        _SeatChip(
          name: state.names[clueRole] ?? 'Player $clueRole',
          job: 'Clue-giver',
          highlight: onClock && state.step == TurnStep.awaitingClue,
        ),
        const SizedBox(height: AppSpacing.xs),
        _SeatChip(
          name: state.names[guessRole] ?? 'Player $guessRole',
          job: 'Guesser',
          highlight: onClock && state.step == TurnStep.awaitingGuess,
        ),
      ],
    );
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({
    required this.name,
    required this.job,
    required this.highlight,
  });

  final String name;
  final String job;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: highlight ? AppColors.gold : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: highlight ? AppColors.deepPurple : AppColors.divider,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            job,
            style: AppText.bodyMuted.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HostPodium extends StatelessWidget {
  const _HostPodium();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_emotions_rounded,
                color: Colors.white, size: 34,),
          ),
          const SizedBox(height: 4),
          const Text('Host', style: AppText.bodyMuted),
        ],
      ),
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

/// The speak-or-type entry, shown only to the on-the-clock player's turn.
class _InputArea extends StatelessWidget {
  const _InputArea({required this.state, required this.controller});
  final MatchState state;
  final GameplayController controller;

  @override
  Widget build(BuildContext context) {
    final giving = state.step == TurnStep.awaitingClue;
    return WordInput(
      key: ValueKey('${state.wordIndex}-${state.step}-${state.cluingTeam}'),
      label: giving ? 'Your clue' : 'Your guess',
      hint: giving ? 'One word…' : 'Your best guess…',
      onSubmit: giving ? controller.submitClue : controller.submitGuess,
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
        BigButton(
          label: 'Start second half',
          icon: Icons.play_arrow_rounded,
          isLoading: controller.busy,
          onPressed: controller.busy ? null : controller.beginSecondHalf,
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
        ],
      ),
    );
  }
}
