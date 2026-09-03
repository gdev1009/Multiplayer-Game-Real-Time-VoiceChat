import 'dart:async';

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
import '../host/host_audio.dart';
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
  bool _timeoutFanfareStarted = false;
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
    try {
      final audio = context.read<AudioController>();
      // Hold AI / auto-advance while Guy talks. Humans can tap to barge in
      // (Speak / Send / Next stop his voice via [stopHostSpeech]).
      controller.inputBlocked = () {
        return audio.hostIntroPlaying ||
            audio.voicePlaying ||
            audio.hostCueBusy;
      };
    } catch (_) {
      controller.inputBlocked = null;
    }
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
  ///
  /// Timeout: TIME is shown first (controller calm), then we play buzz → Guy,
  /// then [GameplayController.completeTimeoutFanfare] switches the team.
  /// Wrong guess: steal/reveal plays while the failing seat stays lit; only
  /// after that audio do we clear the spotlight.
  void _reactToAudio(MatchState state, GameplayController controller) {
    final audio = _audioMaybe;
    final prev = _prevState;
    if (identical(prev, state)) return;

    final timeoutFanfare = controller.timeoutFanfarePending && !_timeoutFanfareStarted;
    final cues = HostAudio.cuesForTransition(prev, state);
    final missCues = controller.suppressMissAudio
        ? const <SoundCue>[]
        : cues
            .where((c) => c == SoundCue.steal || c == SoundCue.reveal)
            .toList();
    final otherCues = cues
        .where((c) => c != SoundCue.steal && c != SoundCue.reveal)
        .toList();
    _prevState = state;

    final inActivePlay = _startedShow &&
        !state.isOver &&
        !state.isHalftime &&
        (state.phase == GamePhase.firstHalf ||
            state.phase == GamePhase.secondHalf);

    // Stray updates while a seat is held must NOT clear the spotlight.
    if (!timeoutFanfare &&
        missCues.isEmpty &&
        otherCues.isEmpty &&
        _startedShow) {
      if (audio != null && inActivePlay) {
        unawaited(audio.ensureThemePlaying());
      }
      return;
    }

    if (audio == null) {
      if (timeoutFanfare) {
        _timeoutFanfareStarted = true;
        unawaited(controller.completeTimeoutFanfare());
      } else if (missCues.isNotEmpty) {
        controller.clearSpotlightHold();
      }
      return;
    }

    if (inActivePlay) {
      unawaited(audio.ensureThemePlaying());
    }

    if (timeoutFanfare) _timeoutFanfareStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        if (!_startedShow) {
          _startedShow = true;
          audio.markHostIntroStarted();
          await audio.reactToTransition(null, state); // opens the show
          return;
        }
        if (timeoutFanfare) {
          // TIME is already on the guesser — shorter buzz → Guy → hand off.
          try {
            await audio.playTimeoutFanfare(
              reveal: controller.timeoutWouldReveal,
            );
          } finally {
            await controller.completeTimeoutFanfare();
            if (mounted) {
              // The fanfare already played steal/reveal — do not fire it again
              // when the state transition lands.
              _prevState = controller.state;
              _timeoutFanfareStarted = false;
            }
          }
          return;
        }
        for (final cue in missCues) {
          await audio.playCue(cue);
        }
        if (missCues.isNotEmpty) {
          controller.clearSpotlightHold();
        }
        for (final cue in otherCues) {
          await audio.playCue(cue);
        }
      } catch (_) {
        if (timeoutFanfare) {
          await controller.completeTimeoutFanfare();
          _timeoutFanfareStarted = false;
        } else if (missCues.isNotEmpty) {
          controller.clearSpotlightHold();
        }
      }
    });
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
      _reactToAudio(state, controller);
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
    // Both teams' clue-givers see the word, so whoever is handed a steal
    // already knows it. The local (single-device) view always sees it.
    final amClueGiver = viewerRole == null || state.isClueGiverRole(viewerRole);
    final showSecretWord = !introPlaying &&
        showTurnDock &&
        state.isTurnActive &&
        state.step == TurnStep.awaitingClue &&
        amClueGiver &&
        state.secretWord.trim().isNotEmpty;
    final pendingClue = state.pendingClue?.trim() ?? '';
    final showClueBanner = !introPlaying &&
        showTurnDock &&
        state.step == TurnStep.awaitingGuess &&
        pendingClue.isNotEmpty;

    // Bottom dock hugs content — shorter on narrow/short phones.
    // Stage stays full-screen (Android adjustPan + Scaffold
    // resizeToAvoidBottomInset: false). Dock lifts with viewInsets when set.
    final narrowPhone = size.width < 400;
    final shortPhone = size.height < 700;
    final panelH = narrowPhone
        ? (shortPhone ? 104.0 : 112.0)
        : (shortPhone ? 118.0 : 128.0);
    final keyboard = viewInsets.bottom;
    final panelBottom = MediaQuery.paddingOf(context).bottom + 10 + keyboard;
    final dockReserve = panelH + 18 + MediaQuery.paddingOf(context).bottom;

    final margin = narrowPhone ? 6.0 : 10.0;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Semantics(
          label: state.hostLine,
          child: StudioStage(
            state: state,
            viewerRole: viewerRole,
            charactersByRole: _stageCharacters(context, controller),
            bottomInset: dockReserve,
            showScoreboards: true,
            spotlightHoldRole: controller.spotlightHoldRole,
          ),
        ),
        // Expected word for the clue-giver — sits in the gap under MATCH WORD
        // and above the upper seats (not on the logo, not on Guy's head).
        if (showSecretWord)
          Positioned(
            left: size.width * 0.18,
            right: size.width * 0.18,
            top: size.height * 0.238,
            height: (size.height * 0.048).clamp(40.0, 52.0),
            child: _StageWordPlaque(
              word: state.secretWord,
              label: 'Your word',
            ),
          )
        else if (showClueBanner)
          Positioned(
            left: size.width * 0.14,
            right: size.width * 0.14,
            top: size.height * 0.238,
            height: (size.height * 0.048).clamp(40.0, 52.0),
            child: _StageWordPlaque(
              word: pendingClue,
              label: 'Clue',
            ),
          ),
        if (state.isOver)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10 + keyboard,
            child: SafeArea(
              top: false,
              child: _GameOverPanel(state: state),
            ),
          )
        else if (state.isHalftime)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10 + keyboard,
            child: SafeArea(
              top: false,
              child: _HalftimePanel(state: state, controller: controller),
            ),
          )
        else if (state.isResolved)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10 + keyboard,
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  try {
                    context.read<AudioController>().skipIntro();
                  } catch (_) {}
                },
                child: const _WaitingPanel(
                  name: '',
                  giving: true,
                  message: 'Skip Ahead',
                ),
              ),
            )
          else
            Positioned(
              left: margin,
              right: margin,
              bottom: panelBottom,
              child: _InputArea(state: state, controller: controller),
            ),
        ],
      ],
    );
  }
}

