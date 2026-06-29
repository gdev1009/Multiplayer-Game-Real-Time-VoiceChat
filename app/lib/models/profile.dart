/// A player's profile as stored in the Supabase `profiles` table.
///
/// The email lives in Supabase Auth and is never shown in the app; it exists
/// only for PIN recovery.
class Profile {
  const Profile({
    required this.id,
    required this.firstName,
    required this.deviceId,
    required this.trialStartedAt,
    required this.trialUsed,
    required this.createdAt,
  });

  final String id;
  final String firstName;
  final String deviceId;
  final DateTime? trialStartedAt;
  final bool trialUsed;
  final DateTime createdAt;

  /// Days remaining in the 7-day free trial (0 if expired or none).
  int get trialDaysRemaining {
    final start = trialStartedAt;
    if (start == null) return 0;
    final end = start.add(const Duration(days: 7));
    final remaining = end.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      firstName: (map['first_name'] as String?) ?? '',
      deviceId: (map['device_id'] as String?) ?? '',
      trialStartedAt: map['trial_started_at'] == null
          ? null
          : DateTime.parse(map['trial_started_at'] as String),
      trialUsed: (map['trial_used'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsert() {
    return {
      'id': id,
      'first_name': firstName,
      'device_id': deviceId,
      'trial_started_at': trialStartedAt?.toIso8601String(),
      'trial_used': trialUsed,
    };
  }
}
