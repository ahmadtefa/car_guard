import 'package:car_guard/core/models/license_models.dart';
import 'package:car_guard/features/license/models/license_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LicenseState', () {
    test('M. default state is unknown/idle with no device', () {
      const state = LicenseState();

      expect(state.deviceSerial, '');
      expect(state.status, LicenseDeviceStatus.unknown);
      expect(state.licenseType, LicenseType.none);
      expect(state.expires, 0);
      expect(state.checkStatus, LicenseCheckStatus.checking);
      expect(state.checkError, '');
      expect(state.activationState, LicenseActivationState.idle);
      expect(state.failureReason, isNull);
      expect(state.activationReason, '');
      expect(state.isUnknown, isTrue);
      expect(state.isActive, isFalse);
      expect(state.isLocked, isFalse);
      expect(state.isChecking, isTrue);
      expect(state.hasError, isFalse);
      expect(state.canUseRealData, isFalse);
      expect(state.isActivating, isFalse);
    });

    test('M. copyWith updates only the supplied fields', () {
      const state = LicenseState();

      final updated = state.copyWith(
        deviceSerial: 'KCG_1234ABCD',
        status: LicenseDeviceStatus.locked,
        licenseType: LicenseType.none,
        activationState: LicenseActivationState.failure,
        failureReason: LicenseFailureReason.serialMismatch,
        activationReason: 'SERIAL_MISMATCH',
      );

      expect(updated.deviceSerial, 'KCG_1234ABCD');
      expect(updated.status, LicenseDeviceStatus.locked);
      expect(updated.licenseType, LicenseType.none);
      expect(updated.activationState, LicenseActivationState.failure);
      expect(updated.failureReason, LicenseFailureReason.serialMismatch);
      expect(updated.activationReason, 'SERIAL_MISMATCH');
      // Untouched fields keep their defaults.
      expect(updated.expires, 0);
    });

    test('M. copyWith clearFailure drops the failure reason', () {
      const state = LicenseState(
        activationState: LicenseActivationState.failure,
        failureReason: LicenseFailureReason.invalidCode,
        activationReason: 'DECODE_ERROR',
      );

      final cleared = state.copyWith(clearFailure: true);

      expect(cleared.failureReason, isNull);
      expect(cleared.status, LicenseDeviceStatus.unknown);
    });
  });
}
