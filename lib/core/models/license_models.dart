import 'dart:convert';

/// License protocol models + strict, non-throwing parser for the Car Guard
/// ESP8266 license WebSocket channel.
///
/// The firmware answers three license commands over the SAME WebSocket used for
/// telemetry (port 81), each reply carrying a `"type"` discriminator:
///
///   App -> ESP:      {"cmd":"DEVICE_SERIAL"}
///   ESP -> App:      {"type":"DEVICE_SERIAL","serial":"KCG_XXXXXXXX"}
///
///   App -> ESP:      {"cmd":"LICENSE_STATUS"}
///   ESP -> App:      {"type":"LICENSE_STATUS","status":"LOCKED","licenseType":"NONE","expires":0}
///                  | {"type":"LICENSE_STATUS","status":"ACTIVE","licenseType":"TEMPORARY","expires":<epoch>}
///                  | {"type":"LICENSE_STATUS","status":"ACTIVE","licenseType":"PERMANENT","expires":0}
///
///   App -> ESP:      {"cmd":"LICENSE_ACTIVATE","code":"<Base32>"}
///   ESP -> App:      {"type":"LICENSE_RESULT","status":"OK","reason":"...","expires":<epoch>}
///                  | {"type":"LICENSE_RESULT","status":"ERROR","reason":"...","expires":0}
///
/// Every factory here validates its fields and returns `null` (or throws on an
/// invalid value) so malformed / unknown frames never crash the app.
library;

/// Lifecycle status of the device license as reported by the firmware.
enum LicenseDeviceStatus {
  /// Not yet determined (no definitive reply received this session).
  unknown,

  /// The device holds an active (non-expired) license.
  active,

  /// The device is locked (fresh, expired, or no valid license).
  locked,
}

/// Type of license held by the device, as reported by the firmware.
enum LicenseType {
  none,
  temporary,
  permanent,
}

/// Discriminator of a license message received from the device.
enum LicenseMessageType {
  deviceSerial,
  licenseStatus,
  licenseResult,
}

/// The three distinct replies the firmware can push for the license protocol.
sealed class LicenseMessage {
  const LicenseMessage();

  LicenseMessageType get type;
}

/// `{"type":"DEVICE_SERIAL","serial":"KCG_XXXXXXXX"}`
class DeviceSerialMessage extends LicenseMessage {
  const DeviceSerialMessage({required this.serial});

  final String serial;

  @override
  LicenseMessageType get type => LicenseMessageType.deviceSerial;
}

/// `{"type":"LICENSE_STATUS",...}`
class LicenseStatusMessage extends LicenseMessage {
  const LicenseStatusMessage({
    required this.status,
    required this.licenseType,
    required this.expires,
  });

  final LicenseDeviceStatus status;
  final LicenseType licenseType;
  final int expires;

  @override
  LicenseMessageType get type => LicenseMessageType.licenseStatus;
}

/// `{"type":"LICENSE_RESULT",...}`
class LicenseResultMessage extends LicenseMessage {
  const LicenseResultMessage({
    required this.ok,
    required this.status,
    required this.reason,
    required this.expires,
  });

  /// True when `status == "OK"`.
  final bool ok;

  /// Raw `"OK"` / `"ERROR"` string from the firmware.
  final String status;

  /// Firmware reason string (e.g. `SERIAL_MISMATCH`, `NTP_UNAVAILABLE`).
  /// Contains no cryptographic internals for the normal UI path.
  final String reason;

  final int expires;

  @override
  LicenseMessageType get type => LicenseMessageType.licenseResult;
}

LicenseDeviceStatus? _parseDeviceStatus(Object? value) {
  if (value is! String) return null;
  switch (value.toUpperCase()) {
    case 'ACTIVE':
      return LicenseDeviceStatus.active;
    case 'LOCKED':
      return LicenseDeviceStatus.locked;
    default:
      return null;
  }
}

LicenseType? _parseLicenseType(Object? value) {
  if (value is! String) return null;
  switch (value.toUpperCase()) {
    case 'NONE':
      return LicenseType.none;
    case 'TEMPORARY':
      return LicenseType.temporary;
    case 'PERMANENT':
      return LicenseType.permanent;
    default:
      return null;
  }
}

