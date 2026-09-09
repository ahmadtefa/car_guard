import 'package:car_guard/core/l10n/app_l10n.dart';
import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/core/providers/device_status_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/features/dashboard/models/dashboard_state.dart';
import 'package:car_guard/features/dashboard/providers/dashboard_provider.dart';
import 'package:car_guard/features/dashboard/providers/trip_provider.dart';
import 'package:car_guard/features/dashboard/providers/voltage_delta_provider.dart';
import 'package:car_guard/features/dashboard/widgets/gauge_area.dart';
import 'package:car_guard/features/settings/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings(demoModeEnabled: true);
}

class _TestTripNotifier extends TripNotifier {
  @override
  TripState build() {
    return const TripState(
      speedKmh: 42,
      distanceKm: 1.25,
      hasFix: true,
    );
  }
}

DeviceStatus _connectedStatus() {
  return DeviceStatus(
    connected: true,
    deviceId: 'test-device',
    batteryData: const BatteryData(
      voltage: 12.6,
      voltageDifference: 0.37,
    ),
    temperatureData: const TemperatureData(engineTemperature: 82),
    coolantLevelData: const CoolantLevelData(),
    controlData: const DeviceControlData(),
    lastUpdated: DateTime(2026, 1, 1),
  );
}

Widget _probe(String key) {
  return SizedBox(
    key: ValueKey<String>(key),
    height: 80,
    child: ColoredBox(color: Colors.black),
  );
}

Future<List<FlutterErrorDetails>> _pumpPrimaryReadings(
  WidgetTester tester,
  double width,
) async {
  final overflowErrors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) {
      overflowErrors.add(details);
    } else {
      previousOnError?.call(details);
    }
  };

  try {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            child: ResponsivePrimaryReadings(
              temperature: _probe('temperature'),
              voltageDifference: _probe('voltage-difference'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  } finally {
    FlutterError.onError = previousOnError;
  }

  return overflowErrors;
}

void main() {
  testWidgets(
    'portrait width that can fit two minimum cards keeps readings side-by-side',
    (tester) async {
      final errors = await _pumpPrimaryReadings(tester, 360);

      expect(errors, isEmpty);
      final temperature =
          tester.getRect(find.byKey(const ValueKey('temperature')));
      final voltage =
          tester.getRect(find.byKey(const ValueKey('voltage-difference')));

      expect((temperature.top - voltage.top).abs(), lessThan(1));
      expect(voltage.left, greaterThan(temperature.right));
    },
  );

  testWidgets('narrow width below the calculated breakpoint stacks readings',
      (tester) async {
    final errors = await _pumpPrimaryReadings(tester, 300);

    expect(errors, isEmpty);
    final temperature =
        tester.getRect(find.byKey(const ValueKey('temperature')));
    final voltage =
        tester.getRect(find.byKey(const ValueKey('voltage-difference')));

    expect(voltage.top, greaterThanOrEqualTo(temperature.bottom));
    expect(voltage.left, closeTo(temperature.left, 0.1));
  });

  testWidgets('landscape width remains side-by-side without overflow',
      (tester) async {
    final errors = await _pumpPrimaryReadings(tester, 800);

    expect(errors, isEmpty);
    final temperature =
        tester.getRect(find.byKey(const ValueKey('temperature')));
    final voltage =
        tester.getRect(find.byKey(const ValueKey('voltage-difference')));

    expect((temperature.top - voltage.top).abs(), lessThan(1));
    expect(voltage.right, lessThanOrEqualTo(800));
  });

  testWidgets('DashboardState receives the effective voltage difference',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _TestSettingsNotifier()),
          deviceStatusProvider.overrideWith(
            (ref) => Stream<DeviceStatus>.value(_connectedStatus()),
          ),
          voltageDeltaProvider.overrideWithValue(0.37),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              return Text(ref.watch(dashboardProvider).voltageDifference);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('0.37 V'), findsOneWidget);
  });

  testWidgets(
    'the shared gauge area keeps temperature, voltage, speed and distance',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => _TestSettingsNotifier()),
            deviceStatusProvider.overrideWith(
              (ref) => Stream<DeviceStatus>.value(_connectedStatus()),
            ),
            tripProvider.overrideWith(() => _TestTripNotifier()),
          ],
          child: MaterialApp(
            home: SingleChildScrollView(
              child: SizedBox(
                width: 800,
                child: Consumer(
                  builder: (context, ref, child) {
                    return buildGaugeArea(
                      context,
                      ref,
                      settings: const AppSettings(demoModeEnabled: true),
                      state: const DashboardState(),
                      l: const AppL10n('en'),
                      onOpenHud: (_) {},
                      compact: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Engine Temperature'), findsWidgets);
      expect(find.text('Voltage Difference'), findsWidgets);
      expect(find.text('+0.37 V'), findsOneWidget);
      expect(find.text('Vehicle speed'), findsOneWidget);
      expect(find.text('Trip distance'), findsOneWidget);
    },
  );
}
