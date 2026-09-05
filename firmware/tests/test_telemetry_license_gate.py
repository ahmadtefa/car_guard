#!/usr/bin/env python3
"""Static output-gate checks for the unchanged Car Guard telemetry paths.

The ESP8266 toolchain is not installed in this checkout. These tests therefore
keep the gate contract executable with the standard library: they inspect the
small output wrappers and exercise a tiny redaction model. Sensor acquisition,
filtering, field names, and the license protocol remain outside the model.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = ROOT / "firmware" / "car_guard"
INO = (FIRMWARE / "car_guard.ino").read_text(encoding="utf-8")
LICENSE_CPP = (FIRMWARE / "license.cpp").read_text(encoding="utf-8")


def section(source: str, start: str, end: str) -> str:
    start_at = source.index(start)
    end_at = source.index(end, start_at)
    return source[start_at:end_at]


class TelemetryOutputModel:
    """Only models the output gate, not sensor acquisition or licensing."""

    def __init__(self, temperature=91.2, voltage=13.4):
        self.temperature = temperature
        self.voltage = voltage
        self.active = False

    def http_reading(self):
        return {
            "temp": self.temperature if self.active else 0.0,
            "volt": self.voltage if self.active else 0.0,
        }

    def websocket_frames(self):
        return [(self.temperature, self.voltage)] if self.active else []

    def html_reading(self):
        return (
            f"{self.temperature:.1f} °C / {self.voltage:.2f} V"
            if self.active
            else "LICENSE_REQUIRED / LICENSE_REQUIRED"
        )

    def activate(self):
        self.active = True

    def lock(self):
        self.active = False


class TelemetryLicenseGateTest(unittest.TestCase):
    def test_valid_license_temperature_available(self):
        model = TelemetryOutputModel()
        model.activate()
        self.assertEqual(model.http_reading()["temp"], 91.2)
        self.assertEqual(model.websocket_frames()[0][0], 91.2)

    def test_valid_license_voltage_available(self):
        model = TelemetryOutputModel()
        model.activate()
        self.assertEqual(model.http_reading()["volt"], 13.4)
        self.assertEqual(model.websocket_frames()[0][1], 13.4)

    def test_locked_temperature_hidden(self):
        model = TelemetryOutputModel()
        self.assertEqual(model.http_reading()["temp"], 0.0)
        self.assertNotIn("91.2", model.html_reading())

    def test_locked_voltage_hidden(self):
        model = TelemetryOutputModel()
        self.assertEqual(model.http_reading()["volt"], 0.0)
        self.assertNotIn("13.40", model.html_reading())

    def test_temporary_expired_uses_the_same_locked_output_gate(self):
        model = TelemetryOutputModel()
        model.activate()
        model.lock()  # license_is_active() becomes false after expiry
        self.assertEqual(model.websocket_frames(), [])
        self.assertEqual(model.http_reading(), {"temp": 0.0, "volt": 0.0})

    def test_locked_data_endpoint_has_redacted_sensor_fields(self):
        handle_data = section(INO, "void handleData()", "void handleSaveAllSettings()")
        self.assertIn("const float exposedTemp = licenseActive ? filteredTemp : 0.0f", handle_data)
        self.assertIn("const float exposedVolt = licenseActive ? filteredVolt : 0.0f", handle_data)
        self.assertIn("String(exposedTemp, 1)", handle_data)
        self.assertIn("String(exposedVolt, 2)", handle_data)
        self.assertNotIn('String(filteredTemp, 1)', handle_data)
        self.assertNotIn('String(filteredVolt, 2)', handle_data)

    def test_locked_websocket_does_not_broadcast_sensor_frames(self):
        broadcast = section(INO, "void broadcastWsData()", "// =========================================================\n// WEBSOCKET EVENTS")
        self.assertIn("if (!license_is_active())", broadcast)
        self.assertIn("return;", broadcast)
        self.assertLess(
            broadcast.index("if (!license_is_active())"),
            broadcast.index("webSocket.broadcastTXT(payload)"),
        )

    def test_locked_root_keeps_page_but_redacts_values(self):
        root = section(INO, "void handleRoot()", "void handleNotFound()")
        self.assertIn("if (licenseActive)", root)
        self.assertIn("LICENSE_REQUIRED", root)
        self.assertIn("server.send(200, \"text/html\", html)", root)

    def test_license_status_and_activation_remain_on_websocket(self):
        ws = section(INO, "void onWsEvent(", "// =========================================================\n// API HANDLERS")
        self.assertIn("license_handle_ws_command", INO)
        self.assertIn("LICENSE_STATUS", ws)
        self.assertIn("DEVICE_SERIAL", ws)
        self.assertIn("LICENSE_ACTIVATE", LICENSE_CPP)
        self.assertIn("activationTime", LICENSE_CPP)

    def test_successful_activation_returns_telemetry(self):
        model = TelemetryOutputModel()
        model.activate()
        self.assertEqual(model.websocket_frames(), [(91.2, 13.4)])
        self.assertIn("91.2", model.html_reading())
        self.assertIn("13.40", model.html_reading())

    def test_successful_activation_forces_first_telemetry_frame(self):
        reply = section(INO, "void sendLicenseWsReply(", "void onWsEvent(")
        self.assertIn("LICENSE_RESULT", reply)
        self.assertIn("lastBroadcastTemp = -999", reply)
        self.assertIn("broadcastWsData();", reply)

    def test_reboot_expired_license_stays_locked(self):
        self.assertIn("load_phone_clock();", LICENSE_CPP)
        self.assertIn("_temporaryExpired = rec.temporaryExpired != 0", LICENSE_CPP)
        self.assertIn("if (_temporaryExpired ||", LICENSE_CPP)
        self.assertIn("if (!license_is_active())", INO)

    def test_reboot_valid_license_can_resume_telemetry(self):
        self.assertIn("license_load();", INO)
        self.assertIn("if (license_is_active())", INO)
        self.assertIn("String(filteredTemp, 1)", INO)
        self.assertIn("String(filteredVolt, 2)", INO)

    def test_sensor_acquisition_and_protocol_fields_were_not_removed(self):
        for token in (
            "void updateSensors()",
            "sensors.requestTemperatures();",
            "float readVoltage()",
            "filteredTemp  = (filteredTemp * 0.7) + (rawTemp * 0.3)",
            "filteredVolt = (filteredVolt * 0.7) + (v * 0.3)",
            '\\"temp\\"',
            '\\"volt\\"',
            "fanState",
            "alarm",
            "muted",
        ):
            self.assertIn(token, INO, token)


if __name__ == "__main__":
    unittest.main(verbosity=2)
