import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:restaurant_app_final/main_prod.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('post-release smoke test navigates to login', (tester) async {
    await app.main();

    // Allow the first frame and the splash timer to complete.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your 4-digit PIN'), findsOneWidget);
  });
}
