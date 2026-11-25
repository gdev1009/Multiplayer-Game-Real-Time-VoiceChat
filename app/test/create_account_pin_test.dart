import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_word/features/auth/auth_controller.dart';
import 'package:match_word/features/auth/screens/create_account_screen.dart';
import 'package:match_word/services/auth_service.dart';
import 'package:match_word/services/device_service.dart';
import 'package:match_word/services/profile_service.dart';
import 'package:match_word/services/trial_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecordingAuth extends AuthController {
  _RecordingAuth(this.client)
      : super(
          AuthService(
            client: client,
            deviceService: DeviceService(),
            profileService: ProfileService(client),
            trialService: TrialService(client),
          ),
        );

  final SupabaseClient client;
  String? savedPin;

  @override
  Future<void> createAccount({
    required String firstName,
    required String email,
    required String pin,
  }) async {
    savedPin = pin;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the fourth PIN digit is kept and the repeat matches',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _RecordingAuth(SupabaseClient('http://localhost', 'anon'));
    addTearDown(auth.client.auth.stopAutoRefresh);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(home: CreateAccountScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Ronna');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ronna@example.com');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a 4-number PIN'), findsOneWidget);

    for (final digit in ['1', '9', '8', '4']) {
      await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
      await tester.pump();
    }

    // The last number stays on this page long enough to see all four dots.
    expect(find.text('Choose a 4-number PIN'), findsOneWidget);
    expect(find.bySemanticsLabel('4 of 4 numbers entered'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Type your PIN again'), findsOneWidget);
    expect(find.bySemanticsLabel('0 of 4 numbers entered'), findsOneWidget);

    // The tap that finished the first PIN must not already fill a dot here.
    await tester.pump(const Duration(milliseconds: 300));
    for (final digit in ['1', '9', '8', '4']) {
      await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
      await tester.pump();
    }
    expect(find.text('Type your PIN again'), findsOneWidget);
    expect(find.bySemanticsLabel('4 of 4 numbers entered'), findsOneWidget);
    expect(
      find.text('The two PINs do not match. Let\'s try again.'),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(auth.savedPin, '1984');
    expect(
      find.text('The two PINs do not match. Let\'s try again.'),
      findsNothing,
    );
    auth.client.auth.stopAutoRefresh();
  });
}
