import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

/// Reads and writes the `profiles` table.
class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  /// Inserts a new profile row plus the PIN hash/salt. The PIN columns are
  /// write-only from the client's perspective (RLS allows insert/update of own
  /// row only); they are never selected back into the app.
  Future<void> createProfile({
    required String userId,
    required String firstName,
    required String deviceId,
    required String pinHash,
    required String pinSalt,
    required bool grantTrial,
  }) async {
    await _client.from('profiles').insert({
      'id': userId,
      'first_name': firstName.trim(),
      'device_id': deviceId,
      'pin_hash': pinHash,
      'pin_salt': pinSalt,
      'trial_used': grantTrial,
      'trial_started_at':
          grantTrial ? DateTime.now().toUtc().toIso8601String() : null,
    });
  }

  /// Fetches the current signed-in user's profile, or null if none.
  Future<Profile?> currentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  /// Returns the stored PIN salt + hash for the current user, or null.
  Future<({String salt, String hash})?> pinCredentials() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('pin_salt, pin_hash')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return (salt: row['pin_salt'] as String, hash: row['pin_hash'] as String);
  }

  /// Updates the PIN hash/salt for the current user (used by recovery).
  Future<void> updatePin({
    required String pinHash,
    required String pinSalt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot update PIN without a signed-in user.');
    }
    await _client
        .from('profiles')
        .update({'pin_hash': pinHash, 'pin_salt': pinSalt}).eq('id', userId);
  }
}
