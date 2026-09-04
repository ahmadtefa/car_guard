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

/// Immutable snapshot of the license state Car Guard tracks.
///
/// The only source of truth is the ESP8266 module itself: [status] and
/// [checkStatus] are updated from a fresh license reply on the current
/// transport session. Flutter never grants access from a persisted license
/// value.
class LicenseState {
  const LicenseState({
    this.deviceSerial = '',
    this.status = LicenseDeviceStatus.unknown,
    this.licenseType = LicenseType.none,
    this.expires = 0,
    this.checkStatus = LicenseCheckStatus.checking,
    this.checkError = '',
    this.activationState = LicenseActivationState.idle,
    this.failureReason,
    this.activationReason = '',
  });

  /// Device serial reported by the module (`KCG_XXXXXXXX`), empty before
  /// `DEVICE_SERIAL` is answered.
  final String deviceSerial;

  /// The raw lifecycle value from the firmware protocol.
  final LicenseDeviceStatus status;
  final LicenseType licenseType;

  /// Absolute UTC epoch of expiry (0 = permanent / none).
  final int expires;

  /// The UI and protected-data state. It is intentionally not folded into
  /// [status], because firmware `LOCKED` covers no-license, expired and other
  /// invalid states.
  final LicenseCheckStatus checkStatus;

  /// Non-secret diagnostic category for a failed status query. It is kept
  /// short and is not a substitute for the authoritative status.
  final String checkError;

  final LicenseActivationState activationState;

  /// Mapped, user-facing failure category (null unless the last activation
  /// attempt failed).
  final LicenseFailureReason? failureReason;

  /// Raw firmware reason string for diagnostics/logging only. This is not a
  /// cryptographic secret and is not shown verbatim in the normal UI path.
  final String activationReason;

  bool get isUnknown => status == LicenseDeviceStatus.unknown;
  bool get isActive => status == LicenseDeviceStatus.active;
  bool get isLocked => status == LicenseDeviceStatus.locked;
  bool get isChecking => checkStatus == LicenseCheckStatus.checking;
  bool get hasError => checkStatus == LicenseCheckStatus.error;

  /// True only after the ESP8266 reports ACTIVE on the current session.
  bool get canUseRealData =>
      status == LicenseDeviceStatus.active &&
      checkStatus == LicenseCheckStatus.licensed;

  bool get isActivating => activationState == LicenseActivationState.loading;

  LicenseState copyWith({
    String? deviceSerial,
    LicenseDeviceStatus? status,
    LicenseType? licenseType,
    int? expires,
    LicenseCheckStatus? checkStatus,
    String? checkError,
    bool clearCheckError = false,
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
      checkStatus: checkStatus ?? this.checkStatus,
      checkError: clearCheckError ? '' : (checkError ?? this.checkError),
      activationState: activationState ?? this.activationState,
      failureReason:
          clearFailure ? null : (failureReason ?? this.failureReason),
      activationReason: activationReason ?? this.activationReason,
    );
  }
}
