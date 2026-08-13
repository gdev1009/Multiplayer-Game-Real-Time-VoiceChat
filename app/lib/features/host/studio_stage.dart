import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../models/character.dart';
import '../../services/audio_controller.dart';
import '../character/idle_character_preview.dart';
import '../game/game_engine.dart';
import 'host_actions.dart';
import 'assets/host_assets.dart';
import 'host_animation_state.dart';
import 'host_controller.dart';
import 'host_widget.dart';

// ─── Stage art (reference: Studio Pass concept) ─────────────────────────────

const _kBg = 'assets/images/Studio_background.png';
const _kSeatOn = 'assets/images/Seat_on.png';
const _kSeatOff = 'assets/images/Seat_off.png';

const _kBgW = 1024.0;
const _kBgH = 1535.0;
const _kSeatAspect = 558 / 447; // Seat_on height / width
const _kHostAspect = 880 / 1348; // host-stage width / height

/// Stage play-rectangle: below MATCH WORD, above the dock. Seats fill it in
/// two rows (Sunny/Rosa top, Walter/Mabel bottom); host fills the centre.
class _RefLayout {
  const _RefLayout._();

  // Play rectangle — under MATCH WORD, above the dock.
  static const rectTop = 0.285;
  static const dockZone = 0.108;
  static const rowGap = 0.010;

  // Horizontal: seats flank the host without swallowing the aisle.
  static const seatOverhang = 0.040;
  static const maxSeatWidth = 0.50;

  // Host — room for gesture hand; centered on stage.
  static const hostWidth = 0.50;
  static const hostShiftX = 0.02;

  // Seat nameplates (measured from Seat_on / Seat_off art).
  static const nameplateTopOn = 0.620;
  static const nameplateHeightOn = 0.072;
  static const nameplateInsetXOn = 0.255;
  static const nameplateTopOff = 0.590;
  static const nameplateHeightOff = 0.082;
  static const nameplateInsetXOff = 0.195;

  // Blue chair-back opening — bust must stay inside these fractions
  // (Ronna red-line range: top of pad → seat lip above the nameplate).
  static const padTopOn = 0.100;
  static const padTopOff = 0.090;
  static const lipTopOn = 0.560;
  static const lipTopOff = 0.550;
  // Keep clear of the purple frame / arms (measured pad ~0.18–0.76).
  static const padInsetXOn = 0.205;
  static const padInsetXOff = 0.210;

  // Intrinsic seat art sizes (on/off canvases differ — keep overlays in art space).
  static const seatOnW = 447.0;
  static const seatOnH = 558.0;
  static const seatOffW = 454.0;
  static const seatOffH = 550.0;
}

double _clamp(double v, double min, double max) => v.clamp(min, max).toDouble();

/// Clips a child to the bottom band of its bounds (from [topFrac] → 1.0).
class _BottomBandClipper extends CustomClipper<Rect> {
  const _BottomBandClipper({required this.topFrac});
  final double topFrac;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * topFrac, size.width, size.height);

  @override
  bool shouldReclip(covariant _BottomBandClipper old) =>
      old.topFrac != topFrac;
}

/// Seat + host metrics packed into the play rectangle.
class _StageMetrics {
  const _StageMetrics({
    required this.seatW,
    required this.seatH,
    required this.upperTop,
    required this.lowerTop,
    required this.aLeft,
    required this.bLeft,
    required this.hostW,
    required this.hostH,
    required this.hostLeft,
    required this.hostTop,
  });

  final double seatW;
  final double seatH;
  final double upperTop;
  final double lowerTop;
  final double aLeft;
  final double bLeft;
  final double hostW;
  final double hostH;
  final double hostLeft;
  final double hostTop;

