import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'assets/host_assets.dart';
import 'facial_animation.dart';
import 'host_actions.dart';
import 'host_animation_state.dart';
import 'host_controller.dart';

/// Guy Smiley — full-frame talk pose swaps (baked natural mouths).
class HostWidget extends StatefulWidget {
  const HostWidget({
    super.key,
    required this.width,
    required this.height,
    required this.controller,
    required this.mouthAmplitude,
    required this.animationState,
    required this.stickyAction,
    required this.voicePlaying,
    required this.welcomeElapsedSec,
    required this.actionElapsedSec,
    required this.inOpeningBeat,
    this.scale = 1.0,
  });

  final double width;
  final double height;
  final HostAnimationController controller;
  final double mouthAmplitude;
  final HostAnimationState animationState;
  final HostAction stickyAction;
  final bool voicePlaying;
  final double welcomeElapsedSec;
  final double actionElapsedSec;
  final bool inOpeningBeat;
  final double scale;

  @override
  State<HostWidget> createState() => _HostWidgetState();
}

class _HostWidgetState extends State<HostWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: FacialTiming.breathCycleMs),
  )..repeat(reverse: true);

  final Map<String, ui.Image> _decoded = {};
  String? _shownAsset;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _warmDecode();
  }

  Future<void> _warmDecode() async {
    if (_loading) return;
    _loading = true;
    await _decode(HostAssets.bodyIdle);
    for (final path in HostAssets.welcomeTalkPoses) {
      await _decode(path);
    }
    if (mounted) setState(() {});
  }

  Future<ui.Image?> _decode(String path) async {
    final cached = _decoded[path];
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 880,
      );
      final frame = await codec.getNextFrame();
      _decoded[path] = frame.image;
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureShown(String path) async {
    if (_shownAsset == path && _decoded.containsKey(path)) return;
    final img = await _decode(path);
    if (!mounted || img == null) return;
    if (_shownAsset != path) {
      setState(() => _shownAsset = path);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    for (final img in _decoded.values) {
      img.dispose();
    }
    _decoded.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        widget.controller.tick(
          nowSec: DateTime.now().millisecondsSinceEpoch / 1000.0,
          lifePhase: _breath.value,
          state: widget.animationState,
          stickyAction: widget.stickyAction,
          mouthAmplitude: widget.mouthAmplitude,
          voicePlaying: widget.voicePlaying,
          welcomeElapsedSec: widget.welcomeElapsedSec,
          actionElapsedSec: widget.actionElapsedSec,
          inOpeningBeat: widget.inOpeningBeat,
        );
        final frame = widget.controller.frame;
        final want = frame.bodyAsset;
        if (_shownAsset != want && !_decoded.containsKey(want)) {
          _ensureShown(want);
        } else if (_decoded.containsKey(want) && _shownAsset != want) {
          _shownAsset = want;
        }
        final paintAsset = (_decoded.containsKey(want) ? want : null) ??
            _shownAsset ??
            (_decoded.keys.isNotEmpty ? _decoded.keys.first : null);
        final image = paintAsset == null ? null : _decoded[paintAsset];

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: image == null
              ? const SizedBox.shrink()
              : CustomPaint(
                  painter: _HostImagePainter(image: image),
                  size: Size(widget.width, widget.height),
                ),
        );
      },
    );
  }
}

/// Paints one full host body frame (mouth already baked into the PNG).
class _HostImagePainter extends CustomPainter {
  _HostImagePainter({required this.image});

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (iw <= 0 || ih <= 0 || size.isEmpty) return;

    final scale = (size.width / iw).clamp(0.0, size.height / ih);
    final dw = iw * scale;
    final dh = ih * scale;
    final dx = (size.width - dw) / 2;
    const dy = 0.0;
    final src = Rect.fromLTWH(0, 0, iw, ih);
    final dst = Rect.fromLTWH(dx, dy, dw, dh);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _HostImagePainter oldDelegate) =>
      oldDelegate.image != image;
}
