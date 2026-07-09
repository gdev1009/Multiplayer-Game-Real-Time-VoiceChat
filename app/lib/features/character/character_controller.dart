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
    _draft = switch (layer) {
      CharacterLayer.base => _draft.copyWith(base: id),
      CharacterLayer.hair => _draft.copyWith(hair: id),
      CharacterLayer.eyes => _draft.copyWith(eyes: id),
      CharacterLayer.glasses => _draft.copyWith(glasses: id),
      CharacterLayer.outfit => _draft.copyWith(outfit: id),
    };
    // Give tintable layers a sensible default colour the moment a style is
    // picked, and clear the colour when the player chooses "None".
    if (layer.tintable) {
      if (id == null) {
        _draft = switch (layer) {
          CharacterLayer.base => _draft.copyWith(baseColor: null),
          CharacterLayer.hair => _draft.copyWith(hairColor: null),
          CharacterLayer.eyes => _draft.copyWith(eyeColor: null),
          _ => _draft,
        };
      } else if (selectedColor(layer) == null) {
        final defaultTint = CharacterCatalog.tintsFor(layer).first.id;
        _draft = switch (layer) {
          CharacterLayer.base => _draft.copyWith(baseColor: defaultTint),
          CharacterLayer.hair => _draft.copyWith(hairColor: defaultTint),
          CharacterLayer.eyes => _draft.copyWith(eyeColor: defaultTint),
          _ => _draft,
        };
      }
    }
    notifyListeners();
  }

  /// The currently chosen option id for a layer, or null.
  String? selected(CharacterLayer layer) => switch (layer) {
        CharacterLayer.base => _draft.base,
        CharacterLayer.hair => _draft.hair,
        CharacterLayer.eyes => _draft.eyes,
        CharacterLayer.glasses => _draft.glasses,
        CharacterLayer.outfit => _draft.outfit,
      };

  /// Sets (or clears, when [id] is null) the tint colour for a tintable layer.
  void chooseColor(CharacterLayer layer, String? id) {
    _draft = switch (layer) {
      CharacterLayer.base => _draft.copyWith(baseColor: id),
      CharacterLayer.hair => _draft.copyWith(hairColor: id),
      CharacterLayer.eyes => _draft.copyWith(eyeColor: id),
      _ => _draft,
    };
    notifyListeners();
  }

  /// The currently chosen tint id for a tintable layer, or null.
  String? selectedColor(CharacterLayer layer) => switch (layer) {
        CharacterLayer.base => _draft.baseColor,
        CharacterLayer.hair => _draft.hairColor,
        CharacterLayer.eyes => _draft.eyeColor,
        _ => null,
      };

  void setDisplayName(String name) {
    _draft = _draft.copyWith(displayName: name);
    notifyListeners();
  }

  /// Whether the draft is complete enough to save.
  bool get isComplete =>
      _draft.displayName.trim().isNotEmpty && _draft.base != null;

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