  static _StageMetrics compute(double w, double h, {double bottomInset = 0}) {
    final dockReserve =
        bottomInset > 0 ? bottomInset + 6 : h * _RefLayout.dockZone;
    final rectTop = h * _RefLayout.rectTop;
    final rectBottom = h - dockReserve;
    final rectH = math.max(120.0, rectBottom - rectTop);
    final gap = h * _RefLayout.rowGap;

    // Largest seat that fits two rows in the rectangle.
    var seatH = (rectH - gap) / 2;
    var seatW = seatH / _kSeatAspect;
    final maxW = w * _RefLayout.maxSeatWidth;
    if (seatW > maxW) {
      seatW = maxW;
      seatH = seatW * _kSeatAspect;
    }

    final upperTop = rectTop;
    final lowerTop = rectBottom - seatH;
    final oh = w * _RefLayout.seatOverhang;
    final aLeft = -oh;
    final bLeft = w - seatW + oh;

    // Host stands on the stage floor between the pods (ref screenshot).
    var hostH = rectH * 0.78;
    var hostW = hostH * _kHostAspect;
    final maxHostW = _clamp(w * _RefLayout.hostWidth, 200.0, 380.0);
    if (hostW > maxHostW) {
      hostW = maxHostW;
      hostH = hostW / _kHostAspect;
    }
    final hostLeft = (w - hostW) / 2 + w * _RefLayout.hostShiftX;
    // Feet land near the lower-seat platform line.
    final hostTop = (lowerTop + seatH * 0.62 - hostH)
        .clamp(rectTop - hostH * 0.04, rectBottom - hostH * 0.85)
        .toDouble();

    return _StageMetrics(
      seatW: seatW,
      seatH: seatH,
      upperTop: upperTop,
      lowerTop: lowerTop,
      aLeft: aLeft,
      bLeft: bLeft,
      hostW: hostW,
      hostH: hostH,
      hostLeft: hostLeft,
      hostTop: hostTop,
    );
  }
}

/// Computed stage geometry for overlaying play UI under seat columns.
class StudioStageGeometry {
  const StudioStageGeometry({
    required this.seatA1,
    required this.seatB1,
    required this.seatA2,
    required this.seatB2,
    required this.scoreA,
    required this.scoreB,
  });

  final Rect seatA1;
  final Rect seatB1;
  final Rect seatA2;
  final Rect seatB2;
  final Rect scoreA;
  final Rect scoreB;

  static StudioStageGeometry compute(Size size, {double bottomInset = 0}) {
    final w = size.width;
    final h = size.height;
    final m = _StageMetrics.compute(w, h, bottomInset: bottomInset);

    Rect bgRect(double ix, double iy, double iw, double ih) {
      final fittedW = h * (_kBgW / _kBgH);
      final cropL = (fittedW - w) / 2;
      return Rect.fromLTWH(
        ix * fittedW - cropL,
        iy * h,
        iw * fittedW,
        ih * h,
      );
    }

    return StudioStageGeometry(
      seatA1: Rect.fromLTWH(m.aLeft, m.upperTop, m.seatW, m.seatH),
      seatB1: Rect.fromLTWH(m.bLeft, m.upperTop, m.seatW, m.seatH),
      seatA2: Rect.fromLTWH(m.aLeft, m.lowerTop, m.seatW, m.seatH),
      seatB2: Rect.fromLTWH(m.bLeft, m.lowerTop, m.seatW, m.seatH),
      scoreA: bgRect(0.292, 0.108, 0.136, 0.044),
      scoreB: bgRect(0.570, 0.108, 0.136, 0.044),
    );
  }
}

/// Live game-show stage built from [Studio_background] + four [Seat_on]/[Seat_off]
/// podiums, dynamic contestant avatars, and the animated host.
class StudioStage extends StatelessWidget {
  const StudioStage({
    super.key,
    required this.state,
    this.viewerRole,
    this.charactersByRole = const {},
    this.bottomInset = 0,
    this.showScoreboards = false,
    this.spotlightHoldRole,
  });

  final MatchState state;
  final String? viewerRole;
  final Map<String, Character> charactersByRole;
  final double bottomInset;
  final bool showScoreboards;
  /// When set, only this seat stays lit (during wrong/timeout buzzer + Guy).
  final String? spotlightHoldRole;

