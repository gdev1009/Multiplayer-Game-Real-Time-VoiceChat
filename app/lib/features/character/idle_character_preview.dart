import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/idle_animation.dart';
import '../../models/character.dart';
import 'character_poses.dart';
import 'character_preview.dart';

/// Character preview that breathes and periodically cycles named pose frames
/// generated from the current artist base bodies
/// (`tools/generate_idle_poses.py`).
///
/// Face-only poses (tongue / worry / smug) are preferred by default so layered
/// hair / glasses / outfit stay registered. Pass [includeGestures] to also
/// cycle shrug / hairfix / selfie.
class IdleCharacterPreview extends StatefulWidget {
  const IdleCharacterPreview({
    super.key,
    required this.character,
    this.size = 92,
    this.showBackdrop = true,
    this.includeGestures = false,
    this.animatePoses = true,
    this.poseHold = const Duration(seconds: 3),
    this.neutralHold = const Duration(seconds: 5),
    this.mouthOpen = 0,
    this.idleIntensity = 1.0,
  });

  final Character character;
  final double size;
  final bool showBackdrop;

  /// When true, also cycles arm gestures (shrug / hairfix / selfie). Prefer
  /// false when outfits are layered — arm poses can peek out oddly.
  final bool includeGestures;

  /// When false, stay on the neutral base (still breathes). Use on the studio
  /// stage until premium pose frames are regenerated.
  final bool animatePoses;

  /// How long each posed frame is held before returning to neutral.
  final Duration poseHold;

  /// How long the neutral (breathing) look is held between poses.
  final Duration neutralHold;

  /// Lipsync amplitude 0..1 forwarded to [CharacterPreview].
  final double mouthOpen;

  /// Scales IdleAnimation breathe/sway (use <1 on tight stage seats).
  final double idleIntensity;

  @override
  State<IdleCharacterPreview> createState() => _IdleCharacterPreviewState();
}

class _IdleCharacterPreviewState extends State<IdleCharacterPreview> {
  CharacterPose? _pose;
  int _index = 0;
  bool _showingPose = false;
  Timer? _timer;

  List<CharacterPose> get _cycle => widget.includeGestures
      ? CharacterPose.idleCycle
      : CharacterPose.faceCycle;

  @override
  void initState() {
    super.initState();
    if (widget.animatePoses) _scheduleNext();
  }

  @override
  void didUpdateWidget(covariant IdleCharacterPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.includeGestures != widget.includeGestures ||
        oldWidget.animatePoses != widget.animatePoses) {
      _index = 0;
      _pose = null;
      _showingPose = false;
      _timer?.cancel();
      if (widget.animatePoses) _scheduleNext();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNext() {
    _timer?.cancel();
    final delay = _showingPose ? widget.poseHold : widget.neutralHold;
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        if (_showingPose) {
          _pose = null;
          _showingPose = false;
        } else {
          final cycle = _cycle;
          final next = cycle.isEmpty ? null : cycle[_index % cycle.length];
          if (next == null ||
              poseAssetPath(widget.character.base, next) == null) {
            _pose = null;
            _showingPose = false;
          } else {
            _pose = next;
            _index++;
            _showingPose = true;
          }
        }
      });
      _scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return IdleAnimation(
      intensity: widget.idleIntensity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // Never stack the previous pose under the new one — crossfades left a
        // ghost double-face behind speech bubbles / feed cards.
        layoutBuilder: (currentChild, previousChildren) =>
            currentChild ?? const SizedBox.shrink(),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: CharacterPreview(
          key: ValueKey(_pose?.name ?? 'neutral'),
          character: widget.character,
          size: widget.size,
          showBackdrop: widget.showBackdrop,
          pose: _pose,
          mouthOpen: widget.mouthOpen,
        ),
      ),
    );
  }
}
