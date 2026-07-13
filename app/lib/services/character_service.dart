import 'package:flutter/foundation.dart';
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
    try {
      await _client
          .from('characters')
          .upsert(character.toMap(profileId), onConflict: 'profile_id');
    } on PostgrestException catch (e) {
      debugPrint(
        '[CharacterService] saveCharacter failed: ${e.code} ${e.message} '
        '(details: ${e.details}, hint: ${e.hint})',
      );
      final msg = e.message.toLowerCase();
      if (e.code == '42P01' ||
          e.code == '42703' || // undefined_column
          msg.contains('does not exist')) {
        throw const CharacterSaveException(
          'Your character could not be saved because the app needs a quick '
          'setup on the server. Please contact support.',
        );
      }
      throw const CharacterSaveException(
        'Your character could not be saved. Please try again.',
      );
    }
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

/// A user-facing error raised when a character cannot be saved. The [message]
/// is safe to show; the real cause is written to the debug log.
class CharacterSaveException implements Exception {
  const CharacterSaveException(this.message);
  final String message;
  @override
  String toString() => 'CharacterSaveException: $message';
}
