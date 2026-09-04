import '../../../core/models/license_models.dart';

/// Result phase of the last activation attempt.
enum LicenseActivationState {
  /// No activation attempt has completed yet.
  idle,

  /// An activation is in flight.
  loading,

  /// The last activation succeeded.
  success,

  /// The last activation failed (device remains locked).
  failure,
}

/// Immutable snapshot of the license state the Car Guard app tracks.
///
/// The only source of truth is the ESP8266 module itself: `status` is only
/// ever `active` after a fresh `LICENSE_STATUS` reply from the device, and it
/// is reset to [LicenseDeviceStatus.unknown] on every (dis)connection so the
/// app never trusts a cached license across sessions.
class LicenseState {
  const LicenseState({
    this.deviceSerial = '',
    this.status = LicenseDeviceStatus.unknown,
    this.licenseType = LicenseType.none,
    this.expires = 0,
    this.activationState = LicenseActivationState.idle,
    this.failureReason,
    this.activationReason = '',
  });

  /// Device serial reported by the module (`KCG_XXXXXXXX`), empty before
  /// `DEVICE_SERIAL` is answered.
  final String deviceSerial;

  final LicenseDeviceStatus status;
  final LicenseType licenseType;

  /// Absolute UTC epoch of expiry (0 = permanent / none).
  final int expires;

  final LicenseActivationState activationState;

  /// Mapped, user-facing failure category (null unless the last attempt failed).
  final LicenseFailureReason? failureReason;

  /// Raw firmware reason string for diagnostics/logging only. This is not a
  /// cryptographic secret and is not shown verbatim in the normal UI path.
  final String activationReason;

  bool get isUnknown => status == LicenseDeviceStatus.unknown;
  bool get isActive => status == LicenseDeviceStatus.active;
  bool get isLocked => status == LicenseDeviceStatus.locked;
  bool get isActivating => activationState == LicenseActivationState.loading;

  LicenseState copyWith({
    String? deviceSerial,
    LicenseDeviceStatus? status,
    LicenseType? licenseType,
    int? expires,
    LicenseActivationState? activationState,
    LicenseFailureReason? failureReason,
    String? activationReason,
    bool clearFailure = false,
  }) {
    return LicenseState(
      deviceSerial: deviceSerial ?? this.deviceSerial,
      status: status ?? this.status,
      licenseType: licenseType ?? this.licenseType,
      expires: expires ?? this.expires,
      activationState: activationState ?? this.activationState,
      failureReason:
          clearFailure ? null : (failureReason ?? this.failureReason),
      activationReason: activationReason ?? this.activationReason,
    );
  }
}
