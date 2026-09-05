import 'package:car_guard/core/l10n/app_l10n.dart';
import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/features/dashboard/providers/voltage_delta_provider.dart';
import 'package:car_guard/features/dashboard/widgets/delta_style_gauge.dart';
import 'package:car_guard/features/dashboard/widgets/mini_gauges.dart';
import 'package:car_guard/features/dashboard/widgets/voltage_delta_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Styles that delegate to [StyledDeltaGauge] (everything but 'cards').
final _styledNames = AppSettings.dashboardStyleNames
    .where((name) => name != 'cards')
    .toList();

/// Every visible text must be negative-free: a positive-only gauge never
/// shows a signed number like "-0.80".
final _negativeNumber = RegExp(r'-\d');

void _expectNoNegativeText(WidgetTester tester) {
  for (final element in find.byType(Text).evaluate()) {
    final text = (element.widget as Text).data ?? '';
    expect(
      _negativeNumber.hasMatch(text),
      isFalse,
      reason: 'Negative text "$text" must never be rendered',
    );
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );
}

Widget _wrapCard(Widget child, {double? delta}) {
  return ProviderScope(
    overrides: [
      l10nProvider.overrideWithValue(const AppL10n('en')),
      dashboardVoltageDeltaProvider.overrideWithValue(delta),
    ],
    child: _wrap(child),
  );
}

void main() {
  group('StyledDeltaGauge — positive-only in every style', () {
    testWidgets('positive delta shows a positive value', (tester) async {
      for (final style in _styledNames) {
        await tester.pumpWidget(
          _wrap(
            StyledDeltaGauge(
              styleName: style,
              delta: 0.90,
              label: 'Voltage difference',
            ),
          ),
        );

        expect(find.textContaining('0.90'), findsWidgets, reason: style);
        _expectNoNegativeText(tester);
      }
    });

    testWidgets('negative internal delta renders as its absolute value',
        (tester) async {
      for (final style in _styledNames) {
        await tester.pumpWidget(
          _wrap(
            StyledDeltaGauge(
              styleName: style,
              delta: -0.90,
              label: 'Voltage difference',
            ),
          ),
        );

        // The magnitude is shown; the signed value never appears.
        expect(find.textContaining('0.90'), findsWidgets, reason: style);
        expect(find.textContaining('-0.90'), findsNothing, reason: style);
        _expectNoNegativeText(tester);
      }
    });

    testWidgets('zero renders 0.00 at the scale start', (tester) async {
      for (final style in _styledNames) {
        await tester.pumpWidget(
          _wrap(
            StyledDeltaGauge(
              styleName: style,
              delta: 0,
              label: 'Voltage difference',
            ),
          ),
        );

        expect(find.textContaining('0.00'), findsWidgets, reason: style);
        _expectNoNegativeText(tester);
      }
    });

    testWidgets('null never becomes a fake zero', (tester) async {
      for (final style in _styledNames) {
        await tester.pumpWidget(
          _wrap(
            StyledDeltaGauge(
              styleName: style,
              delta: null,
              label: 'Voltage difference',
            ),
          ),
        );

        expect(find.textContaining('--.-'), findsWidgets, reason: style);
        expect(find.textContaining('0.00'), findsNothing, reason: style);
      }
    });
  });

  group('DeltaGauge (cards style)', () {
    testWidgets('respects negative, zero and null magnitudes',
        (tester) async {
      for (final delta in <double?>[-0.9, 0.0, 0.9, null]) {
        await tester.pumpWidget(
          _wrap(DeltaGauge(delta: delta, scale: 1.5)),
        );

        expect(find.byType(DeltaGauge), findsOneWidget);
      }
    });
  });

  group('VoltageDeltaCard', () {
    testWidgets('cards style maps a negative delta to its magnitude',
        (tester) async {
      await tester.pumpWidget(
        _wrapCard(const VoltageDeltaCard(), delta: -0.85),
      );

      expect(find.text('0.85 V'), findsOneWidget);
      expect(find.textContaining('-0.85'), findsNothing);
      expect(find.byType(DeltaGauge), findsOneWidget);
      _expectNoNegativeText(tester);
    });

    testWidgets('cards style shows the placeholder for null, not 0.00',
        (tester) async {
      await tester.pumpWidget(
        _wrapCard(const VoltageDeltaCard(), delta: null),
      );

      expect(find.text('--.- V'), findsOneWidget);
      expect(find.text('0.00 V'), findsNothing);
    });

    testWidgets('styled card uses the positive-only StyledDeltaGauge',
        (tester) async {
      await tester.pumpWidget(
        _wrapCard(const VoltageDeltaCard(styleName: 'led'), delta: -0.85),
      );

      expect(find.byType(StyledDeltaGauge), findsOneWidget);
      expect(find.textContaining('0.85'), findsWidgets);
      expect(find.textContaining('-0.85'), findsNothing);
      _expectNoNegativeText(tester);
    });
  });
}
