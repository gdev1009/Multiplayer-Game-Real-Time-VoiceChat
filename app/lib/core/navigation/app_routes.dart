/// Centralized route names for the app's navigation shell.
///
/// The post-login Opening screen is shown by the [AuthGate] (it is the
/// MaterialApp `home`), so it has no named route here. These names cover the
/// destinations reachable from the Opening screen.
class AppRoutes {
  AppRoutes._();

  /// "Check Upcoming Games" — the lobby hub (create/join/quick-match, M4).
  static const String upcomingGames = '/upcoming-games';

  /// The live game room a player enters after creating or joining a game (M4).
  static const String lobbyRoom = '/lobby-room';

  /// Enter a friend's 4-digit code to join their game (M4).
  static const String joinByCode = '/join-by-code';

  /// "Enter the Studio" — host a game and share the code, or join with one (M4).
  static const String studio = '/studio';

  /// Character builder — create or edit the player's paper-doll character.
  static const String character = '/character';
}
