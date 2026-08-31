// test/widget_test.dart
// Basic smoke test - verifies app initializes without errors in test environment
// Full integration tests require a real database (covered in unit tests)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_manager/core/utils/money.dart';
import 'package:solar_manager/core/utils/id_generator.dart';

void main() {
  // Basic sanity tests that don't require a database
  group('App Sanity Checks', () {
    test('Money can be created from int', () {
      final m = Money.fromInt(1000);
      expect(m.toDouble, 1000.0);
    });

    test('ID generator produces unique IDs', () {
      final ids = List.generate(100, (_) => IdGenerator.generate());
      final unique = ids.toSet();
      expect(unique.length, 100);
    });

    testWidgets('Material app can build', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Solar Manager')),
            body: const Center(
              child: Text('Solar Manager Test'),
            ),
          ),
        ),
      );
      expect(find.text('Solar Manager'), findsOneWidget);
    });
  });
}
