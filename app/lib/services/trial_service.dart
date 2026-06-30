import 'package:supabase_flutter/supabase_flutter.dart';

/// Records and checks the device-id trial ledger.
///
/// The ledger lives in the `device_trials` table. The logic runs silently:
/// when a brand-new account is created we check whether this device has ever
/// started a trial before. If it has, no new trial is granted.
class TrialService {
  TrialService(this._client);

  final SupabaseClient _client;

  /// Returns true if this device has already consumed a free trial.
  Future<bool> hasUsedTrial(String deviceId) async {
    final rows = await _client
        .from('device_trials')
        .select('device_id')
        .eq('device_id', deviceId)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// Records the start of a trial for [deviceId]. Safe to call once per new
  /// account; duplicate device ids are ignored by the table's primary key.
  Future<void> recordTrialStart(String deviceId) async {
    await _client.from('device_trials').upsert(
      {'device_id': deviceId},
      onConflict: 'device_id',
      ignoreDuplicates: true,
    );
  }
}
