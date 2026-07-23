import 'package:flutter/foundation.dart';

import '../../models/prize.dart';
import '../../services/prize_service.dart';

/// Loads and refreshes the Prize Room for the signed-in player.
class PrizeController extends ChangeNotifier {
  PrizeController(this._service);

  final PrizeService _service;

  PrizeRoom _room = PrizeRoom.empty();
  PrizeRoom get room => _room;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _room = await _service.myPrizeRoom();
    } on PrizeFailure catch (e) {
      _error = e.message;
      _room = PrizeRoom.empty();
    } catch (e) {
      debugPrint('[PrizeController] load failed: $e');
      _error = 'Could not open the Prize Room right now.';
      _room = PrizeRoom.empty();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Seeds a finished-looking room for demos / progress recordings (no backend).
  void seedForDemo(PrizeRoom room) {
    _room = room;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  /// Soft-records a finished match. Safe to call from local demos (no-ops
  /// when unsigned / offline).
  Future<void> recordMatchResult({required bool won}) {
    return _service.recordMatchResult(won: won);
  }
}
