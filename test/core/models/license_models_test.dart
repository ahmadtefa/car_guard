import 'package:car_guard/core/models/license_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('license message parser', () {
    test('A. DEVICE_SERIAL is parsed with its serial', () {
      final msg = parseLicenseMessage(
        '{"type":"DEVICE_SERIAL","serial":"KCG_1234ABCD"}',
      );

      expect(msg, isA<DeviceSerialMessage>());
      expect((msg! as DeviceSerialMessage).serial, 'KCG_1234ABCD');
    });

    test('B. LICENSE_STATUS ACTIVE TEMPORARY is parsed', () {
      final msg = parseLicenseMessage(
        '{"type":"LICENSE_STATUS","status":"ACTIVE","licenseType":"TEMPORARY","expires":1800000000}',
      );

      expect(msg, isA<LicenseStatusMessage>());
      final s = msg! as LicenseStatusMessage;
      expect(s.status, LicenseDeviceStatus.active);
      expect(s.licenseType, LicenseType.temporary);
      expect(s.expires, 1800000000);
    });

    test('C. LICENSE_STATUS ACTIVE PERMANENT is parsed', () {
      final msg = parseLicenseMessage(
        '{"type":"LICENSE_STATUS","status":"ACTIVE","licenseType":"PERMANENT","expires":0}',
      );

      expect(msg, isA<LicenseStatusMessage>());
      final s = msg! as LicenseStatusMessage;
      expect(s.status, LicenseDeviceStatus.active);
      expect(s.licenseType, LicenseType.permanent);
      expect(s.expires, 0);
    });

    test('D. LICENSE_STATUS LOCKED is parsed', () {
      final msg = parseLicenseMessage(
        '{"type":"LICENSE_STATUS","status":"LOCKED","licenseType":"NONE","expires":0}',
      );

      expect(msg, isA<LicenseStatusMessage>());
      final s = msg! as LicenseStatusMessage;
      expect(s.status, LicenseDeviceStatus.locked);
      expect(s.licenseType, LicenseType.none);
      expect(s.expires, 0);
    });

    test('E. LICENSE_RESULT OK is parsed', () {
      final msg = parseLicenseMessage(
        '{"type":"LICENSE_RESULT","status":"OK","reason":"OK","expires":1800000000}',
      );

      expect(msg, isA<LicenseResultMessage>());
      final r = msg! as LicenseResultMessage;
      expect(r.ok, isTrue);
      expect(r.expires, 1800000000);
      expect(r.reason, 'OK');
    });

    test('F. LICENSE_RESULT ERROR is parsed (not ok)', () {
      final msg = parseLicenseMessage(
        '{"type":"LICENSE_RESULT","status":"ERROR","reason":"ALREADY_USED","expires":0}',
      );

      expect(msg, isA<LicenseResultMessage>());
      final r = msg! as LicenseResultMessage;
      expect(r.ok, isFalse);
      expect(r.reason, 'ALREADY_USED');
      expect(r.expires, 0);
    });

    test('G. malformed JSON returns null (does not throw)', () {
      expect(parseLicenseMessage('{not json'), isNull);
      expect(parseLicenseMessage(''), isNull);
      expect(parseLicenseMessage('   '), isNull);
      expect(parseLicenseMessage('12345'), isNull);
      expect(parseLicenseMessage('[1,2,3]'), isNull);
    });

    test('H. unknown message type returns null', () {
      expect(
        parseLicenseMessage('{"type":"SOMETHING_ELSE","a":1}'),
        isNull,
      );
      expect(
        parseLicenseMessage('{"type":"TEMP","temp":10}'),
        isNull,
      );
    });

    test('I. missing required fields returns null', () {
      // No type.
      expect(parseLicenseMessage('{"cmd":"DEVICE_SERIAL"}'), isNull);
      // DEVICE_SERIAL without serial.
      expect(parseLicenseMessage('{"type":"DEVICE_SERIAL"}'), isNull);
      // LICENSE_STATUS missing expires.
      expect(
        parseLicenseMessage('{"type":"LICENSE_STATUS","status":"ACTIVE","licenseType":"PERMANENT"}'),
        isNull,
      );
      // LICENSE_RESULT missing reason.
      expect(
        parseLicenseMessage('{"type":"LICENSE_RESULT","status":"OK"}'),
        isNull,
      );
    });

    test('J. invalid status/type values return null', () {
      expect(
        parseLicenseMessage('{"type":"LICENSE_STATUS","status":"BROKEN","licenseType":"PERMANENT","expires":0}'),
        isNull,
      );
      expect(
        parseLicenseMessage('{"type":"LICENSE_STATUS","status":"ACTIVE","licenseType":"UNKNOWN","expires":0}'),
        isNull,
      );
    });

    test('telemetry (CSV) is not a license message', () {
      expect(parseLicenseMessage('88.5,12.4,1,0,95,90,12,15,0,0,0'), isNull);
    });

    test('reason mapping covers firmware strings with a generic fallback', () {
      expect(
        licenseFailureReasonFromFirmware('SIGNATURE_INVALID'),
        LicenseFailureReason.invalidSignature,
      );
      expect(
        licenseFailureReasonFromFirmware('SERIAL_MISMATCH'),
        LicenseFailureReason.serialMismatch,
      );
      expect(
        licenseFailureReasonFromFirmware('NTP_UNAVAILABLE'),
        LicenseFailureReason.ntpUnavailable,
      );
      expect(
        licenseFailureReasonFromFirmware('ALREADY_USED'),
        LicenseFailureReason.alreadyUsed,
      );
      expect(
        licenseFailureReasonFromFirmware('DECODE_ERROR'),
        LicenseFailureReason.invalidCode,
      );
      expect(
        licenseFailureReasonFromFirmware('MISSING_CODE'),
        LicenseFailureReason.codeEmpty,
      );
      expect(
        licenseFailureReasonFromFirmware('INVALID_TERM'),
        LicenseFailureReason.invalidMonths,
      );
      expect(
        licenseFailureReasonFromFirmware('CANNOT_REPLACE_PERMANENT'),
        LicenseFailureReason.permanentAlreadyActive,
      );
      // Unknown / null -> generic fallback.
      expect(
        licenseFailureReasonFromFirmware('SOMETHING_RANDOM'),
        LicenseFailureReason.unknown,
      );
      expect(licenseFailureReasonFromFirmware(null), LicenseFailureReason.unknown);
    });
  });
}
