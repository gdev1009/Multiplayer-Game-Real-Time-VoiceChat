import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:match_word/features/game/computer_play.dart';
import 'package:match_word/features/game/computer_play_controller.dart';
import 'package:match_word/features/game/computer_players_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Easy, Medium, and Hard can be chosen and remembered',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final skill = ComputerPlayController(prefs: prefs);
    await skill.ready;

    await tester.pumpWidget(
      ChangeNotifierProvider<ComputerPlayController>.value(
        value: skill,
        child: const MaterialApp(home: Scaffold(body: ComputerPlayersPicker())),
      ),
    );

    expect(find.text('Computer players'), findsOneWidget);
    expect(
      find.text(
        'They get some answers wrong, and sometimes think a little longer.',
      ),
      findsOneWidget,
    );
    expect(skill.level, ComputerPlayLevel.medium);

    await tester.tap(find.text('Easy'));
    await tester.pump();
    expect(skill.level, ComputerPlayLevel.easy);
    expect(
      find.text('They miss more often, and take their time.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Hard'));
    await tester.pump();
    expect(skill.level, ComputerPlayLevel.hard);

    final again = ComputerPlayController(prefs: prefs);
    await again.ready;
    expect(again.level, ComputerPlayLevel.hard);
  });

  test('a saved name that is not a level falls back to Medium', () async {
    SharedPreferences.setMockInitialValues({'computer.playLevel': 'expert'});
    final prefs = await SharedPreferences.getInstance();
    final skill = ComputerPlayController(prefs: prefs);
    await skill.ready;
    expect(skill.level, ComputerPlayLevel.medium);
  });
}
