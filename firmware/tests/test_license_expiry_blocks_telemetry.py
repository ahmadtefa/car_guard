#!/usr/bin/env python3
"""Host-native firmware test: license expiry blocks telemetry on the ESP8266.

GOAL
----
Prove that the ESP8266 FIRMWARE itself (not the Flutter app) moves a device
with a valid temporary license through

    ACTIVE -> (expiry) -> LOCKED

and that after expiry the firmware stops emitting telemetry on BOTH channels
(WebSocket broadcast + HTTP /data), refuses protected control commands with
423 LICENSE_REQUIRED, and stays LOCKED across a reboot — without relying on
the phone's clock.

HOW IT WORKS (deterministic, no waiting, no production changes)
---------------------------------------------------------------
The test compiles the UNMODIFIED production sources

    firmware/car_guard/car_guard.ino
    firmware/car_guard/license.cpp
    firmware/car_guard/license_helpers.cpp

into a host binary together with the test-only shims under
`firmware/tests/host/`:

  * a deterministic test clock (stub millis() advanced by the test),
  * flash-like EEPROM storage that survives simulated reboots,
  * HTTP/WebSocket capture stubs that record every frame the firmware emits,
  * a BearSSL API shim whose SHA-256 / ECDSA-P256 implementation is REAL
    (backed by the host's libcrypto), and
  * a host-test keypair used to mint temporary/permanent licenses.
    The test private key is published in the repo ON PURPOSE: it can only
    activate this host build. Real devices embed the production public key,
    so test licenses are meaningless to them. The license payload layout,
    Base32 format, signature format and production durations are untouched;
    activation goes through the unmodified production code path.

The scenario injects phone-clock messages (LICENSE_STATUS / LICENSE_ACTIVATE
with fixed epoch values) exactly like the Flutter app would, so expiry is
reached deterministically without waiting a month or shortening any
production constant.

The ESP8266/Arduino toolchain is not required — only g++ and libcrypto.
"""

from __future__ import annotations

import glob
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FIRMWARE = ROOT / "firmware" / "car_guard"
HOST = ROOT / "firmware" / "tests" / "host"

GXX = shutil.which("g++")


def _find_libcrypto() -> str | None:
    candidates = [
        "/usr/lib/x86_64-linux-gnu/libcrypto.so.3",
        "/usr/lib/x86_64-linux-gnu/libcrypto.so",
        "/usr/lib/libcrypto.so.3",
        "/usr/lib/libcrypto.so",
        "/usr/lib64/libcrypto.so.3",
        "/usr/lib64/libcrypto.so",
    ]
    candidates += sorted(glob.glob("/lib/*/libcrypto.so*"))
    candidates += sorted(glob.glob("/usr/lib/*/libcrypto.so*"))
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


LIBCRYPTO = _find_libcrypto()

BUILD_SOURCES = [
    str(FIRMWARE / "car_guard.ino"),
    str(FIRMWARE / "license.cpp"),
    str(FIRMWARE / "license_helpers.cpp"),
    str(HOST / "support" / "support.cpp"),
    str(HOST / "support" / "bearssl_shim.cpp"),
    str(HOST / "support" / "test_pubkey.cpp"),
    str(HOST / "support" / "scenario_main.cpp"),
]

INCLUDE_DIRS = [
    str(HOST / "arduino"),
    str(HOST / "support"),
    str(FIRMWARE),
]

EXPECTED_MARKS = [
    "phase2_active_with_telemetry",
    "phase3_active_before_expiry",
    "phase4_expired_locked_telemetry_blocked",
    "phase5_clock_games_blocked",
    "phase6_reboot_stays_locked",
    "phase7_renewal_via_signed_license_only",
    "phase8_permanent_unaffected",
]

EXPECTED_CHECKS = [
    # ACTIVE phase: telemetry present on both channels.
    "P2 WebSocket broadcasts live telemetry while ACTIVE",
    "P2 HTTP /data serves live readings with licenseStatus ACTIVE",
    "P3 telemetry still broadcasting before expiry",
    # Expiry: firmware flips to LOCKED by itself.
    "P4 WS status flips to LOCKED at expiry",
    "P4 license_is_active() == false at expiry",
    "P4 WebSocket emits ZERO telemetry frames after expiry",
    "P4 HTTP /data redacted + LOCKED after expiry",
    "P4 protected command refused (423) after expiry",
    # Phone clock cannot revive.
    "P5 backdated phone clock rejected, still LOCKED",
    "P5 forward phone clock cannot revive (sticky expired flag)",
    # Reboot persistence.
    "P6 rebooted module is LOCKED immediately (sticky EEPROM state)",
    "P6 WebSocket telemetry blocked after reboot",
    "P6 HTTP /data redacted after reboot",
    "P6 pre-expiry phone clock rejected after reboot (rollback)",
    "P6 telemetry STILL blocked after clock attempts",
    # Recovery only via a genuinely signed new license.
    "P7 telemetry resumes ONLY after genuine re-activation",
]


