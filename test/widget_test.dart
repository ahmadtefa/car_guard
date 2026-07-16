import 'package:car_guard/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CarGuardApp(),
      ),
    );

    expect(find.byType(CarGuardApp), findsOneWidget);
  });
}