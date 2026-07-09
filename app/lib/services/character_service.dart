import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/character.dart';

/// Reads and writes the `characters` table (one row per profile).
///
/// RLS restricts every operation to the signed-in user's own row, so all
/// methods rely on the current Supabase session for the profile id.
class CharacterService {
  CharacterService(this._client);

  final SupabaseClient _client;

  String? get _profileId => _client.auth.currentUser?.id;

  /// Loads the current user's saved character, or null if none exists yet.
  Future<Character?> loadCharacter() async {
    final profileId = _profileId;
    if (profileId == null) return null;
    final row = await _client
        .from('characters')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    return row == null ? null : Character.fromMap(row);
  }

  /// Creates or updates the current user's character.
  Future<void> saveCharacter(Character character) async {
    final profileId = _profileId;
    if (profileId == null) {
      throw StateError('Cannot save a character without a signed-in user.');
    }
    await _client
        .from('characters')
        .upsert(character.toMap(profileId), onConflict: 'profile_id');
  }

  /// Whether the current user has already built a character.
  Future<bool> hasCharacter() async {
    final profileId = _profileId;
    if (profileId == null) return false;
    final row = await _client
        .from('characters')
        .select('profile_id')
        .eq('profile_id', profileId)
        .maybeSingle();
    return row != null;
  }
}
