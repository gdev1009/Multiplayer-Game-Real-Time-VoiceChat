import 'package:flutter/foundation.dart';

import '../../models/character.dart';
import '../../services/character_service.dart';
import 'character_catalog.dart';

/// Holds the in-progress (draft) character while the player builds it, and
/// loads/saves it through [CharacterService].
class CharacterController extends ChangeNotifier {
  CharacterController(this._service);

  final CharacterService _service;

  /// The character currently being edited.
  Character _draft = const Character(displayName: '');
  Character get draft => _draft;

  /// The last saved character, or null if the player hasn't built one yet.
  Character? _saved;
  Character? get saved => _saved;
  bool get hasCharacter => _saved != null;

  bool _busy = false;
  bool get busy => _busy;

  /// Loads any existing character from the backend (call after sign-in).
  Future<void> load() async {
    _setBusy(true);
    try {
      _saved = await _service.loadCharacter();
      // Start the draft from the saved character so editing is seamless.
      _draft = _saved ?? const Character(displayName: '');
    } finally {
      _setBusy(false);
    }
  }

  /// Resets the draft to a blank character (used by "create from scratch").
  void startNew() {
    _draft = const Character(displayName: '');
    notifyListeners();
  }

  /// Resets the draft to the last saved character (used by "edit").
  void startEdit() {
    _draft = _saved ?? const Character(displayName: '');
    notifyListeners();
  }

  /// Sets (or clears, when [id] is null) the chosen option for a layer.
  void chooseOption(CharacterLayer layer, String? id) {
    switch (layer) {
      case CharacterLayer.base:
        // Changing body swaps every option set, so reset the body-specific
        // choices and dress the new body in its first outfit right away.
        if (id != null && id != _draft.base) {
          _draft = _draft.copyWith(
            base: id,
            hair: null,
            outfit: CharacterCatalog.defaultOutfitFor(id),
            glasses: null,
            hat: null,
            // earrings are shared across bodies, so they can stay.
            accessory: null,
          );
        }
      case CharacterLayer.hair:
        // Picking a style for the first time also settles on a colour, so the
        // preview never shows the untinted grey art.
        _draft = _draft.copyWith(
          hair: id,
          hairColor: id == null
              ? _draft.hairColor
              : (_draft.hairColor ?? CharacterCatalog.defaultHairColorId),
        );
      case CharacterLayer.outfit:
        _draft = _draft.copyWith(outfit: id);
      case CharacterLayer.glasses:
        _draft = _draft.copyWith(glasses: id);
      case CharacterLayer.hat:
        _draft = _draft.copyWith(hat: id);
      case CharacterLayer.earrings:
        _draft = _draft.copyWith(earrings: id);
      case CharacterLayer.accessory:
        _draft = _draft.copyWith(accessory: id);
    }
    notifyListeners();
  }

  /// The currently chosen option id for a layer, or null.
  String? selected(CharacterLayer layer) => switch (layer) {
        CharacterLayer.base => _draft.base,
        CharacterLayer.hair => _draft.hair,
        CharacterLayer.outfit => _draft.outfit,
        CharacterLayer.glasses => _draft.glasses,
        CharacterLayer.hat => _draft.hat,
        CharacterLayer.earrings => _draft.earrings,
        CharacterLayer.accessory => _draft.accessory,
      };

  /// The chosen hair colour id, falling back to the catalog default so the
  /// swatch row always shows a selection.
  String get hairColorId =>
      _draft.hairColor ?? CharacterCatalog.defaultHairColorId;

  /// Sets the hair colour tint applied to the neutral hair art.
  void setHairColor(String id) {
    _draft = _draft.copyWith(hairColor: id);
    notifyListeners();
  }

  void setDisplayName(String name) {
    _draft = _draft.copyWith(displayName: name);
    notifyListeners();
  }

  /// Whether the draft is complete enough to save.
  bool get isComplete =>
      _draft.displayName.trim().isNotEmpty &&
      _draft.base != null &&
      _draft.outfit != null;

  /// Persists the draft and updates the saved character.
  Future<void> save() async {
    _setBusy(true);
    try {
      final toSave = _draft.copyWith(displayName: _draft.displayName.trim());
      await _service.saveCharacter(toSave);
      _saved = toSave;
      _draft = toSave;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
