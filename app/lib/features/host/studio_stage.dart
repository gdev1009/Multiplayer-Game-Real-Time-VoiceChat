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

  // Play rectangle — matches match-word-studio-updated.png proportions.
  static const rectTop = 0.318; // just under WORD letters
  static const dockZone = 0.118;
  static const rowGap = 0.012; // gap between upper & lower seat rows

  // Horizontal: seats flank the host without swallowing the aisle.
  static const seatOverhang = 0.045;
  static const maxSeatWidth = 0.50;

  // Host — dominant centre figure; slight right nudge so A1 clears his shoulder.
  static const hostWidth = 0.50;
  static const hostShiftX = 0.018;

  // Seat PNG interior — avatar fills the blue chair back above the nameplate.
  static const avatarBottom = 0.36;
  // Active (Seat_on) gold fill — keep text inside the yellow (fitWidth overflowed).
  static const nameplateTopOn = 0.628;
  static const nameplateHeightOn = 0.058;
  static const nameplateInsetXOn = 0.255;
  // Inactive (Seat_off) dark title fill.
  static const nameplateTopOff = 0.580;
  static const nameplateHeightOff = 0.095;
  static const nameplateInsetXOff = 0.150;

  // Intrinsic seat art sizes (on/off canvases differ — keep overlays in art space).
  static const seatOnW = 447.0;
  static const seatOnH = 558.0;
  static const seatOffW = 454.0;
  static const seatOffH = 550.0;
}

