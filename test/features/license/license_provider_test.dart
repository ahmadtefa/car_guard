import 'dart:async';

import 'package:car_guard/core/models/license_models.dart';
import 'package:car_guard/core/providers/device_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/core/services/device_repository.dart';
import 'package:car_guard/features/license/models/license_state.dart';
import 'package:car_guard/features/license/providers/license_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test double for [DeviceRepository] that lets the license provider be tested
/// without network. It returns the configured license messages and records the
/// activation code it was called with.
class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository({
    DeviceSerialMessage? serialMessage,
    required this.statusMessage,
    this.resultMessage,
  }) : serialMessage =
            serialMessage ?? const DeviceSerialMessage(serial: 'KCG_1234ABCD');

  DeviceSerialMessage serialMessage;
  LicenseStatusMessage statusMessage;
  LicenseResultMessage? resultMessage;

  bool activated = false;
  String? lastCode;

  final StreamController<LicenseMessage> _license =
      StreamController.broadcast();
  final StreamController<bool> _connection = StreamController.broadcast();

  @override
  Stream<bool> get connectionStream => _connection.stream;

  @override
  Stream<LicenseMessage> get licenseStream => _license.stream;

  @override
  bool get hasAuthoritativeActiveLicense =>
      statusMessage.status == LicenseDeviceStatus.active;

  @override
  Stream<DeviceStatus> get liveUpdates => const Stream.empty();

  @override
  Future<DeviceSerialMessage?> getDeviceSerial() async => serialMessage;

  @override
  Future<LicenseStatusMessage?> getLicenseStatus() async => statusMessage;

  @override
  Future<LicenseResultMessage?> activateLicense(String code) async {
    activated = true;
    lastCode = code;
    return resultMessage;
  }

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
  test('K. activation success updates the state to ACTIVE', () async {
    final fake = FakeDeviceRepository(
      statusMessage: const LicenseStatusMessage(
        status: LicenseDeviceStatus.active,
        licenseType: LicenseType.temporary,
        expires: 1800000000,
      ),
      resultMessage: const LicenseResultMessage(
        ok: true,
        status: 'OK',
        reason: 'OK',
        expires: 1800000000,
      ),
    );

    final container = ProviderContainer(
      overrides: [deviceRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(licenseProvider.notifier);

    // Let the initial STATUS refresh complete.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(licenseProvider).deviceSerial, 'KCG_1234ABCD');

    await notifier.activateLicense('AFFUGR27…');
    final state = container.read(licenseProvider);

    expect(fake.activated, isTrue);
    expect(fake.lastCode, 'AFFUGR27…');
    // Re-query after success makes the state authoritative and ACTIVE.
    expect(state.status, LicenseDeviceStatus.active);
    expect(state.checkStatus, LicenseCheckStatus.licensed);
    expect(state.canUseRealData, isTrue);
  });

  test('L. activation failure keeps the device locked', () async {
    final fake = FakeDeviceRepository(
      statusMessage: const LicenseStatusMessage(
        status: LicenseDeviceStatus.locked,
        licenseType: LicenseType.none,
        expires: 0,
      ),
      resultMessage: const LicenseResultMessage(
        ok: false,
        status: 'ERROR',
        reason: 'SERIAL_MISMATCH',
        expires: 0,
      ),
    );

    final container = ProviderContainer(
      overrides: [deviceRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(licenseProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(licenseProvider).status, LicenseDeviceStatus.locked);
    expect(
      container.read(licenseProvider).checkStatus,
      LicenseCheckStatus.noLicense,
    );

    await notifier.activateLicense('AFFUGR27…');
    final state = container.read(licenseProvider);

    // Device stays locked and the failure is surfaced as a mapped, friendly reason.
    expect(state.status, LicenseDeviceStatus.locked);
    expect(state.activationState, LicenseActivationState.failure);
    expect(state.failureReason, LicenseFailureReason.serialMismatch);
    expect(state.checkStatus, LicenseCheckStatus.invalid);
    expect(state.canUseRealData, isFalse);
  });
}