/// White plaque with bright red letters under the MATCH WORD marquee.
///
/// Ronna (Sep 2026): clue / word cards must read clearly — white background,
/// bright red text (not the old purple plaque with white letters).
class _StageWordPlaque extends StatelessWidget {
  const _StageWordPlaque({required this.word, required this.label});

  final String word;
  final String label;

  static const _clueRed = Color(0xFFEE0011);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${word.trim()}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _clueRed, width: 2.8),
          boxShadow: [
            BoxShadow(
              color: _clueRed.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                word.trim().toUpperCase(),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(
                  color: _clueRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 56,
                  letterSpacing: 1.4,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared dock chrome for waiting notes (input uses WordInput’s own chrome).
class _DockPanel extends StatelessWidget {
  const _DockPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xEE160C30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF1B159),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xEE160C30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: child,
          ),
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
      final holding = controller.spotlightHoldRole != null;
      final giving = holding ? false : state.step == TurnStep.awaitingClue;
      final steal = giving && state.lastOutcome == WordOutcome.wrong;
      final waitName = controller.displayClockName;
      return _WaitingPanel(
        name: waitName,
        giving: giving,
        message: steal && waitName.isNotEmpty
            ? 'A steal — waiting for $waitName’s new clue…'
            : null,
      );
    }
    final giving = state.step == TurnStep.awaitingClue;
    // After a miss the word stays live — the other team (or you, on a
    // steal-back) must give a *new* clue. Two X's on stage is not "stuck".
    final stealClue = giving && state.lastOutcome == WordOutcome.wrong;
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
      label: giving
          ? (stealClue ? 'New one-word clue' : 'One-word clue')
          : 'Guess',
      hint: giving
          ? (stealClue
              ? 'A steal — give a new clue…'
              : 'A word that hints at it…')
          : 'What is the word?',
      onSubmit: (text) async {
        await audio?.stopHostSpeech();
        if (giving) {
          await controller.submitClue(text);
        } else {
          await controller.submitGuess(text);
        }
      },
      compact: true,
      clueTurn: giving,
      onSpeakRequested: speech == null
          ? null
          : () async {
              final a = audio;
              // Fully release game audio so Android STT can take the mic
              // (media playback session otherwise steals recognition).
              await a?.beginSpeechInputDuck();
              try {
                return await speech!.listenForWord();
              } finally {
                await a?.endSpeechInputDuck();
              }
            },
      onInteract: () {
        unawaited(audio?.stopHostSpeech());
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
    var cueBusy = false;
    try {
      cueBusy = context.watch<AudioController>().hostCueBusy;
    } catch (_) {}
    final headline = guessed
        ? (secret.isEmpty
            ? 'Nice work! On to the next word.'
            : 'Yes it was')
        : (secret.isEmpty
            ? 'Time’s up — on to the next word.'
            : 'Time’s up! The word was');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: guessed ? AppColors.lavenderSoft : AppColors.warmBeige,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: guessed ? AppColors.success : AppColors.gold,
              width: 2,
            ),
          ),
          child: secret.isEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      guessed
                          ? Icons.stars_rounded
                          : Icons.visibility_rounded,
                      color: guessed ? AppColors.success : AppColors.gold,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        headline,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        guessed
                            ? Icons.stars_rounded
                            : Icons.visibility_rounded,
                        color: guessed ? AppColors.success : AppColors.gold,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$headline $secret',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (controller.isLocal || controller.isHost)
          BigButton(
            label: 'Next word',
            icon: Icons.arrow_forward_rounded,
            isLoading: controller.busy,
            onPressed: controller.busy || cueBusy
                ? null
                : () {
                    controller.nextWord();
                  },
          )
        else
          const _WaitingPanel(
            name: 'the host',
            giving: false,
            message: 'Waiting for the host to deal the next word…',
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
            onPressed: controller.busy
                ? null
                : () {
                    controller.beginSecondHalf();
                  },
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
                : 'A trophy is waiting on your shelf — see you next game!',
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
