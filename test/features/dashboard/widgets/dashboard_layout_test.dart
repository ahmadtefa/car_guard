import 'dart:async';

import 'package:car_guard/core/l10n/app_l10n.dart';
import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/core/providers/device_status_provider.dart';
import 'package:car_guard/core/providers/effective_settings_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/features/dashboard/providers/fan_mode_provider.dart';
import 'package:car_guard/features/dashboard/providers/trip_provider.dart';
import 'package:car_guard/features/dashboard/providers/voltage_delta_provider.dart';
import 'package:car_guard/features/dashboard/widgets/fan_control_card.dart';
import 'package:car_guard/features/dashboard/widgets/readings_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout contract for the redesigned dashboard cards.
///
/// The cards are squeezed to half the screen width on a 320 dp phone, which is
/// exactly where the old fixed font sizes clipped text (`المروحة لا تعم…`) and
/// threw RenderFlex overflows. A `RenderFlex` that does not fit throws in debug
/// mode, so `takeException()` is how these tests assert "no overflow at this
/// size" — the same check the Flutter framework uses in its own layout tests.
void main() {
  final DeviceStatus device = DeviceStatus(
    connected: true,
    deviceId: 'fake',
    batteryData: BatteryData(voltage: 13.9, voltageDifference: 0.4),
    temperatureData: TemperatureData(engineTemperature: 96.4),
    coolantLevelData: CoolantLevelData(),
    controlData: DeviceControlData(fanRunning: true, fanForced: false),
    lastUpdated: DateTime(2026, 9, 3),
  );

  const AppL10n l = AppL10n('ar');

  /// Pumps [child] at an exact logical size, RTL (the app's primary language).
  ///
  /// [fan] swaps in a fake fan notifier for the tests that drive forced
  /// mode. Riverpod 3.x keeps the `Override` type off its public API, so the
  /// override list is built here and let inference name the element type.
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    required Widget child,
    _FakeFanNotifier? fan,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _FakeFanNotifier? fakeFan = fan;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceStatusProvider.overrideWith(
            (ref) => Stream<DeviceStatus>.value(device),
          ),
          tripProvider.overrideWith(() => _FakeTripNotifier()),
          voltageDeltaProvider.overrideWithValue(0.42),
          effectiveSettingsProvider.overrideWithValue(AppSettings()),
          l10nProvider.overrideWithValue(l),
          if (fakeFan != null) fanModeProvider.overrideWith(() => fakeFan),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  group('readings grid', () {
    const sizes = <Size>[
      Size(320, 568), // smallest phones still in use
      Size(360, 640),
      Size(412, 915), // the common modern phone
      Size(600, 400), // small tablet / split screen
      Size(800, 480), // landscape, and most car head units
    ];

    for (final size in sizes) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} '
          'without overflowing', (tester) async {
        await pumpAt(tester, size, child: const DashboardReadingsGrid());

        expect(tester.takeException(), isNull);

        // Everything stays inside the painted area.
        for (final title in <String>[
          l.engineTemperature,
          l.voltageDifference,
          l.vehicleSpeed,
          l.tripDistance,
        ]) {
          final textRect = tester.getRect(find.text(title));

          // Horizontal only: the dashboard is scrollable, so running past the
          // bottom edge is legal — leaving the screen sideways is not.
          expect(
            textRect.left >= 0 && textRect.right <= size.width + 0.5,
            isTrue,
            reason: "'$title' escapes the ${size.width.toInt()}dp screen: $textRect",
          );
        }
      });
    }

    testWidgets('shows the four live readings in two rows of two', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(412, 915),
        child: const DashboardReadingsGrid(),
      );

      expect(find.text(l.engineTemperature), findsOneWidget);
      expect(find.text(l.voltageDifference), findsOneWidget);
      expect(find.text(l.vehicleSpeed), findsOneWidget);
      expect(find.text(l.tripDistance), findsOneWidget);

      // Values come from the module / GPS providers, never placeholders.
      expect(find.text('96.4'), findsOneWidget);
      expect(find.text('+0.42'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text('125.31'), findsOneWidget);

      // Same row = same top edge; two rows = second one is below.
      final tempTop = tester.getRect(find.text(l.engineTemperature)).top;
      final deltaTop = tester.getRect(find.text(l.voltageDifference)).top;
      final speedTop = tester.getRect(find.text(l.vehicleSpeed)).top;
      final distanceTop = tester.getRect(find.text(l.tripDistance)).top;

      expect(tempTop, deltaTop);
      expect(speedTop, distanceTop);
      expect(speedTop, greaterThan(tempTop));
    });

    testWidgets('one column below 300dp so a card is never squeezed', (
      tester,
    ) async {
      await pumpAt(tester, const Size(280, 600), child: const DashboardReadingsGrid());

      expect(tester.takeException(), isNull);

      final tempRect = tester.getRect(find.text(l.engineTemperature));
      final deltaRect = tester.getRect(find.text(l.voltageDifference));

      expect(deltaRect.top, greaterThan(tempRect.bottom));
    });

    testWidgets('fullscreen mode fills the height it is given', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(390, 844),
        child: const SizedBox(
          height: 600,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: DashboardReadingsGrid(fullscreen: true),
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Four big cells, stacked 2x2 in portrait: the last one still fits.
      final distanceRect = tester.getRect(find.text(l.tripDistance));

      expect(distanceRect.bottom, lessThanOrEqualTo(844));
      expect(distanceRect.height, lessThan(600));
    });
  });

  group('fan control card', () {
    testWidgets('forced mode is spelled out, not just recoloured', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(320, 568),
        child: const FanControlCard(),
        fan: _FakeFanNotifier(
          const FanModeState(
            mode: FanMode.forcedOn,
            modeReported: true,
            connected: true,
          ),
        ),
      );

      expect(find.text(l.fanRunningForced), findsOneWidget);
      expect(find.text(l.fanModeForced), findsOneWidget);
      expect(find.text(l.fanReleaseButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the automatic and stopped states stay distinguishable', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(320, 568),
        child: const FanControlCard(),
        fan: _FakeFanNotifier(
          const FanModeState(
            mode: FanMode.automatic,
            modeReported: true,
            connected: true,
          ),
        ),
      );

      expect(find.text(l.fanModeAuto), findsOneWidget);
      expect(find.text(l.fanRunningAuto), findsOneWidget);
      expect(find.text(l.fanForceButton), findsOneWidget);
    });

    testWidgets('forcing the fan asks for confirmation first', (
      tester,
    ) async {
      final notifier = _FakeFanNotifier(
        const FanModeState(mode: FanMode.automatic, connected: true),
      );

      await pumpAt(
        tester,
        const Size(320, 568),
        child: const FanControlCard(),
        fan: notifier,
      );

      expect(find.text(l.fanForceButton), findsOneWidget);

      await tester.tap(find.text(l.fanForceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The confirm dialog, with both buttons.
      expect(find.text(l.fanForceConfirmBody), findsOneWidget);
      expect(find.text(l.cancel), findsOneWidget);
      expect(find.text(l.fanForceConfirmAction), findsOneWidget);

      // Cancelling sends nothing.
      await tester.tap(find.text(l.cancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(notifier.requests, isEmpty);
      expect(find.text(l.fanForceConfirmBody), findsNothing);

      // Confirming sends exactly one command and reports the confirmed mode.
      await tester.tap(find.text(l.fanForceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l.fanForceConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(notifier.requests, <bool>[true]);
      expect(find.text(l.fanForcedOnMsg), findsOneWidget);
    });

    testWidgets('a failed command is never shown as success', (
      tester,
    ) async {
      final notifier = _FakeFanNotifier(
        const FanModeState(mode: FanMode.automatic, connected: true),
        result: FanCommandResult.failed,
      );

      await pumpAt(
        tester,
        const Size(320, 568),
        child: const FanControlCard(),
        fan: notifier,
      );

      await tester.tap(find.text(l.fanForceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(l.fanForceConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l.fanCommandFailedMsg), findsOneWidget);
      expect(find.text(l.fanForcedOnMsg), findsNothing);

      // The card still tells the truth about the module: automatic, running
      // because the temperature asked for it, not because the user did.
      expect(find.text(l.fanRunningAuto), findsOneWidget);
    });

    testWidgets('cancelling forced mode also asks first', (tester) async {
      final notifier = _FakeFanNotifier(
        const FanModeState(
          mode: FanMode.forcedOn,
          modeReported: true,
          connected: true,
        ),
      );

      await pumpAt(
        tester,
        const Size(320, 568),
        child: const FanControlCard(),
        fan: notifier,
      );

      await tester.tap(find.text(l.fanReleaseButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l.fanReleaseConfirmBody), findsOneWidget);

      await tester.tap(find.text(l.fanReleaseConfirmAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(notifier.requests, <bool>[false]);
      expect(find.text(l.fanReleasedMsg), findsOneWidget);
    });
  });
}

/// GPS state without touching geolocator.
class _FakeTripNotifier extends TripNotifier {
  @override
  TripState build() => const TripState(
    speedKmh: 82.4,
    distanceKm: 125.31,
    hasFix: true,
  );
}

/// Stands in for the whole command path so these tests assert the UI contract —
/// confirmation first, truthful feedback afterwards — without a socket.
class _FakeFanNotifier extends FanModeNotifier {
  _FakeFanNotifier(this._state, {this.result = FanCommandResult.confirmed});

  final FanModeState _state;
  final FanCommandResult result;

  final List<bool> requests = <bool>[];

  @override
  FanModeState build() => _state;

  @override
  Future<FanCommandResult> setForced(bool enabled) async {
    requests.add(enabled);

    return result;
  }
}
