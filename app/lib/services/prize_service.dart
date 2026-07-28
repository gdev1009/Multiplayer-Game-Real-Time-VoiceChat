import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/prize.dart';

class PrizeFailure implements Exception {
  const PrizeFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Server-authoritative Prize Room operations.
class PrizeService {
  PrizeService(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const PrizeFailure('Something went wrong. Please try again.');
  }

  /// Loads the caller's shelves (catalog + earned flags + play stats).
  Future<PrizeRoom> myPrizeRoom() async {
    try {
      final res = _asMap(await _client.rpc('mw_my_prize_room'));
      if (res['ok'] != true) {
        throw const PrizeFailure('Could not open the Prize Room right now.');
      }
      return PrizeRoom.fromMap(res);
    } on PostgrestException catch (e) {
      debugPrint('[PrizeService] mw_my_prize_room failed: ${e.message}');
      throw const PrizeFailure('Could not open the Prize Room right now.');
    }
  }

  /// Records that the signed-in player finished a match. Grants Phase-1 clay /
  /// milestone trophies on wins. Soft-fails when offline or unsigned so
  /// gameplay never blocks on awards.
  Future<void> recordMatchResult({required MatchOutcome outcome}) async {
    if (_client.auth.currentUser == null) return;
    try {
      final res = _asMap(
        await _client.rpc(
          'mw_record_match_result',
          params: {'p_outcome': outcome.rpcValue},
        ),
      );
      if (res['ok'] != true) {
        debugPrint('[PrizeService] recordMatchResult: ${res['reason']}');
      }
    } on PostgrestException catch (e) {
      debugPrint('[PrizeService] recordMatchResult failed: ${e.message}');
    } catch (e) {
      debugPrint('[PrizeService] recordMatchResult ignored: $e');
    }
  }
}