@unittest.skipUnless(GXX, "g++ is not available in this environment")
@unittest.skipUnless(LIBCRYPTO, "libcrypto was not found in this environment")
class LicenseExpiryBlocksTelemetryTest(unittest.TestCase):
    """Compile the production firmware on the host and run the scenario."""

    BINARY: Path | None = None
    OUTPUT: str = ""
    EXIT_CODE: int = -1
    BUILD_LOG: str = ""

    @classmethod
    def setUpClass(cls):
        workdir = Path(tempfile.mkdtemp(prefix="car_guard_license_test_"))
        cls.BINARY = workdir / "car_guard_license_test"

        cmd = (
            [GXX, "-std=c++17", "-O0", "-w", "-x", "c++", BUILD_SOURCES[0]]
            + ["-x", "none"]
            + BUILD_SOURCES[1:]
            + [f"-I{inc}" for inc in INCLUDE_DIRS]
            + [LIBCRYPTO, "-o", str(cls.BINARY)]
        )
        build = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        cls.BUILD_LOG = build.stdout + build.stderr
        if build.returncode != 0:
            raise RuntimeError(
                "host firmware build failed:\n"
                + " ".join(cmd)
                + "\n"
                + cls.BUILD_LOG[-8000:]
            )

        run = subprocess.run(
            [str(cls.BINARY)], capture_output=True, text=True, timeout=120
        )
        cls.OUTPUT = run.stdout
        cls.EXIT_CODE = run.returncode

    def test_scenario_binary_exits_cleanly(self):
        self.assertEqual(
            self.EXIT_CODE,
            0,
            f"scenario reported failures:\n{self.OUTPUT}",
        )

    def test_no_failed_check_in_output(self):
        self.assertNotIn("FAIL  -", self.OUTPUT, self.OUTPUT)

    def test_all_phases_reached(self):
        for mark in EXPECTED_MARKS:
            self.assertIn(f"[MARK] {mark}", self.OUTPUT, mark)

    def test_required_assertions_present(self):
        for check in EXPECTED_CHECKS:
            self.assertIn(f"ok    - {check}", self.OUTPUT, check)

    def test_summary_reports_success(self):
        self.assertIn("TAP SUMMARY:", self.OUTPUT)
        self.assertIn("fail=0", self.OUTPUT, self.OUTPUT)
        self.assertIn("RESULT: ALL CHECKS PASSED", self.OUTPUT)

    def test_active_then_locked_transition_proven_in_firmware(self):
        """The exact sequence ACTIVE -> telemetry -> expiry -> LOCKED ->
        blocked telemetry -> reboot -> still LOCKED appears in order."""
        idx_active = self.OUTPUT.index("[MARK] phase2_active_with_telemetry")
        idx_before = self.OUTPUT.index("[MARK] phase3_active_before_expiry")
        idx_expired = self.OUTPUT.index(
            "[MARK] phase4_expired_locked_telemetry_blocked"
        )
        idx_reboot = self.OUTPUT.index("[MARK] phase6_reboot_stays_locked")
        self.assertLess(idx_active, idx_before)
        self.assertLess(idx_before, idx_expired)
        self.assertLess(idx_expired, idx_reboot)

    def test_production_sources_were_not_modified(self):
        """This test must only add host harness files; the sketch, license
        protocol, durations and telemetry format in firmware/car_guard stay
        untouched by the test code itself (guarded by the split layout)."""
        forbidden = ["forceActive", "skipExpiry", "SKIP_EXPIRY",
                     "FORCE_ACTIVE", "bypass_license", "LICENSE_BYPASS"]
        for name in ("car_guard.ino", "license.cpp", "license.h",
                     "license_helpers.cpp", "license_pubkey.cpp",
                     "license_pubkey.h"):
            text = (FIRMWARE / name).read_text(encoding="utf-8")
            for token in forbidden:
                self.assertNotIn(token, text, f"{token} found in {name}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