  /// Map a normalised rect on Studio_background into screen space under
  /// [BoxFit.cover] + [Alignment.topCenter].
  static Rect _bgRect(
    double width,
    double height,
    double ix,
    double iy,
    double iw,
    double ih,
  ) {
    final fittedW = height * (_kBgW / _kBgH);
    final cropL = (fittedW - width) / 2;
    return Rect.fromLTWH(
      ix * fittedW - cropL,
      iy * height,
      iw * fittedW,
      ih * height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0C071C),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final m = _StageMetrics.compute(w, h, bottomInset: bottomInset);

          final upperW = m.seatW;
          final upperH = m.seatH;
          final upperTop = m.upperTop;
          final lowerW = m.seatW;
          final lowerH = m.seatH;
          final lowerTop = m.lowerTop;
          final aLeft = m.aLeft;
          final bLeft = m.bLeft;
          final a2Left = m.aLeft;
          final b2Left = m.bLeft;
          final hostW = m.hostW;
          final hostH = m.hostH;
          final hostLeft = m.hostLeft;
          final hostTop = m.hostTop;

          // Baked scoreboard dark interiors on Studio_background.
          final scoreA = _bgRect(w, h, 0.292, 0.108, 0.136, 0.044);
          final scoreB = _bgRect(w, h, 0.570, 0.108, 0.136, 0.044);

          Widget seatPod({
            required String role,
            required bool foreground,
            required double left,
            required double top,
            required double seatW,
            required double seatH,
          }) {
            return Positioned(
              left: left,
              top: top,
              width: seatW,
              height: seatH,
              child: IgnorePointer(
                child: _SeatPod(
                  state: state,
                  role: role,
                  width: seatW,
                  height: seatH,
                  character: charactersByRole[role],
                  foreground: foreground,
                  spotlightHoldRole: spotlightHoldRole,
                ),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // 1. Background + baked score frames — gentle crop so MATCH WORD
              // stays fully legible while seats still get more stage room.
              Positioned.fill(
                child: ClipRect(
                  child: Transform.scale(
                    scale: 1.06,
                    alignment: const Alignment(0, 0.22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Image(
                          image: AssetImage(_kBg),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.high,
                        ),
                        if (showScoreboards) ...[
                          Positioned.fromRect(
                            rect: scoreA,
                            child: _Scoreboard(
                              value: state.scoreA,
                              boardWidth: scoreA.width,
                              boardHeight: scoreA.height,
                            ),
                          ),
                          Positioned.fromRect(
                            rect: scoreB,
                            child: _Scoreboard(
                              value: state.scoreB,
                              boardWidth: scoreB.width,
                              boardHeight: scoreB.height,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 2–3. Upper row (behind host).
              seatPod(
                role: 'A1',
                foreground: false,
                left: aLeft,
                top: upperTop,
                seatW: upperW,
                seatH: upperH,
              ),
              seatPod(
                role: 'B1',
                foreground: false,
                left: bLeft,
                top: upperTop,
                seatW: upperW,
                seatH: upperH,
              ),

              // 4. Host — plain puppet, no focus chrome that can paint a plate.
              Positioned(
                left: hostLeft,
                top: hostTop,
                width: hostW,
                height: hostH,
                child: _HostCentre(
                  state: state,
                  maxWidth: hostW,
                  maxHeight: hostH,
                ),
              ),

              // 5–6. Lower row — Walter under Sunny, Mabel under Rosa.
              seatPod(
                role: 'A2',
                foreground: true,
                left: a2Left,
                top: lowerTop,
                seatW: lowerW,
                seatH: lowerH,
              ),
              seatPod(
                role: 'B2',
                foreground: true,
                left: b2Left,
                top: lowerTop,
                seatW: lowerW,
                seatH: lowerH,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Score digits (frames baked into Studio_background) ─────────────────────

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.value,
    required this.boardWidth,
    required this.boardHeight,
  });

  final int value;
  final double boardWidth;
  final double boardHeight;

  @override
  Widget build(BuildContext context) {
    final digits = value.clamp(0, 99).toString().padLeft(2, '0');
    final padH = boardWidth * 0.06;
    final padV = boardHeight * 0.05;
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: CustomPaint(
          size: Size(boardWidth - padH * 2, boardHeight - padV * 2),
          painter: _SevenSegPainter(digits: digits),
        ),
      ),
    );
  }
}

class _SevenSegPainter extends CustomPainter {
  _SevenSegPainter({required this.digits});
  final String digits;

  static const _map = <String, int>{
    '0': 0x3F,
    '1': 0x06,
    '2': 0x5B,
    '3': 0x4F,
    '4': 0x66,
    '5': 0x6D,
    '6': 0x7D,
    '7': 0x07,
    '8': 0x7F,
    '9': 0x6F,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final n = digits.length;
    final gap = size.width * 0.10;
    final digitH = size.height * 0.96;
    final digitW = math.min(
      (size.width - gap * (n - 1).clamp(0, 8)) / n,
      digitH * 0.62,
    );
    final top = (size.height - digitH) / 2;
    var x = (size.width - (digitW * n + gap * (n - 1))) / 2;
    for (final ch in digits.split('')) {
      _paintDigit(
        canvas,
        Rect.fromLTWH(x, top, digitW, digitH),
        _map[ch] ?? 0x3F,
      );
      x += digitW + gap;
    }
  }

  void _paintDigit(Canvas canvas, Rect box, int bits) {
    final t = (box.shortestSide * 0.19).clamp(4.0, 13.0);
    final inset = t * 0.4;
    final glow = Paint()
      ..color = const Color(0xFFFFB000).withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    final lit = Paint()..color = const Color(0xFFFFF1A0);
    final dim = Paint()..color = const Color(0x55FFE566);

    Path horiz(double y) {
      final left = box.left + inset;
      final right = box.right - inset;
      return Path()
        ..moveTo(left + t * 0.55, y)
        ..lineTo(left + t, y - t * 0.45)
        ..lineTo(right - t, y - t * 0.45)
        ..lineTo(right - t * 0.55, y)
        ..lineTo(right - t, y + t * 0.45)
        ..lineTo(left + t, y + t * 0.45)
        ..close();
    }

    Path vert(double x, double y0, double y1) {
      return Path()
        ..moveTo(x, y0 + t * 0.55)
        ..lineTo(x - t * 0.45, y0 + t)
        ..lineTo(x - t * 0.45, y1 - t)
        ..lineTo(x, y1 - t * 0.55)
        ..lineTo(x + t * 0.45, y1 - t)
        ..lineTo(x + t * 0.45, y0 + t)
        ..close();
    }

    final segs = <Path>[
      horiz(box.top + t * 0.55),
      vert(box.right - t * 0.55, box.top, box.center.dy),
      vert(box.right - t * 0.55, box.center.dy, box.bottom),
      horiz(box.bottom - t * 0.55),
      vert(box.left + t * 0.55, box.center.dy, box.bottom),
      vert(box.left + t * 0.55, box.top, box.center.dy),
      horiz(box.center.dy),
    ];

    for (var i = 0; i < 7; i++) {
      final on = (bits & (1 << i)) != 0;
      if (on) {
        canvas.drawPath(segs[i], glow);
        canvas.drawPath(segs[i], lit);
      } else {
        canvas.drawPath(segs[i], dim);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SevenSegPainter old) => old.digits != digits;
}

// ─── Seat pod (Seat_on / Seat_off + avatar + name text) ─────────────────────

class _SeatPod extends StatelessWidget {
  const _SeatPod({
    required this.state,
    required this.role,
    required this.width,
    required this.height,
    this.character,
    this.foreground = false,
    this.spotlightHoldRole,
  });

  final MatchState state;
  final String role;
  final double width;
  final double height;
  final Character? character;
  final bool foreground;
  final String? spotlightHoldRole;

  bool get _active {
    // During wrong/timeout audio, keep the failing guesser lit until Guy ends.
    final hold = spotlightHoldRole;
    if (hold != null) return role == hold;
    if (!state.isTurnActive) return false;
    if (state.step == TurnStep.awaitingClue) {
      return role == state.clueGiverRole;
    }
    if (state.step == TurnStep.awaitingGuess) {
      return role == state.guesserRole;
    }
    return false;
  }

  PlayEntry? get _line {
    if (state.isResolved || state.isHalftime || state.isOver) return null;
    // Quiet during the opening welcome — no leftover bubbles on stage.
    if (state.wordIndex == 0 && state.feed.isEmpty) return null;

    // Each seat keeps its own latest line for *this* word:
    // clue stays visible while the partner answers (was vanishing when a
    // guess/wrong became the global "latest"), and wrong answers stay sticky.
    PlayEntry? mine;
    for (var i = state.feed.length - 1; i >= 0; i--) {
      final e = state.feed[i];
      if (e.wordIndex == state.wordIndex && e.role == role) {
        mine = e;
        break;
      }
    }
    if (mine == null) return null;

    // Don't show your own prior clue while you're typing the next one.
    if (state.step == TurnStep.awaitingClue &&
        mine.kind == PlayKind.clue &&
        role == state.clueGiverRole) {
      return null;
    }
    return mine;
  }

  @override
  Widget build(BuildContext context) {
    final name = state.names[role] ?? role;
    final team = role.isNotEmpty ? role[0] : '?';
    final active = _active;
    final line = _line;

    final artW = active ? _RefLayout.seatOnW : _RefLayout.seatOffW;
    final artH = active ? _RefLayout.seatOnH : _RefLayout.seatOffH;
    // Bust lives only in the blue pad (red-line range), never the frame/lip.
    final padTop = active ? _RefLayout.padTopOn : _RefLayout.padTopOff;
    final lipTop = active ? _RefLayout.lipTopOn : _RefLayout.lipTopOff;
    final padInsetX =
        active ? _RefLayout.padInsetXOn : _RefLayout.padInsetXOff;
    final plateTop = active
        ? _RefLayout.nameplateTopOn
        : _RefLayout.nameplateTopOff;
    final plateH = active
        ? _RefLayout.nameplateHeightOn
        : _RefLayout.nameplateHeightOff;
    final plateInsetX = active
        ? _RefLayout.nameplateInsetXOn
        : _RefLayout.nameplateInsetXOff;

    final pod = AnimatedScale(
      scale: active ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: width,
        height: height,
        // Keep overlays in the painted seat-art box (on/off canvases differ).
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AspectRatio(
            aspectRatio: artW / artH,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final aw = constraints.maxWidth;
                final ah = constraints.maxHeight;
                final avatarTop = ah * padTop;
                final avatarH = ah * (lipTop - padTop);
                final plateTopPx = ah * plateTop;
                final plateHPx = ah * plateH;
                final seatAsset = active ? _kSeatOn : _kSeatOff;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  fit: StackFit.expand,
                  children: [
                    // 1. Full seat (chair back + floor).
                    Image.asset(
                      seatAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                    // 2. Bust clipped hard to the blue pad (between red lines).
                    Positioned(
                      left: aw * padInsetX,
                      right: aw * padInsetX,
                      top: avatarTop,
                      height: avatarH,
                      child: ClipRect(
                        child: _PlayerBust(
                          name: name,
                          seed: role,
                          character: character,
                          width: aw * (1 - padInsetX * 2),
                          height: avatarH,
                          foreground: foreground,
                        ),
                      ),
                    ),
                    // 3. Seat lip + nameplate over anything past the bottom line.
                    Positioned.fill(
                      child: ClipRect(
                        clipper: _BottomBandClipper(topFrac: lipTop),
                        child: Image.asset(
                          seatAsset,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    // 4. Name inside the painted gold/dark plate only.
                    Positioned(
                      left: aw * plateInsetX,
                      right: aw * plateInsetX,
                      top: plateTopPx,
                      height: plateHPx,
                      child: ClipRect(
                        child: _NameplateText(
                          team: team,
                          name: name,
                          active: active,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    if (line == null) return pod;

    // Just under the nameplate (still on the seat art). Too low and the dock
    // covers lower-row wrong answers so they look like they "vanished".
    final nameTop =
        active ? _RefLayout.nameplateTopOn : _RefLayout.nameplateTopOff;
    final nameH =
        active ? _RefLayout.nameplateHeightOn : _RefLayout.nameplateHeightOff;
    // Foreground (lower) seats sit tighter to the dock — keep bubbles higher.
    final gap = foreground ? 0.008 : 0.018;
    final bubbleTop = (height * (nameTop + nameH + gap))
        .clamp(height * 0.66, height * (foreground ? 0.78 : 0.84));
    final maxBubbleW = (width * 0.96).clamp(110.0, 260.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        pod,
        Positioned(
          top: bubbleTop,
          left: width * 0.04,
          right: width * 0.04,
          child: Align(
            alignment: Alignment.topCenter,
            child: _PlayerBubble(
              key: ValueKey(
                '${line.wordIndex}-${line.kind}-${line.role}-${line.text}',
              ),
              entry: line,
              maxWidth: maxBubbleW,
            ),
          ),
        ),
      ],
    );
  }
}

/// Text only — plate colour comes from Seat_on / Seat_off artwork.
class _NameplateText extends StatelessWidget {
  const _NameplateText({
    required this.team,
    required this.name,
    required this.active,
  });

  final String team;
  final String name;
  final bool active; // plate chrome (gold vs dark)

  @override
  Widget build(BuildContext context) {
    // White on gold and dark plates — never spill past the chrome.
    const color = Color(0xFFFFFFFF);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: active ? 6 : 7,
        vertical: active ? 2 : 3,
      ),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            '$team  $name',
            key: ValueKey<bool>(active),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: active ? 42 : 38,
              height: 1.0,
              letterSpacing: 0.2,
              shadows: const [],
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Speech bubble ───────────────────────────────────────────────────────────

class _PlayerBubble extends StatelessWidget {
  const _PlayerBubble({
    super.key,
    required this.entry,
    required this.maxWidth,
  });

  final PlayEntry entry;
  final double maxWidth;

  static const _tailH = 28.0;
  static const _radius = 18.0;
  /// Half-width at the base of the upward tail (longer stem stays readable).
  static const _tailHalfW = 13.0;

  @override
  Widget build(BuildContext context) {
    final correct = entry.correct == true;
    final wrong = entry.correct == false;
    final bg = correct
        ? const Color(0xFFC8E6C9)
        : wrong
            ? const Color(0xFFFFCDD2)
            : Colors.white;
    final fg = correct
        ? AppColors.success
        : wrong
            ? AppColors.error
            : AppColors.deepPurpleDark;
    final border = correct
        ? AppColors.success
        : wrong
            ? AppColors.error
            : const Color(0xFFAA5BAC).withValues(alpha: 0.55);
    final raw = entry.text.trim();
    final isTimeout = raw == '…' || raw.toLowerCase() == 'time';
    final label = raw;

    final isGuess = entry.kind == PlayKind.guess && !isTimeout;
    // Scale bubble type down on narrow phones so long words still fit.
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final targetSize = isGuess
        ? (narrow ? 36.0 : 44.0)
        : (isTimeout ? (narrow ? 34.0 : 42.0) : (narrow ? 32.0 : 40.0));
    final iconSize = isGuess ? (narrow ? 24.0 : 30.0) : (narrow ? 22.0 : 28.0);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        minWidth: 96,
      ),
      child: CustomPaint(
        painter: _SpeechBubblePainter(
          fill: bg.withValues(alpha: 0.98),
          border: border,
          borderWidth: correct || wrong ? 2.4 : 1.4,
          radius: _radius,
          tailHeight: _tailH,
          tailHalfWidth: _tailHalfW,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            12,
            6 + _tailH,
            12,
            8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (correct || wrong) ...[
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: fg,
                  size: iconSize,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      fontSize: targetSize,
                      height: 1.0,
                      letterSpacing: isGuess ? 0.3 : 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  _SpeechBubblePainter({
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.radius,
    required this.tailHeight,
    this.tailHalfWidth = 12.0,
  });

  final Color fill;
  final Color border;
  final double borderWidth;
  final double radius;
  final double tailHeight;
  final double tailHalfWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.22), 3, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Rounded body with a long upward tail aimed at the seat bust.
  Path _path(Size size) {
    final w = size.width;
    final h = size.height;
    final th = tailHeight;
    final top = th;
    final r = radius.clamp(0.0, (h - th) / 2).toDouble();
    final midX = w * 0.5;
    final tw = tailHalfWidth.clamp(8.0, w * 0.18);
    // Slightly flared tip so the long stem still reads at a glance.
    final tipW = (tw * 0.35).clamp(3.5, 6.0);
    return Path()
      ..moveTo(midX, 0)
      ..lineTo(midX + tipW, th * 0.35)
      ..lineTo(midX + tw, top)
      ..lineTo(w - r, top)
      ..arcToPoint(Offset(w, top + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, top + r)
      ..arcToPoint(Offset(r, top), radius: Radius.circular(r))
      ..lineTo(midX - tw, top)
      ..lineTo(midX - tipW, th * 0.35)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter old) =>
      old.fill != fill ||
      old.border != border ||
      old.borderWidth != borderWidth ||
      old.radius != radius ||
      old.tailHeight != tailHeight ||
      old.tailHalfWidth != tailHalfWidth;
}

// ─── Contestant bust ─────────────────────────────────────────────────────────

class _PlayerBust extends StatefulWidget {
  const _PlayerBust({
    required this.name,
    required this.seed,
    required this.width,
    required this.height,
    this.character,
    this.foreground = false,
  });

  final String name;
  final String seed;
  final double width;
  final double height;
  final Character? character;
  final bool foreground;

  @override
  State<_PlayerBust> createState() => _PlayerBustState();
}

class _PlayerBustState extends State<_PlayerBust>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  @override
  void initState() {
    super.initState();
    _idle
      ..value = (widget.seed.hashCode % 1000) / 1000.0
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (context, child) {
        final bob = math.sin(_idle.value * math.pi) * 0.15;
        return Transform.translate(offset: Offset(0, -bob), child: child);
      },
      child: _figure(),
    );
  }

  Widget _figure() {
    final character = widget.character;
    final boxW = widget.width;
    final boxH = widget.height;
    if (character != null && character.base != null) {
      // Head near the top red line, torso tucked into the seat lip (bottom
      // red line). Hard ClipRect on the parent Positioned keeps hats/arms
      // inside the blue pad — never past the purple frame.
      final bustScale = widget.foreground ? 2.90 : 2.80;
      final render = math.max(boxW, boxH) * 1.12;
      return SizedBox(
        width: boxW,
        height: boxH,
        child: ClipRect(
          child: Transform.translate(
            // Sit the bust down so the chest meets the lip (no floating gap).
            offset: Offset(0, boxH * 0.10),
            child: Transform.scale(
              scale: bustScale,
              alignment: const Alignment(0, -0.90),
              child: IdleCharacterPreview(
                character: character,
                size: render,
                showBackdrop: false,
                animatePoses: false,
                idleIntensity: 0.08,
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Image.asset(
        widget.seed.hashCode.isEven
            ? 'assets/images/host/bust-female.png'
            : 'assets/images/host/bust-male.png',
        width: boxW * 0.95,
        height: boxH * 0.95,
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

// ─── Host (gameplay layer — not part of the three stage PNGs) ────────────────

class _HostCentre extends StatefulWidget {
  const _HostCentre({
    required this.state,
    required this.maxWidth,
    required this.maxHeight,
  });

  final MatchState state;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_HostCentre> createState() => _HostCentreState();
}

class _HostCentreState extends State<_HostCentre>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gesture = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  final HostAnimationController _hostAnim = HostAnimationController();

  HostAction _shown = HostAction.listening;
  DateTime _stickyUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _actionStartedAt = DateTime.now();
  DateTime? _welcomeStartedAt;
  bool _wasWelcomeBeat = false;

  HostAction get _desired => HostActions.forState(widget.state);

  static Duration _holdFor(HostAction action) => switch (action) {
        HostAction.correct => const Duration(milliseconds: 5200),
        HostAction.wrong => const Duration(milliseconds: 5200),
        HostAction.reveal => const Duration(milliseconds: 4500),
        // Long ElevenLabs welcome intro — keep wave+lipsync for the full line.
        HostAction.welcome => const Duration(milliseconds: 75000),
        HostAction.winner => const Duration(milliseconds: 6000),
        HostAction.listening => Duration.zero,
      };

  void _applyAction(HostAction next, DateTime now, {bool restart = false}) {
    if (next == _shown && !restart) return;
    _shown = next;
    _actionStartedAt = now;
    final hold = _holdFor(next);
    _stickyUntil = hold == Duration.zero ? now : now.add(hold);
    if (hold > Duration.zero) {
      Future<void>.delayed(hold, () {
        if (!mounted) return;
        if (DateTime.now().isBefore(_stickyUntil)) return;
        final catchUp = _desired;
        if (catchUp != _shown) {
          setState(() {
            _applyAction(catchUp, DateTime.now());
          });
        }
      });
    }
  }

  void _syncAction({bool force = false}) {
    final next = _desired;
    final now = DateTime.now();
    if (!force && now.isBefore(_stickyUntil) && next == HostAction.listening) {
      return;
    }
    _applyAction(next, now, restart: force);
  }

  @override
  void initState() {
    super.initState();
    _syncAction(force: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final path in HostAssets.allPrecache) {
        precacheImage(AssetImage(path), context);
      }
    });
  }

  @override
  void didUpdateWidget(_HostCentre oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = _shown;
    _syncAction();
    if (before != _shown || oldWidget.state.hostLine != widget.state.hostLine) {
      _gesture.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _gesture.dispose();
    _hostAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final openingBeat =
        widget.state.wordIndex == 0 && widget.state.feed.isEmpty;
    bool voicePlaying = false;
    bool introPlaying = false;
    try {
      voicePlaying =
          context.select<AudioController, bool>((a) => a.voicePlaying);
      introPlaying =
          context.select<AudioController, bool>((a) => a.hostIntroPlaying);
    } catch (_) {}

    final animState = HostStateResolver.resolve(
      state: widget.state,
      voicePlaying: voicePlaying,
      introPlaying: introPlaying,
      stickyAction: _shown,
      inOpeningBeat: openingBeat,
    );

    final inWelcomeBeat = openingBeat &&
        (introPlaying ||
            animState == HostAnimationState.entering ||
            animState == HostAnimationState.welcome ||
            animState == HostAnimationState.speaking);

    if (inWelcomeBeat && !_wasWelcomeBeat) {
      _welcomeStartedAt = DateTime.now();
    } else if (!inWelcomeBeat) {
      _welcomeStartedAt = null;
    }
    _wasWelcomeBeat = inWelcomeBeat;

    final welcomeElapsed = _welcomeStartedAt == null
        ? 0.0
        : DateTime.now().difference(_welcomeStartedAt!).inMilliseconds /
            1000.0;

    final actionElapsed =
        DateTime.now().difference(_actionStartedAt).inMilliseconds / 1000.0;

    double mouthOpen = 0;
    try {
      mouthOpen = context.select<AudioController, double>((a) => a.mouthOpen);
    } catch (_) {}

    return AnimatedBuilder(
      animation: _gesture,
      builder: (context, child) {
        // Keep host size locked while speaking — no push-in / pop scale.
        const scale = 1.0;

        return HostWidget(
          width: widget.maxWidth,
          height: widget.maxHeight,
          controller: _hostAnim,
          mouthAmplitude: mouthOpen,
          animationState: animState,
          stickyAction: _shown,
          voicePlaying: voicePlaying,
          welcomeElapsedSec: welcomeElapsed,
          actionElapsedSec: actionElapsed,
          inOpeningBeat: inWelcomeBeat,
          scale: scale,
        );
      },
    );
  }
}
