import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../models/character.dart';
import '../character/character_preview.dart';
import '../game/game_engine.dart';

/// The Milestone 6 "game-show studio" stage.
///
/// Renders the live match the way the concept mockup shows it: a deep-purple
/// set lit by soft spotlights, a gold-framed scoreboard and the current word
/// tile up top, two team podiums with the players' character busts, and a
/// full-body Guy Smiley centre-stage holding his microphone with a speech
/// bubble and gold nameplate below him.
///
/// It is a pure presentation widget driven entirely by [state]; all inputs,
/// buttons and audio live around it in `play_screen.dart`.
class StudioStage extends StatelessWidget {
  const StudioStage({
    super.key,
    required this.state,
    this.viewerRole,
    this.charactersByRole = const {},
  });

  final MatchState state;

  /// The role (A1/A2/B1/B2) of the player looking at this device, or null for a
  /// single-device / demo game. Used so the secret word is only ever revealed
  /// on the clue-giver's own screen — never on the guesser's device.
  final String? viewerRole;

  /// Each seat role's character (the player's saved character, or a generated
  /// look for a computer seat). Empty falls back to a generic clay bust.
  final Map<String, Character> charactersByRole;

  @override
  Widget build(BuildContext context) {
    // The stage keeps a portrait TV-frame aspect so the composition matches the
    // mockup on any width. The whole composition is authored against a fixed
    // 360×480 canvas and then uniformly scaled to fit the device via FittedBox,
    // so the host, podiums and busts always keep the same relative positions
    // and never overlap on narrower phones.
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.deepPurpleDark,
                AppColors.deepPurple,
                Color(0xFF4A2578),
              ],
            ),
          ),
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: 360,
              height: 480,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Spotlights + studio floor behind everything.
                  const Positioned.fill(child: _StudioBackdrop()),

                  // Scoreboard + word tile pinned to the top.
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      children: [
                        _Scoreboard(state: state),
                        const SizedBox(height: 10),
                        _WordTile(state: state, viewerRole: viewerRole),
                      ],
                    ),
                  ),

                  // Podiums flank the lower third; the host stands between them.
                  Positioned(
                    left: 8,
                    bottom: 96,
                    width: 132,
                    child: _TeamPodium(
                      state: state,
                      team: 'A',
                      charactersByRole: charactersByRole,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 96,
                    width: 132,
                    child: _TeamPodium(
                      state: state,
                      team: 'B',
                      charactersByRole: charactersByRole,
                    ),
                  ),

                  // Guy Smiley, centre-stage, with his nameplate + speech bubble.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: _HostCentre(state: state),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft ceiling spotlights and a pale studio floor disc.
class _StudioBackdrop extends StatelessWidget {
  const _StudioBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackdropPainter());
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Three cone spotlights beaming down from the top.
    final beam = Paint()..blendMode = BlendMode.plus;
    void spotlight(double topX, double floorX) {
      final path = Path()
        ..moveTo(topX - 10, -4)
        ..lineTo(topX + 10, -4)
        ..lineTo(floorX + w * 0.14, h * 0.62)
        ..lineTo(floorX - w * 0.14, h * 0.62)
        ..close();
      beam.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.62));
      canvas.drawPath(path, beam);
    }

    spotlight(w * 0.22, w * 0.24);
    spotlight(w * 0.5, w * 0.5);
    spotlight(w * 0.78, w * 0.76);

    // Pale elliptical studio floor the host stands on.
    final floor = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.9),
          width: w * 1.1,
          height: h * 0.42,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.9),
        width: w * 1.05,
        height: h * 0.4,
      ),
      floor,
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
}

/// Gold-framed "MATCH WORD" scoreboard with both team scores.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.deepPurple.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'MATCH WORD',
            style: AppText.body.copyWith(
              color: AppColors.goldLight,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ScoreEnd(label: 'TEAM A', score: state.scoreA),
              Text(
                '—',
                style: AppText.display.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                ),
              ),
              _ScoreEnd(label: 'TEAM B', score: state.scoreB, alignEnd: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreEnd extends StatelessWidget {
  const _ScoreEnd({
    required this.label,
    required this.score,
    this.alignEnd = false,
  });
  final String label;
  final int score;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (alignEnd)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _bigScore(),
          ),
        Text(
          label,
          style: AppText.bodyMuted.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
        if (!alignEnd)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: _bigScore(),
          ),
      ],
    );
  }

  Widget _bigScore() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: Tween<double>(begin: 0.4, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          ),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Text(
          '$score',
          key: ValueKey<int>(score),
          style: AppText.display.copyWith(color: Colors.white, fontSize: 40),
        ),
      );
}

