import 'dart:async';

import 'package:car_guard/app/home_gate.dart';
import 'package:car_guard/core/models/license_models.dart';
import 'package:car_guard/core/providers/device_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/core/services/device_repository.dart';
import 'package:car_guard/core/widgets/loading_view.dart';
import 'package:car_guard/features/dashboard/pages/dashboard_page.dart';
import 'package:car_guard/features/license/pages/license_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double so the gate can be exercised without a real device. The
/// connection stream never emits, so the module never looks connected via
/// telemetry; only the license answer decides the gate.
class _FakeRepo implements DeviceRepository {
  _FakeRepo({required this.statusMessage});

  /// Null means the module never answers LICENSE_STATUS (unknown gate).
  final LicenseStatusMessage? statusMessage;
  final StreamController<bool> _connection = StreamController.broadcast();

  @override
  Stream<bool> get connectionStream => _connection.stream;

  @override
  Stream<LicenseMessage> get licenseStream => const Stream.empty();

  @override
  Stream<DeviceStatus> get liveUpdates => const Stream.empty();

  @override
  Future<DeviceSerialMessage?> getDeviceSerial() async =>
      const DeviceSerialMessage(serial: 'KCG_1234ABCD');

  @override
  Future<LicenseStatusMessage?> getLicenseStatus() async => statusMessage;

  @override
  Future<LicenseResultMessage?> activateLicense(String code) async => null;

  @override
  Future<void> connect({required String host, int? port}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<Map<String, dynamic>> readJson() async => {};

  @override
  Future<void> sendJson(Map<String, dynamic> payload) async {}

  @override
  Future<void> reconnect() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGate(
    WidgetTester tester,
    LicenseStatusMessage? status, {
    bool settle = false,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(
            _FakeRepo(statusMessage: status),
          ),
        ],
        child: const MaterialApp(home: HomeGate()),
      ),
    );
    // The LoadingView uses an indeterminate progress indicator that never
    // settles, so only the non-animated gate render should [settle].
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  const locked = LicenseStatusMessage(
    status: LicenseDeviceStatus.locked,
    licenseType: LicenseType.none,
    expires: 0,
  );

  testWidgets('N. locked shows the License page and hides telemetry',
      (tester) async {
    await pumpGate(tester, locked, settle: true);

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.byType(DashboardPage), findsNothing);
    expect(find.text('KCG_1234ABCD'), findsOneWidget);
  });

  testWidgets('N. unknown shows a loading gate (never telemetry)',
      (tester) async {
    // A module that never answers leaves the state unknown; the gate must not
    // leak the dashboard.
    await pumpGate(tester, null);

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.byType(LicensePage), findsNothing);
    expect(find.byType(DashboardPage), findsNothing);
  });
}
