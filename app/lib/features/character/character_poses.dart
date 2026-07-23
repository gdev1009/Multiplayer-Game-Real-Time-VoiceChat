/// Named idle poses generated from the current artist base bodies
/// (`tools/generate_idle_poses.py`). Asset paths live under
/// `assets/images/character/poses/{female|male}/`.
enum CharacterPose {
  tongue,
  worry,
  smug,
  shrug,
  hairfix,
  selfie,
  /// Lipsync — mouth half-open (face only).
  talkMid,
  /// Lipsync — mouth open mid-speech (face only).
  talkOpen;

  /// Folder-friendly asset stem (matches the PNG filename).
  String get assetId => switch (this) {
        CharacterPose.talkMid => 'talk-mid',
        CharacterPose.talkOpen => 'talk-open',
        _ => name,
      };

  /// Faces that only change the expression — safe to stack under hair/glasses.
  bool get isFaceOnly =>
      this == CharacterPose.tongue ||
      this == CharacterPose.worry ||
      this == CharacterPose.smug ||
      this == CharacterPose.talkMid ||
      this == CharacterPose.talkOpen;

  bool get isTalk =>
      this == CharacterPose.talkMid || this == CharacterPose.talkOpen;

  /// All poses in the recommended idle-cycle order (gentle → playful).
  static const List<CharacterPose> idleCycle = [
    CharacterPose.smug,
    CharacterPose.worry,
    CharacterPose.tongue,
    CharacterPose.shrug,
    CharacterPose.hairfix,
    CharacterPose.selfie,
  ];

  /// Face-only subset — prefer these when hair/outfit layers are on.
  static const List<CharacterPose> faceCycle = [
    CharacterPose.smug,
    CharacterPose.worry,
    CharacterPose.tongue,
  ];

  /// Pick a talk pose from amplitude 0..1 (null = closed / neutral).
  static CharacterPose? talkFromAmplitude(double open) {
    if (open >= 0.48) return CharacterPose.talkOpen;
    if (open >= 0.14) return CharacterPose.talkMid;
    return null;
  }
}

/// Resolves a pose PNG path for a given base body id (`body-female` /
/// `body-male`). Returns null when the body is unknown so callers can fall
/// back to the neutral base.
String? poseAssetPath(String? baseId, CharacterPose pose) {
  final folder = switch (baseId) {
    'body-female' => 'female',
    'body-male' => 'male',
    _ => null,
  };
  if (folder == null) return null;
  return 'assets/images/character/poses/$folder/${pose.assetId}.png';
}