/// The cream word tile. Shows the secret word only to the clue-giver (during
/// the clue step); otherwise it shows the word counter so the guesser can never
/// read the answer. The label pops when it changes.
class _WordTile extends StatelessWidget {
  const _WordTile({required this.state, this.viewerRole});
  final MatchState state;
  final String? viewerRole;

  @override
  Widget build(BuildContext context) {
    // Reveal the word during the clue step, but only on the clue-giver's own
    // device. In a single-device / demo game (viewerRole == null) the one
    // screen is the clue-giver, so it shows as before.
    final amClueGiver =
        viewerRole == null || viewerRole == state.clueGiverRole;
    final revealSecret =
        state.isTurnActive && state.step == TurnStep.awaitingClue && amClueGiver;
    final label = revealSecret ? state.secretWord.toUpperCase() : state.wordLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warmBeige,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 2.5),
        boxShadow: AppColors.tileShadow,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        ),
        child: Text(
          label,
          key: ValueKey<String>(label),
          style: AppText.display.copyWith(
            color: AppColors.deepPurple,
            fontSize: revealSecret ? 34 : 24,
            letterSpacing: revealSecret ? 2 : 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A team podium with two character busts above a gold-trimmed desk holding the
/// team name and the two seat nameplates. The active seat glows gold.
class _TeamPodium extends StatelessWidget {
  const _TeamPodium({
    required this.state,
    required this.team,
    this.charactersByRole = const {},
  });
  final MatchState state;
  final String team;
  final Map<String, Character> charactersByRole;

  @override
  Widget build(BuildContext context) {
    final onClock = state.isTurnActive && state.cluingTeam == team;
    final clueRole = MatchEngine.clueGiverRole(team, state.phase);
    final guessRole = MatchEngine.guesserRole(team, state.phase);
    final clueName = state.names[clueRole] ?? 'Player $clueRole';
    final guessName = state.names[guessRole] ?? 'Player $guessRole';
    final clueActive = onClock && state.step == TurnStep.awaitingClue;
    final guessActive = onClock && state.step == TurnStep.awaitingGuess;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Two busts peeking above the desk.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Bust(
              name: clueName,
              seed: '$team$clueRole',
              active: clueActive,
              character: charactersByRole[clueRole],
            ),
            const SizedBox(width: 6),
            _Bust(
              name: guessName,
              seed: '$team$guessRole',
              active: guessActive,
              character: charactersByRole[guessRole],
            ),
          ],
        ),
        Transform.translate(
          offset: const Offset(0, -14),
          child: _Desk(
            team: team,
            clueName: clueName,
            guessName: guessName,
            clueActive: clueActive,
            guessActive: guessActive,
            onClock: onClock,
          ),
        ),
      ],
    );
  }
}

/// A realistic character bust for the podium: the artist's clay head-and-
/// shoulders art (cropped from the base bodies) rising above the desk. The head
/// gently bobs so the stage feels alive, and the whole bust scales up with a
/// gold spotlight ring when it's that player's turn.
class _Bust extends StatefulWidget {
  const _Bust({
    required this.name,
    required this.seed,
    required this.active,
    this.character,
  });
  final String name;
  final String seed;
  final bool active;

  /// The player's character to render. When null, a generic clay bust shows.
  final Character? character;

  @override
  State<_Bust> createState() => _BustState();
}

