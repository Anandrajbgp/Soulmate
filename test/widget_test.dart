import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soulmate/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Splash screen se Login screen tak ka flow',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'is_logged_in': false});

    await tester.pumpWidget(const MyApp());

    // Logo/title animation 45% ke baad hi tree me aata hai (0-1450ms).
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('SoulMate AI'), findsOneWidget);

    // Baaki splash animation (3.2s total) + fade transition (0.8s).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Logged-out user ko login screen dikhni chahiye.
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });
}

