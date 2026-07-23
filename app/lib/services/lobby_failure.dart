/// A user-facing lobby error, raised by [LobbyService] when a game action
/// cannot complete. The [message] is safe to show in large, calm text; the
/// optional [code] is a machine-readable reason from the server.
class LobbyFailure implements Exception {
  const LobbyFailure(this.message, {this.code});

  final String message;
  final String? code;

  /// Maps a server `reason` tag to a senior-friendly message.
  factory LobbyFailure.fromReason(String? reason) {
    switch (reason) {
      case 'not_found':
        return const LobbyFailure(
          "We couldn't find a game with that code. Please check the four "
          'numbers and try again.',
          code: 'not_found',
        );
      case 'full':
        return const LobbyFailure(
          'That game is already full. Try another code or start your own.',
          code: 'full',
        );
      case 'not_host':
        return const LobbyFailure(
          'Only the person who made the game can do that.',
          code: 'not_host',
        );
      case 'not_in_lobby':
        return const LobbyFailure(
          'That game has already started.',
          code: 'not_in_lobby',
        );
      case 'need_more_players':
        return const LobbyFailure(
          'You need at least two players to start. Add more players first.',
          code: 'need_more_players',
        );
      case 'no_profile':
        return const LobbyFailure(
          'Please finish setting up your account first.',
          code: 'no_profile',
        );
      case 'not_signed_in':
        return const LobbyFailure(
          'Please sign in again to play.',
          code: 'not_signed_in',
        );
      case 'no_secret':
        return const LobbyFailure(
          'The word is still loading. Please try again in a moment.',
          code: 'no_secret',
        );
      case 'not_awaiting_guess':
        return const LobbyFailure(
          'That word is already done — wait for the next one.',
          code: 'not_awaiting_guess',
        );
      default:
        return LobbyFailure(
          'Something went wrong. Please try again.',
          code: reason,
        );
    }
  }

  @override
  String toString() => 'LobbyFailure($code): $message';
}