class _BustState extends State<_Bust> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  @override
  void initState() {
    super.initState();
    // Stagger each bust so the two heads don't bob in lockstep.
    final phase = (widget.seed.hashCode % 1000) / 1000.0;
    _idle
      ..value = phase
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  /// Pick a base body deterministically so a player always looks the same.
  String get _asset {
    final h = widget.seed.codeUnits.fold<int>(
      7,
      (a, c) => (a * 31 + c) & 0x7fffffff,
    );
    return h.isEven
        ? 'assets/images/host/bust-female.png'
        : 'assets/images/host/bust-male.png';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: widget.active ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: 62,
        height: 72,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Gold spotlight halo behind the active player.
            if (widget.active)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.75),
                        AppColors.gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            // The bobbing bust.
            AnimatedBuilder(
              animation: _idle,
              builder: (context, child) {
                final bob = math.sin(_idle.value * math.pi) * 2.2;
                return Transform.translate(
                  offset: Offset(0, -bob),
                  child: child,
                );
              },
              child: _figure(),
            ),
          ],
        ),
      ),
    );
  }

  /// The player's actual character, cropped to head-and-shoulders, or the
  /// generic clay bust when no character is available (demo / missing art).
  Widget _figure() {
    final character = widget.character;
    if (character != null && character.base != null) {
      // Render the full figure large, then show just the head/shoulders through
      // a small window so it reads as a bust rising above the desk.
      const box = Size(60, 70);
      const render = 150.0; // full-figure square, scaled up
      const focusY = 0.16; // fraction of the figure height to centre on
      return SizedBox(
        width: box.width,
        height: box.height,
        child: ClipRect(
          child: OverflowBox(
            minWidth: render,
            maxWidth: render,
            minHeight: render,
            maxHeight: render,
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: const Offset(0, -(render * focusY) + 6),
              child: CharacterPreview(
                character: character,
                size: render,
                showBackdrop: false,
              ),
            ),
          ),
        ),
      );
    }
    return Image.asset(
      _asset,
      height: 70,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(
        Icons.person_rounded,
        size: 48,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}

/// The gold-trimmed team desk with the team name and two seat nameplates.
class _Desk extends StatelessWidget {
  const _Desk({
    required this.team,
    required this.clueName,
    required this.guessName,
    required this.clueActive,
    required this.guessActive,
    required this.onClock,
  });
  final String team;
  final String clueName;
  final String guessName;
  final bool clueActive;
  final bool guessActive;
  final bool onClock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.deepPurpleLight,
            AppColors.deepPurple,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: onClock ? AppColors.gold : Colors.white.withValues(alpha: 0.18),
          width: onClock ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'TEAM $team',
            style: AppText.body.copyWith(
              color: AppColors.goldLight,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          _NamePlate(name: clueName, active: clueActive),
          const SizedBox(height: 4),
          _NamePlate(name: guessName, active: guessActive),
          const SizedBox(height: 6),
          // Gold desk trim.
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.name, required this.active});
  final String name;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.gold : AppColors.warmBeige,
        borderRadius: BorderRadius.circular(8),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppText.body.copyWith(
          color: AppColors.deepPurpleDark,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// Guy Smiley centre-stage: an idle-bobbing full-body figure with a speech
/// bubble above and a gold nameplate below.
class _HostCentre extends StatefulWidget {
  const _HostCentre({required this.state});
  final MatchState state;

  @override
  State<_HostCentre> createState() => _HostCentreState();
}

class _HostCentreState extends State<_HostCentre>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  // A quick, warm bounce whenever the host says something new.
  late final AnimationController _gesture = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didUpdateWidget(_HostCentre oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.hostLine != widget.state.hostLine) {
      _gesture.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _gesture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speech bubble with the host's current line.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _SpeechBubble(message: widget.state.hostLine),
        ),
        const SizedBox(height: 6),
        // The bobbing host, with a bounce + tilt when he speaks.
        AnimatedBuilder(
          animation: Listenable.merge([_idle, _gesture]),
          builder: (context, child) {
            final bob = math.sin(_idle.value * math.pi) * 3;
            final pop = Curves.elasticOut.transform(_gesture.value);
            final scale = 1 + (pop.clamp(0.0, 1.0)) * 0.06;
            final tilt = math.sin(_gesture.value * math.pi * 2) * 0.03;
            return Transform.translate(
              offset: Offset(0, -bob),
              child: Transform.rotate(
                angle: tilt,
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: SizedBox(
            height: 210,
            child: Image.asset(
              'assets/images/host/host-stage.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.emoji_emotions_rounded,
                color: Colors.white,
                size: 120,
              ),
            ),
          ),
        ),
        // Gold "GUY SMILEY" nameplate.
        Transform.translate(
          offset: const Offset(0, -6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppColors.tileShadow,
            ),
            child: Text(
              'GUY SMILEY',
              style: AppText.body.copyWith(
                color: AppColors.deepPurpleDark,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded speech bubble (cream) with a little downward tail. The text pops
/// in whenever the host says something new.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmBeige,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.deepPurpleLight, width: 2),
            boxShadow: AppColors.tileShadow,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
            ),
            child: Text(
              message,
              key: ValueKey<String>(message),
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                color: AppColors.deepPurple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        // Tail.
        CustomPaint(size: const Size(20, 10), painter: _BubbleTailPainter()),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.warmBeige;
    final border = Paint()
      ..color = AppColors.deepPurpleLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) => false;
}
