import 'package:car_guard/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots without crashing', (WidgetTester tester) async {
    // Provide an in-memory SharedPreferences instance so the settings and
    // device providers can load without platform channels.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const ProviderScope(
        child: CarGuardApp(),
      ),
    );

    expect(find.byType(CarGuardApp), findsOneWidget);
  });
}