/// Parses a raw WebSocket frame into a [LicenseMessage], or returns `null` when
/// the frame is not a valid license message (telemetry, malformed JSON, unknown
/// type, missing/invalid fields). This never throws and never crashes.
LicenseMessage? parseLicenseMessage(String raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  final trimmed = raw.trim();
  if (!trimmed.startsWith('{')) return null;

  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;

  final map = Map<String, dynamic>.from(decoded);
  final type = map['type'];
  if (type is! String) return null;

  switch (type) {
    case 'DEVICE_SERIAL':
      final serial = map['serial'];
      if (serial is! String || serial.isEmpty) return null;
      return DeviceSerialMessage(serial: serial);

    case 'LICENSE_STATUS':
      final status = _parseDeviceStatus(map['status']);
      final licenseType = _parseLicenseType(map['licenseType']);
      final expires = (map['expires'] as num?)?.toInt();
      if (status == null || licenseType == null || expires == null) return null;
      return LicenseStatusMessage(
        status: status,
        licenseType: licenseType,
        expires: expires,
      );

    case 'LICENSE_RESULT':
      final status = map['status'];
      final reason = map['reason'];
      if (status is! String || reason is! String) return null;
      final expires = (map['expires'] as num?)?.toInt() ?? 0;
      return LicenseResultMessage(
        ok: status.toUpperCase() == 'OK',
        status: status,
        reason: reason,
        expires: expires,
      );

    default:
      // Unknown licence message type — ignore rather than crash.
      return null;
  }
}

/// Category of a failed activation, derived from the firmware reason string.
///
/// Names follow the vocabulary the product team uses, but the mapping is from
/// the ACTUAL firmware strings (e.g. `SIGNATURE_INVALID`, `DECODE_ERROR`).
/// `unknown` is the generic fallback for anything not currently defined.
enum LicenseFailureReason {
  /// The code is malformed / not decodable / wrong length.
  invalidCode,

  /// The code's signature did not verify.
  invalidSignature,

  /// The code belongs to a different device.
  serialMismatch,

  /// The signed creation date was not a real calendar date.
  invalidDate,

  /// The requested month count is out of range for a temporary license.
  invalidMonths,

  /// No trusted NTP time available on the module.
  ntpUnavailable,

  /// The code was already used (replay protection).
  alreadyUsed,

  /// A permanent license already exists and cannot be replaced.
  permanentAlreadyActive,

  /// A temporary license is already active.
  temporaryAlreadyActive,

  /// The code supplied was empty.
  codeEmpty,

  /// No production public key is configured on the module.
  publicKeyNotConfigured,

  /// The module could not commit the license to EEPROM.
  eepromCommitFailed,

  /// Unknown / unrecognised reason (generic fallback).
  unknown,
}

/// Maps the raw firmware reason to a stable [LicenseFailureReason].
///
/// Reasons that are not currently emitted by the firmware but were listed in
/// the review (INVALID_CODE, INVALID_DATE, INVALID_MONTHS, ...) map to their
/// actual firmware equivalents so the UI never invents a string.
LicenseFailureReason licenseFailureReasonFromFirmware(String? reason) {
  if (reason == null || reason.trim().isEmpty) {
    return LicenseFailureReason.unknown;
  }

  switch (reason.trim().toUpperCase()) {
    case 'EMPTY_CODE':
    case 'MISSING_CODE':
      return LicenseFailureReason.codeEmpty;

    case 'PUBLIC_KEY_NOT_CONFIGURED':
      return LicenseFailureReason.publicKeyNotConfigured;

    case 'DECODE_ERROR':
    case 'INVALID_LENGTH':
    case 'INVALID_PAYLOAD':
      // Covers the product's INVALID_CODE / INVALID_DATE / INVALID_MONTHS
      // vocabulary: those are all rejected inside the signed payload.
      return LicenseFailureReason.invalidCode;

    case 'SIGNATURE_INVALID':
      return LicenseFailureReason.invalidSignature;

    case 'SERIAL_MISMATCH':
      return LicenseFailureReason.serialMismatch;

    case 'NTP_UNAVAILABLE':
      return LicenseFailureReason.ntpUnavailable;

    case 'ALREADY_USED':
      return LicenseFailureReason.alreadyUsed;

    case 'CANNOT_REPLACE_PERMANENT':
      return LicenseFailureReason.permanentAlreadyActive;

    case 'EXISTING_TEMP_ACTIVE':
      return LicenseFailureReason.temporaryAlreadyActive;

    case 'EEPROM_COMMIT_FAILED':
      return LicenseFailureReason.eepromCommitFailed;

    case 'INVALID_TERM':
      return LicenseFailureReason.invalidMonths;

    default:
      return LicenseFailureReason.unknown;
  }
}
