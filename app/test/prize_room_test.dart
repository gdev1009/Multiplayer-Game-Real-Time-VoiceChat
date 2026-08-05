import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/models/prize.dart';

void main() {
  group('PrizeRoom Phase-1 win trophies', () {
    test('winTrophyCount matches gamesWon', () {
      const room = PrizeRoom(gamesPlayed: 5, gamesWon: 3, items: []);
      expect(room.winTrophyCount, 3);
      expect(room.winCups().length, 3);
    });

    test('winCups are capped for layout', () {
      const room = PrizeRoom(gamesPlayed: 40, gamesWon: 20, items: []);
      expect(room.winCups(maxVisible: 12).length, 12);
    });

    test('signInTrophyLine encourages return play', () {
      expect(
        const PrizeRoom(gamesPlayed: 0, gamesWon: 0, items: []).signInTrophyLine,
        contains('Win a game'),
      );
      expect(
        const PrizeRoom(gamesPlayed: 1, gamesWon: 1, items: []).signInTrophyLine,
        contains('1 trophy'),
      );
      expect(
        const PrizeRoom(gamesPlayed: 4, gamesWon: 3, items: []).signInTrophyLine,
        contains('3 trophies'),
      );
      // Ronna: call them trophies (not “play/win trophies”).
      expect(
        const PrizeRoom(gamesPlayed: 4, gamesWon: 3, items: []).signInTrophyLine,
        isNot(contains('play troph')),
      );
    });

    test('yearly tournament qualifier is 50 trophies', () {
      expect(PrizeAssets.yearlyTournamentTrophyQualifier, 50);
    });

    test('gamesLost accounts for ties', () {
      const room = PrizeRoom(
        gamesPlayed: 5,
        gamesWon: 2,
        gamesTied: 1,
        items: [],
      );
      expect(room.gamesLost, 2);
      expect(MatchOutcome.tie.rpcValue, 'tie');
    });

    test('milestoneTrophies exclude the win-cup catalog id', () {
      const room = PrizeRoom(
        gamesPlayed: 2,
        gamesWon: 2,
        items: [
          PrizeItem(
            id: 'trophy-win-cup',
            kind: 'trophy',
            title: 'Win Trophy',
            description: '',
            assetPath: PrizeAssets.winCup,
            sortOrder: 5,
            earned: true,
          ),
          PrizeItem(
            id: 'trophy-first-win',
            kind: 'trophy',
            title: 'First Win',
            description: '',
            assetPath: PrizeAssets.winCup,
            sortOrder: 10,
            earned: true,
          ),
        ],
      );
      expect(room.milestoneTrophies.map((i) => i.id), ['trophy-first-win']);
      expect(PrizeAssets.showNoveltyPrizes, isFalse);
    });
  });
}
