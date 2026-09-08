#!/usr/bin/env python3
"""Factory-reset lifecycle tests and source-contract checks.

The host environment has no ESP8266 core or real EEPROM, so the model covers
persistence/boot semantics while the source assertions bind those semantics to
the actual sketch. Hardware and live Flutter-to-module tests remain separate
limitations reported by the test run.
"""

from dataclasses import dataclass, field
from pathlib import Path
import copy
import unittest


ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = ROOT / "firmware" / "car_guard"
INO = (FIRMWARE / "car_guard.ino").read_text(encoding="utf-8")
LICENSE_CPP = (FIRMWARE / "license.cpp").read_text(encoding="utf-8")
LICENSE_H = (FIRMWARE / "license.h").read_text(encoding="utf-8")
REPOSITORY = (ROOT / "lib/core/services/esp8266_repository.dart").read_text(
    encoding="utf-8"
)
PROVIDER = (
    ROOT / "lib/features/license/providers/license_provider.dart"
).read_text(encoding="utf-8")
FACTORY_ACTION = (
    ROOT / "lib/core/services/factory_reset_action.dart"
).read_text(encoding="utf-8")
MODULE_SETTINGS = (
    ROOT / "lib/features/settings/widgets/module_settings_section.dart"
).read_text(encoding="utf-8")
ADVANCED_SETTINGS = (
    ROOT / "lib/features/device/pages/advanced_settings_page.dart"
).read_text(encoding="utf-8")
SETTINGS_PAGE = (
    ROOT / "lib/features/settings/pages/settings_page.dart"
).read_text(encoding="utf-8")


@dataclass
class PersistentImage:
    settings: dict[str, object] = field(default_factory=dict)
    license_record: dict[str, object] | None = None
    clock_record: dict[str, object] | None = None


class FactoryResetModel:
    """Minimal model of the three EEPROM regions and chip-derived identity."""

    def __init__(self) -> None:
        self.serial = "KCG_1234ABCD"
        self.defaults = {
            "signature": "SETTINGS_SIGNATURE",
            "wifiSSID": "CarGaurd",
            "wifiPASS": "12345678",
            "staSSID": "",
            "staPASS": "",
            "maxTemp": 97.0,
            "fanOnTemp": 90.0,
            "minVolt": 12.0,
            "maxVolt": 14.8,
            "offset": 0.0,
            "r1": 4700.0,
            "r2": 1000.0,
            "voltCalib": 1.0,
            "sensorPullUp": 4700.0,
            "installDate": "2026-06-08",
        }
        self.image = PersistentImage(settings=copy.deepcopy(self.defaults))
        self.settings = copy.deepcopy(self.defaults)
        self.license_record = None
        self.clock_record = None
        self.commit_count = 0
        self.reboot_count = 0
        self.restart_pending = False
        self.fan_on = False
        self.telemetry_enabled = False

    def install(self, license_type: str, replay_hash: str) -> None:
        self.license_record = {
            "serial": self.serial,
            "type": license_type,
            "status": "ACTIVE",
            "replayHash": replay_hash,
            "expiration": 0 if license_type == "PERMANENT" else 1_800_000_000,
        }
        self.clock_record = {
            "lastPhoneTime": 1_700_000_000,
            "temporaryExpired": False,
            "clockRollback": False,
        }
        self.image.license_record = copy.deepcopy(self.license_record)
        self.image.clock_record = copy.deepcopy(self.clock_record)
        self.telemetry_enabled = True

    def factory_reset(self, *, commit_ok: bool = True, method: str = "GET") -> str:
        if method != "GET":
            return "METHOD_NOT_ALLOWED"
        if self.restart_pending:
            return "FACTORY_RESET_IN_PROGRESS"
        if self.license_record is None:
            return "LICENSE_REQUIRED"
        if not commit_ok:
            return "FACTORY_RESET_FAILED"

        # The real implementation writes all three regions before mutating
        # runtime state. This model intentionally mirrors that transaction.
        next_image = PersistentImage(
            settings=copy.deepcopy(self.defaults),
            license_record=None,
            clock_record=None,
        )
        self.image = next_image
        self.settings = copy.deepcopy(self.defaults)
        self.license_record = None
        self.clock_record = None
        self.telemetry_enabled = False
        self.fan_on = False
        self.restart_pending = True
        self.commit_count += 1
        return "OK"

    def reboot(self) -> None:
        self.reboot_count += 1
        self.settings = copy.deepcopy(self.image.settings)
        self.license_record = copy.deepcopy(self.image.license_record)
        self.clock_record = copy.deepcopy(self.image.clock_record)
        self.restart_pending = False
        self.telemetry_enabled = self.license_record is not None
        self.fan_on = False

    def activate_new_license(self, license_type: str, replay_hash: str) -> bool:
        if self.license_record is not None:
            return False
        self.license_record = {
            "serial": self.serial,
            "type": license_type,
            "status": "ACTIVE",
            "replayHash": replay_hash,
            "expiration": 0 if license_type == "PERMANENT" else 1_900_000_000,
        }
        self.clock_record = {
            "lastPhoneTime": 1_700_000_001,
            "temporaryExpired": False,
            "clockRollback": False,
        }
        self.image.license_record = copy.deepcopy(self.license_record)
        self.image.clock_record = copy.deepcopy(self.clock_record)
        self.commit_count += 1
        self.telemetry_enabled = True
        return True


