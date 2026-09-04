#!/usr/bin/env python3
"""Static firmware checks for the Car Guard license gate.

The ESP8266 toolchain is not part of the repository, so these checks are kept
stdlib-only. They verify the integration points that must remain present in the
compiled sketch: the protocol constants, EEPROM partition, activation
transition checks, relay/buzzer guards, WebSocket activation path, UI status,
and OTA-safe persistence. They do not replace a hardware smoke test.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = ROOT / "firmware" / "car_guard"
INO = (FIRMWARE / "car_guard.ino").read_text(encoding="utf-8")
LICENSE_H = (FIRMWARE / "license.h").read_text(encoding="utf-8")
LICENSE_CPP = (FIRMWARE / "license.cpp").read_text(encoding="utf-8")
HELPERS_CPP = (FIRMWARE / "license_helpers.cpp").read_text(encoding="utf-8")
PUBKEY_CPP = (FIRMWARE / "license_pubkey.cpp").read_text(encoding="utf-8")


def section(source: str, start: str, end: str) -> str:
    start_at = source.index(start)
    end_at = source.index(end, start_at)
    return source[start_at:end_at]


class LicenseGateStaticTest(unittest.TestCase):
    def test_protocol_and_storage_contract(self):
        for name, value in {
            "LICENSE_DECODED_LEN": "83",
            "LICENSE_PAYLOAD_LEN": "19",
            "LICENSE_SIGNATURE_LEN": "64",
            "LICENSE_PAYLOAD_SERIAL_LEN": "12",
            "LICENSE_EEPROM_OFFSET": "256",
            "LICENSE_EEPROM_VERSION": "1",
            "LICENSE_NTP_MIN_VALID_EPOCH": "1640995200",
        }.items():
            self.assertRegex(LICENSE_H, rf"#define\s+{name}\s+{value}\b")
        self.assertIn("LICENSE_TEMPORARY = 0", LICENSE_H)
        self.assertIn("LICENSE_PERMANENT = 1", LICENSE_H)
        self.assertIn("static_assert(sizeof(LicenseRecord) == 76", LICENSE_H)
        self.assertIn("EEPROM.put(LICENSE_EEPROM_OFFSET", LICENSE_CPP)
        self.assertIn("EEPROM.put(0, settings)", INO)
        self.assertNotIn("EEPROM" + ".clear(", INO + LICENSE_CPP)
        self.assertIn("static_assert(sizeof(Settings) <= LICENSE_EEPROM_OFFSET", INO)

    def test_activation_validation_and_transitions(self):
        for token in (
            "license_decode_base32",
            "decodedLen != LICENSE_DECODED_LEN",
            "verify_ecdsa_p256_sha256",
            "license_parse_payload",
            "SERIAL_MISMATCH",
            "license_wait_ntp_time",
            "license_compute_replay_hash",
            "ALREADY_USED",
            "transition_allowed",
            "CANNOT_REPLACE_PERMANENT",
            "EXISTING_TEMP_ACTIVE",
            "newType == LICENSE_PERMANENT",
            "license_persist(rec)",
        ):
            self.assertIn(token, LICENSE_CPP, token)
        self.assertIn("newType == LICENSE_PERMANENT) return true", LICENSE_CPP)
        self.assertIn("case ST_PERM_ACTIVE", LICENSE_CPP)
        self.assertIn("return false; // reason already set", LICENSE_CPP)
        self.assertIn("br_ecdsa_vrfy_raw_get_default", HELPERS_CPP)
        self.assertIn("sig_len != LICENSE_SIGNATURE_LEN", HELPERS_CPP)

    def test_locked_gate_and_silent_buzzer(self):
        fan_control = section(INO, "void updateFanControl()", "// =========================================================\n// VOLTAGE")
        fan_endpoint = section(INO, "void handleTestFan()", "void handleMute()")
        mute_endpoint = section(INO, "void handleMute()", "void handleRestart()")
        alarm = section(INO, "void handleAlarm()", "// =========================================================\n// LED STATUS")
        self.assertIn("if (!license_is_active())", fan_control)
        self.assertIn("fanOff();", fan_control)
        self.assertIn("if (!license_is_active())", fan_endpoint)
        self.assertIn('server.send(423, "text/plain", "LICENSE_REQUIRED")', fan_endpoint)
        self.assertIn("if (!license_is_active())", mute_endpoint)
        self.assertIn('server.send(423, "text/plain", "LICENSE_REQUIRED")', mute_endpoint)
        self.assertIn("if (!license_is_active())", alarm)
        self.assertIn("digitalWrite(BUZZER, LOW);", alarm)
        for sound in (
            "playStartupSound",
            "playSaveSuccessSound",
            "playConnectSound",
            "playDisconnectSound",
            "playConfirmSound",
        ):
            body = section(INO, f"void {sound}()", "\n}")
            self.assertIn("if (!license_is_active())", body, sound)

    def test_web_ui_and_websocket_are_available_when_locked(self):
        self.assertIn('server.on("/",                    handleRoot)', INO)
        self.assertIn("LICENSE REQUIRED", INO)
        self.assertIn("license_get_status_message", INO)
        self.assertIn('server.on("/data",                handleData)', INO)
        self.assertIn('server.on("/update",', INO) if 'server.on("/update",' in INO else self.assertIn('httpUpdater.setup(&server, "/update")', INO)
        ws = section(INO, "void onWsEvent(", "// =========================================================\n// API HANDLERS")
        self.assertIn("license_handle_ws_command", INO)
        self.assertIn("WStype_TEXT", ws)
        self.assertIn("DEVICE_SERIAL", ws)
        self.assertIn("LICENSE_STATUS", ws)

    def test_persistence_and_ota_order(self):
        self.assertLess(INO.index("license_load();"), INO.index("playStartupSound();"))
        self.assertIn('httpUpdater.setup(&server, "/update")', INO)
        self.assertIn("LICENSE_EEPROM_OFFSET", INO)
        self.assertNotIn("EEPROM" + ".clear(", INO)
        self.assertRegex(LICENSE_CPP, r"EEPROM\.put\(LICENSE_EEPROM_OFFSET, toSave\)")
        self.assertRegex(INO, r"EEPROM\.put\(0, settings\)")

    def test_production_private_material_is_absent(self):
        all_source = "\n".join(
            (FIRMWARE / name).read_text(encoding="utf-8")
            for name in (
                "car_guard.ino",
                "license.cpp",
                "license.h",
                "license_helpers.cpp",
                "license_pubkey.cpp",
                "license_pubkey.h",
            )
        )
        self.assertNotRegex(all_source, r"BEGIN\s+(EC\s+|RSA\s+|OPENSSH\s+|ENCRYPTED\s+)?PRIVATE\s+KEY")
        self.assertNotRegex(all_source, r"license[-_ ]signing[-_ ]key")
        values = re.findall(r"0x([0-9A-Fa-f]{2})", PUBKEY_CPP)
        self.assertEqual(len(values), 65)
        self.assertIn("PUBLIC_KEY_CONFIGURED 1", (FIRMWARE / "license_pubkey.h").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
