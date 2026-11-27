import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'computer_play.dart';

/// The host's Easy / Medium / Hard choice, remembered on this phone.
class ComputerPlayController extends ChangeNotifier {
  ComputerPlayController({SharedPreferences? prefs}) : _prefs = prefs {
    ready = _load();
  }

  static const _key = 'computer.playLevel';

  SharedPreferences? _prefs;
  ComputerPlayLevel _level = ComputerPlayLevel.medium;

  /// Completes once a saved choice, if any, has been read.
  late final Future<void> ready;

  ComputerPlayLevel get level => _level;

  Future<void> _load() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    _level = ComputerPlayLevel.fromName(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> setLevel(ComputerPlayLevel level) async {
    if (_level == level) return;
    _level = level;
    notifyListeners();
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_key, level.name);
  }
}