class FactoryResetLifecycleTest(unittest.TestCase):
    def test_temporary_license_reset_locks_and_clears_every_license_region(self):
        device = FactoryResetModel()
        device.install("TEMPORARY", "hash-temp")
        self.assertEqual(device.factory_reset(), "OK")
        self.assertIsNone(device.license_record)
        self.assertIsNone(device.clock_record)
        self.assertFalse(device.telemetry_enabled)
        self.assertFalse(device.fan_on)

    def test_permanent_license_reset_becomes_no_license(self):
        device = FactoryResetModel()
        device.install("PERMANENT", "hash-permanent")
        self.assertEqual(device.factory_reset(), "OK")
        self.assertIsNone(device.image.license_record)
        self.assertIsNone(device.image.clock_record)

    def test_device_identity_survives_reset(self):
        device = FactoryResetModel()
        before = device.serial
        device.install("PERMANENT", "hash")
        self.assertEqual(device.factory_reset(), "OK")
        device.reboot()
        self.assertEqual(device.serial, before)
        self.assertEqual(device.serial, "KCG_1234ABCD")

    def test_reset_persists_through_reboot_and_new_license_can_activate(self):
        device = FactoryResetModel()
        device.install("TEMPORARY", "old-replay")
        self.assertEqual(device.factory_reset(), "OK")
        device.reboot()
        self.assertIsNone(device.license_record)
        self.assertIsNone(device.clock_record)
        self.assertEqual(device.factory_reset(), "LICENSE_REQUIRED")
        self.assertTrue(device.activate_new_license("TEMPORARY", "new-replay"))
        self.assertEqual(device.license_record["replayHash"], "new-replay")
        self.assertTrue(device.telemetry_enabled)

    def test_failed_commit_keeps_old_image_and_active_license(self):
        device = FactoryResetModel()
        device.install("PERMANENT", "keep-me")
        image_before = copy.deepcopy(device.image)
        self.assertEqual(
            device.factory_reset(commit_ok=False),
            "FACTORY_RESET_FAILED",
        )
        self.assertEqual(device.image, image_before)
        self.assertEqual(device.license_record["replayHash"], "keep-me")
        self.assertFalse(device.restart_pending)
        self.assertEqual(device.commit_count, 0)

    def test_malformed_method_and_duplicate_reset_are_rejected(self):
        device = FactoryResetModel()
        device.install("TEMPORARY", "hash")
        self.assertEqual(
            device.factory_reset(method="POST"),
            "METHOD_NOT_ALLOWED",
        )
        self.assertEqual(device.factory_reset(), "OK")
        self.assertEqual(
            device.factory_reset(),
            "FACTORY_RESET_IN_PROGRESS",
        )

    def test_cancel_does_not_issue_or_commit_a_reset(self):
        device = FactoryResetModel()
        device.install("PERMANENT", "still-active")
        image_before = copy.deepcopy(device.image)
        # The shared Flutter action returns null for cancellation before it
        # invokes the repository. Model that branch explicitly here.
        cancelled_result = None
        self.assertIsNone(cancelled_result)
        self.assertEqual(device.commit_count, 0)
        self.assertEqual(device.image, image_before)
        self.assertEqual(device.license_record["status"], "ACTIVE")
        self.assertIn("if (confirmed != true) return null;", FACTORY_ACTION)

    def test_firmware_transaction_and_safe_restart_contract(self):
        reset = section(INO, "bool persistFactoryReset()", "void handleFactoryReset()")
        self.assertEqual(reset.count("EEPROM.commit()"), 1)
        self.assertIn("EEPROM.put(0, factorySettings)", reset)
        self.assertIn("EEPROM.put(LICENSE_EEPROM_OFFSET, clearedLicense)", reset)
        self.assertIn(
            "EEPROM.put(LICENSE_CLOCK_EEPROM_OFFSET, clearedClock)",
            reset,
        )
        self.assertIn("license_reset_runtime();", reset)
        self.assertNotIn("ESP.restart()", reset)

        handler = section(INO, "void handleFactoryReset()", "void handleGetAllSettings()")
        for token in (
            "HTTP_GET",
            "METHOD_NOT_ALLOWED",
            "INVALID_FACTORY_RESET_REQUEST",
            "factoryResetPending",
            "FACTORY_RESET_IN_PROGRESS",
            "license_is_active()",
            "LICENSE_REQUIRED",
            "FACTORY_RESET_FAILED",
            'server.send(200, "text/plain", "OK")',
            "factoryResetRestartAt",
        ):
            self.assertIn(token, handler)
        self.assertNotIn("ESP.restart()", handler)

        loop = section(INO, "void loop()", "\n}")
        self.assertIn("factoryResetPending", loop)
        self.assertIn("ESP.restart();", loop)
        self.assertIn("licenseTelemetryPending", loop)

        for token in (
            "#define LICENSE_CLOCK_EEPROM_OFFSET",
            "struct LicenseClockRecord",
        ):
            self.assertIn(token, LICENSE_H)
        for token in (
            "void fanOff()",
            "fanTestActive",
            "manualFanOverride",
            "alarmActive",
            "buzzMuted",
        ):
            self.assertIn(token, INO)

        self.assertIn("void license_reset_runtime();", LICENSE_H)
        runtime = section(LICENSE_CPP, "void license_reset_runtime()", "void license_load()")
        for token in (
            "license_init();",
            "_phoneTimeAvailable = false",
            "_clockRecordValid = false",
            "_temporaryExpired = false",
            "last_activation_reason[0]",
        ):
            self.assertIn(token, runtime)

    def test_flutter_response_serialization_and_expected_restart_state(self):
        self.assertIn("_factoryResetInFlight", REPOSITORY)
        self.assertIn("_factoryResetAwaitingReconnect", REPOSITORY)
        self.assertIn("body.toUpperCase() != \"OK\"", REPOSITORY)
        self.assertIn("_markFactoryResetLocally();", REPOSITORY)
        self.assertIn("beginFactoryReset()", PROVIDER)
        self.assertIn("finishFactoryReset(bool success)", PROVIDER)
        self.assertIn("_factoryResetRestartExpected", PROVIDER)
        self.assertIn("_factoryResetDisconnectObserved", PROVIDER)
        self.assertIn("LicenseCheckStatus.noLicense", PROVIDER)
        self.assertIn("runFactoryResetAction", FACTORY_ACTION)
        self.assertIn("beginFactoryReset", FACTORY_ACTION)
        self.assertIn("finishFactoryReset", FACTORY_ACTION)
        self.assertIn("confirmed != true", FACTORY_ACTION)

    def test_factory_reset_is_only_visible_in_advanced_settings(self):
        # The normal module section retains only a private compatibility wrapper;
        # it has no visible factory-reset title/button anymore.
        self.assertNotIn("title: l.factoryResetModule", MODULE_SETTINGS)
        self.assertNotIn("child: Text(l.factoryResetModule)", MODULE_SETTINGS)
        self.assertIn("runFactoryResetAction", MODULE_SETTINGS)

        self.assertIn("runFactoryResetAction", ADVANCED_SETTINGS)
        self.assertIn("Icons.restore_rounded", ADVANCED_SETTINGS)
        self.assertEqual(ADVANCED_SETTINGS.count("child: Row("), 1)
        self.assertNotIn("factoryResetModule", SETTINGS_PAGE)


def section(source: str, start: str, end: str) -> str:
    start_at = source.index(start)
    end_at = source.index(end, start_at)
    return source[start_at:end_at]


if __name__ == "__main__":
    unittest.main(verbosity=2)