double _clamp(double v, double min, double max) => v.clamp(min, max).toDouble();

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
    final maxHostW = _clamp(w * _RefLayout.hostWidth, 200.0, 360.0);
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
  });

  final MatchState state;
  final String? viewerRole;
  final Map<String, Character> charactersByRole;
  final double bottomInset;
  final bool showScoreboards;

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
                ),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // 1. Full background — curtains, arch, MATCH WORD, floor.
              const Positioned.fill(
                child: Image(
                  image: AssetImage(_kBg),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
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

              // 4. Host (dynamic — not part of the three stage PNGs).
              Positioned(
                left: hostLeft,
                top: hostTop,
                width: hostW,
                height: hostH,
                child: ExcludeFocus(
                  child: _HostCentre(
                    state: state,
                    maxWidth: hostW,
                    maxHeight: hostH,
                  ),
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

              // 7. Team scores in the baked top rectangles.
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
  });

  final MatchState state;
  final String role;
  final double width;
  final double height;
  final Character? character;
  final bool foreground;

  bool get _active {
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
    for (var i = state.feed.length - 1; i >= 0; i--) {
      final e = state.feed[i];
      if (e.role != role || e.wordIndex != state.wordIndex) continue;
      // Hide a stale clue while this seat is composing the next one.
      if (state.step == TurnStep.awaitingClue &&
          e.kind == PlayKind.clue &&
          role == state.clueGiverRole) {
        return null;
      }
      return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = state.names[role] ?? role;
    final team = role.isNotEmpty ? role[0] : '?';
    final active = _active;
    final line = _line;

    final artW = active ? _RefLayout.seatOnW : _RefLayout.seatOffW;
    final artH = active ? _RefLayout.seatOnH : _RefLayout.seatOffH;
    final inset = foreground ? 0.10 : 0.12;
    // Chair-back opening: head/shoulders fill the blue pad above the plate.
    final avatarTopFrac = foreground ? 0.06 : 0.08;
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
                final avatarTop = ah * avatarTopFrac;
                final avatarBottom = ah * _RefLayout.avatarBottom;
                return Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      active ? _kSeatOn : _kSeatOff,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                    Positioned(
                      left: aw * inset,
                      right: aw * inset,
                      top: avatarTop,
                      bottom: avatarBottom,
                      child: ClipRect(
                        child: _PlayerBust(
                          name: name,
                          seed: role,
                          character: character,
                          width: aw * (1 - inset * 2),
                          height: ah - avatarTop - avatarBottom,
                          foreground: foreground,
                        ),
                      ),
                    ),
                    Positioned(
                      left: aw * plateInsetX,
                      right: aw * plateInsetX,
                      top: ah * plateTop,
                      height: ah * plateH,
                      child: _NameplateText(
                        team: team,
                        name: name,
                        active: active,
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

    // Just under the nameplate (not below the whole pod — that floated onto
    // the host / other seats / the dock).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        pod,
        Positioned(
          left: width * 0.08,
          right: width * 0.08,
          top: height * 0.70,
          child: Center(
            child: _PlayerBubble(entry: line),
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
    // White on gold and dark plates.
    const color = Color(0xFFFFFFFF);
    // Fill the seat label without spilling past the gold/dark chrome.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: active ? 4 : 5,
        vertical: active ? 2 : 2,
      ),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: Text(
            '$team  $name',
            key: ValueKey<bool>(active),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: active ? 48 : 44,
              height: 1.0,
              letterSpacing: 0.3,
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
  const _PlayerBubble({required this.entry});

  final PlayEntry entry;

  static const _tailH = 8.0;
  static const _radius = 16.0;

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
    final label = entry.kind == PlayKind.clue
        ? '“$raw”'
        : isTimeout
            ? 'TIME'
            : raw;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220, minWidth: 96),
      child: CustomPaint(
        painter: _SpeechBubblePainter(
          fill: bg.withValues(alpha: 0.98),
          border: border,
          borderWidth: correct || wrong ? 2.4 : 1.4,
          radius: _radius,
          tailHeight: _tailH,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10 + _tailH, 14, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (correct || wrong) ...[
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: fg,
                  size: 26,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    height: 1.0,
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
  });

  final Color fill;
  final Color border;
  final double borderWidth;
  final double radius;
  final double tailHeight;

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

  /// Bubble body with a short upward tail (sits under the seat).
  Path _path(Size size) {
    final w = size.width;
    final h = size.height;
    final th = tailHeight;
    final top = th;
    final r = radius.clamp(0.0, (h - th) / 2).toDouble();
    final midX = w * 0.5;
    const tw = 9.0; // short tail half-width
    return Path()
      ..moveTo(midX, 0)
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
      ..close();
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter old) =>
      old.fill != fill ||
      old.border != border ||
      old.borderWidth != borderWidth ||
      old.radius != radius ||
      old.tailHeight != tailHeight;
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
      // Sitting look from standing art: clip to the chair back and zoom into
      // head + shoulders only (never show legs / full standing body).
      final bustScale = widget.foreground ? 2.85 : 2.70;
      final render = math.max(boxW, boxH) * 1.12;
      return SizedBox(
        width: boxW,
        height: boxH,
        child: ClipRect(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                  Color(0x00FFFFFF),
                ],
                // Soft fade at the chest so it reads as a seated bust.
                stops: [0.0, 0.62, 0.92],
              ).createShader(bounds);
            },
            child: Transform.translate(
              // Nudge down so shoulders sit on the nameplate line.
              offset: Offset(0, boxH * 0.10),
              child: Transform.scale(
                scale: bustScale,
                // Pivot near the head so legs stay clipped away.
                alignment: const Alignment(0, -0.88),
                child: IdleCharacterPreview(
                  character: character,
                  size: render,
                  showBackdrop: false,
                  animatePoses: false,
                  idleIntensity: 0.18,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: const Alignment(0, 0.35),
      child: Image.asset(
        widget.seed.hashCode.isEven
            ? 'assets/images/host/bust-female.png'
            : 'assets/images/host/bust-male.png',
        width: boxW * 0.85,
        height: boxH * 0.85,
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
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  late final AnimationController _gesture = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  HostAction _shown = HostAction.listening;
  DateTime _stickyUntil = DateTime.fromMillisecondsSinceEpoch(0);

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

  void _syncAction({bool force = false}) {
    final next = _desired;
    final now = DateTime.now();
    if (!force && now.isBefore(_stickyUntil) && next == HostAction.listening) {
      return;
    }
    if (next != _shown) {
      _shown = next;
      final hold = _holdFor(next);
      _stickyUntil = hold == Duration.zero ? now : now.add(hold);
      if (hold > Duration.zero) {
        Future<void>.delayed(hold, () {
          if (!mounted) return;
          if (DateTime.now().isBefore(_stickyUntil)) return;
          final catchUp = _desired;
          if (catchUp != _shown) {
            setState(() {
              _shown = catchUp;
              _stickyUntil = DateTime.now();
            });
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _shown = _desired;
    _syncAction(force: true);
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
    _idle.dispose();
    _gesture.dispose();
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
    } catch (_) {
      // Demo / screenshot hosts may omit AudioController.
    }

    // Welcome wave for the whole intro — no mouth overlay (it left a blotch).
    final useWelcome = _shown == HostAction.welcome ||
        ((introPlaying || voicePlaying) && openingBeat);
    final useListening = !useWelcome && _shown == HostAction.listening;

    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _gesture]),
      builder: (context, child) {
        final bob = math.sin(_idle.value * math.pi) * 0.4;
        final breathe = 1 + math.sin(_idle.value * math.pi) * 0.005;
        final pop = Curves.easeOutCubic.transform(_gesture.value);
        final scale = 1 + pop.clamp(0.0, 1.0) * 0.02;

        // Action clips are 480×480 with transparent padding — scale up a bit.
        final frameScale = useListening
            ? 1.0
            : (widget.maxHeight / (widget.maxWidth * 0.95)).clamp(1.12, 1.50);

        Widget figure;
        if (useWelcome) {
          figure = Transform.scale(
            scale: frameScale,
            alignment: Alignment.topCenter,
            child: Image.asset(
              HostActions.webpFor(HostAction.welcome),
              key: const ValueKey('welcome-wave'),
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Image.asset(
                HostActions.gifFor(HostAction.welcome),
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/host/host-idle.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          );
        } else if (useListening) {
          // Idle listening pose — no lipsync.
          figure = Image.asset(
            'assets/images/host/host-idle.png',
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/host/host-stage.png',
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
            ),
          );
        } else {
          // Outcome actions: authored WebP/GIF clip as-is.
          figure = Transform.scale(
            scale: frameScale,
            alignment: Alignment.topCenter,
            child: Image.asset(
              HostActions.webpFor(_shown),
              key: ValueKey(_shown),
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Image.asset(
                HostActions.gifFor(_shown),
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Image.asset(
                  HostActions.framesFor(_shown)[1],
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          );
        }

        return Transform.translate(
          offset: Offset(0, -bob),
          child: Transform.scale(
            scale: scale * breathe,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: widget.maxWidth,
              height: widget.maxHeight,
              child: figure,
            ),
          ),
        );
      },
    );
  }
}
