import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/core/providers/device_status_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/features/dashboard/widgets/compact_status_row.dart';
import 'package:car_guard/features/settings/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}

DeviceStatus _connectedStatus() {
  return DeviceStatus(
    connected: true,
    deviceId: 'test-device',
    batteryData: const BatteryData(voltage: 13.8),
    temperatureData: const TemperatureData(engineTemperature: 80),
    coolantLevelData: const CoolantLevelData(),
    controlData: const DeviceControlData(),
    lastUpdated: DateTime(2026, 1, 1),
  );
}

Future<List<FlutterErrorDetails>> _pumpStatusRow(
  WidgetTester tester, {
  required String languageName,
  required TextDirection textDirection,
  required Size size,
}) async {
  final overflowErrors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) {
      overflowErrors.add(details);
    }
  };

  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsNotifier(
              AppSettings(
                languageName: languageName,
                demoModeEnabled: true,
              ),
            ),
          ),
          deviceStatusProvider.overrideWith(
            (ref) => Stream<DeviceStatus>.value(_connectedStatus()),
          ),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: textDirection,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: const FanAlternatorRow(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  } finally {
    FlutterError.onError = previousOnError;
  }

  return overflowErrors;
}

void expectTextWithinCard(WidgetTester tester, Finder textFinder) {
  final textBox = tester.renderObject<RenderParagraph>(textFinder);
  final textRect = tester.getRect(textFinder);
  final cardRect = tester.getRect(find.byType(Card));

  expect(textBox.didExceedMaxLines, isFalse);
  expect(textRect.left, greaterThanOrEqualTo(cardRect.left));
  expect(textRect.right, lessThanOrEqualTo(cardRect.right));
  expect(textRect.top, greaterThanOrEqualTo(cardRect.top));
  expect(textRect.bottom, lessThanOrEqualTo(cardRect.bottom));
}

void main() {
  testWidgets('fan and alternator text wraps in narrow English LTR layout',
      (tester) async {
    final overflowErrors = await _pumpStatusRow(
      tester,
      languageName: 'en',
      textDirection: TextDirection.ltr,
      size: const Size(160, 180),
    );

    expect(overflowErrors, isEmpty);
    expectTextWithinCard(tester, find.text('Fan: OFF'));
    expectTextWithinCard(tester, find.text('Alternator: Not charging'));
  });

  testWidgets('fan and alternator text wraps in narrow Arabic RTL layout',
      (tester) async {
    final overflowErrors = await _pumpStatusRow(
      tester,
      languageName: 'ar',
      textDirection: TextDirection.rtl,
      size: const Size(160, 220),
    );

    expect(overflowErrors, isEmpty);
    expectTextWithinCard(tester, find.text('المروحة: متوقفة'));
    expectTextWithinCard(tester, find.text('الدينامو: لا يشحن'));
  });

  testWidgets('normal width keeps both status items on one row', (tester) async {
    final overflowErrors = await _pumpStatusRow(
      tester,
      languageName: 'en',
      textDirection: TextDirection.ltr,
      size: const Size(720, 180),
    );

    expect(overflowErrors, isEmpty);
    final fanRect = tester.getRect(find.text('Fan: OFF'));
    final alternatorRect = tester.getRect(find.text('Alternator: Not charging'));
    expect((fanRect.top - alternatorRect.top).abs(), lessThan(1));
  });
}
