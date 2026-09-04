import 'dart:async';

import 'package:car_guard/app/home_gate.dart';
import 'package:car_guard/core/models/license_models.dart';
import 'package:car_guard/core/providers/device_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/core/services/device_repository.dart';
import 'package:car_guard/features/dashboard/pages/dashboard_page.dart';
import 'package:car_guard/features/license/pages/license_page.dart' as license_page;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double so the shell can be exercised without a real device.
class _FakeRepo implements DeviceRepository {
  _FakeRepo({required this.statusMessage});

  final LicenseStatusMessage? statusMessage;
  final StreamController<bool> _connection = StreamController.broadcast();

  @override
  Stream<bool> get connectionStream => _connection.stream;

  @override
  Stream<LicenseMessage> get licenseStream => const Stream.empty();

  @override
  bool get hasAuthoritativeActiveLicense =>
      statusMessage?.status == LicenseDeviceStatus.active;

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
    LicenseStatusMessage? status,
  ) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  const locked = LicenseStatusMessage(
    status: LicenseDeviceStatus.locked,
    licenseType: LicenseType.none,
    expires: 0,
  );

  testWidgets('locked opens the dashboard shell with a no-license notice',
      (tester) async {
    await pumpGate(tester, locked);

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(license_page.LicensePage), findsNothing);
    expect(find.text('No license'), findsOneWidget);
    expect(find.text('KCG_1234ABCD'), findsNothing);
  });

  testWidgets('a missing status opens the dashboard with a network notice',
      (tester) async {
    await pumpGate(tester, null);

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(license_page.LicensePage), findsNothing);
    expect(find.text('The module could not be reached to verify the license.'),
        findsOneWidget);
  });

  testWidgets('active still opens the normal dashboard without a banner',
      (tester) async {
    await pumpGate(
      tester,
      const LicenseStatusMessage(
        status: LicenseDeviceStatus.active,
        licenseType: LicenseType.permanent,
        expires: 0,
      ),
    );

    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.text('No license'), findsNothing);
    expect(find.byType(license_page.LicensePage), findsNothing);
  });
}
