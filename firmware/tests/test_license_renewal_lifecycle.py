#!/usr/bin/env python3
"""Host-side lifecycle model for the ESP8266 license replacement contract.

The ESP8266/Arduino toolchain is not available in this checkout, so this is
not presented as a hardware test. It exercises the state transitions that are
otherwise difficult to cover without an EEPROM/WebSocket double, and the
static assertions tie the model's atomic/deferred guarantees to the actual
firmware source.
"""

from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
from hashlib import sha256
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
LICENSE_CPP = (ROOT / "firmware" / "car_guard" / "license.cpp").read_text(
    encoding="utf-8"
)
INO = (ROOT / "firmware" / "car_guard" / "car_guard.ino").read_text(
    encoding="utf-8"
)


@dataclass(frozen=True)
class Record:
    serial: str
    license_type: str
    activation: int
    expiration: int
    replay_hash: str


@dataclass(frozen=True)
class Clock:
    last_phone_time: int = 0
    temporary_expired: bool = False
    rollback: bool = False


def add_months_clamped(epoch: int, months: int) -> int:
    source = datetime.fromtimestamp(epoch, tz=timezone.utc)
    month_index = source.year * 12 + source.month - 1 + months
    year, month_zero = divmod(month_index, 12)
    month = month_zero + 1
    # Asking datetime for day zero of the following month gives the last day
    # of the target month without relying on the host's local timezone.
    if month == 12:
        next_month = datetime(year + 1, 1, 1, tzinfo=timezone.utc)
    else:
        next_month = datetime(year, month + 1, 1, tzinfo=timezone.utc)
    last_day = (next_month - timedelta(days=1)).day
    day = min(source.day, last_day)
    return int(
        datetime(
            year,
            month,
            day,
            source.hour,
            source.minute,
            source.second,
            tzinfo=timezone.utc,
        ).timestamp()
    )


class LicenseLifecycleModel:
    """Small model of the persisted license and phone-clock contract."""

    def __init__(self, serial: str = "KCG_1234ABCD"):
        self.serial = serial
        self.record: Record | None = None
        self.clock = Clock()
        self._persisted_record: Record | None = None
        self._persisted_clock = self.clock
        self.eeprom_commits = 0
        self.reset_count = 0

    def _hash(self, code: str) -> str:
        return sha256(code.encode("ascii")).hexdigest()

    def _commit_activation(self, record: Record, now: int) -> None:
        # This is the property supplied by license_persist_activation(): both
        # values become durable together, with no intermediate mixed state.
        next_clock = Clock(
            last_phone_time=now,
            temporary_expired=False,
            rollback=self.clock.rollback,
        )
        self.record = record
        self.clock = next_clock
        self._persisted_record = record
        self._persisted_clock = next_clock
        self.eeprom_commits += 1

    def observe_time(self, now: int) -> bool:
        if now < self.clock.last_phone_time:
            self.clock = replace(self.clock, rollback=True)
            return False
        self.clock = replace(self.clock, last_phone_time=now)
        return True

    def status(self, now: int) -> str:
        if not self.observe_time(now):
            return "LOCKED"
        if self.record is None:
            return "LOCKED"
        if self.record.license_type == "PERMANENT":
            return "ACTIVE"
        if self.clock.temporary_expired or now >= self.record.expiration:
            if not self.clock.temporary_expired:
                self.clock = replace(self.clock, temporary_expired=True)
                self._persisted_clock = self.clock
                self.eeprom_commits += 1
            return "LOCKED"
        return "ACTIVE"

    def telemetry_and_fan_available(self, now: int) -> bool:
        return self.status(now) == "ACTIVE"

    def activate(
        self,
        code: str,
        now: int,
        *,
        license_type: str = "TEMPORARY",
        months: int = 1,
        serial: str | None = None,
        signature_valid: bool = True,
        malformed: bool = False,
    ) -> str:
        old_record = self.record
        if malformed or not code:
            return "DECODE_ERROR"
        if not signature_valid:
            return "SIGNATURE_INVALID"
        if serial is not None and serial != self.serial:
            return "SERIAL_MISMATCH"
        if now < 1_640_995_200:
            return "INVALID_TIMESTAMP"
        if now < self.clock.last_phone_time:
            self.clock = replace(self.clock, rollback=True)
            return "CLOCK_ROLLBACK"

        replay_hash = self._hash(code)
        if old_record is not None and old_record.replay_hash == replay_hash:
            return "ALREADY_USED"

        current = "LOCKED"
        if old_record is not None:
            if old_record.license_type == "PERMANENT":
                current = "PERMANENT_ACTIVE"
            elif not self.clock.temporary_expired and now < old_record.expiration:
                current = "TEMPORARY_ACTIVE"

        if current == "PERMANENT_ACTIVE":
            return "CANNOT_REPLACE_PERMANENT"
        if current == "TEMPORARY_ACTIVE" and license_type == "TEMPORARY":
            return "EXISTING_TEMP_ACTIVE"
        if license_type not in ("TEMPORARY", "PERMANENT"):
            return "INVALID_PAYLOAD"
        if license_type == "TEMPORARY" and not 1 <= months <= 120:
            return "INVALID_TERM"

        expiration = 0
        if license_type == "TEMPORARY":
            expiration = add_months_clamped(now, months)
        self._commit_activation(
            Record(
                serial=self.serial,
                license_type=license_type,
                activation=now,
                expiration=expiration,
                replay_hash=replay_hash,
            ),
            now,
        )
        return "OK"

    def reboot(self) -> None:
        self.reset_count += 1
        self.record = self._persisted_record
        self.clock = self._persisted_clock


class LicenseRenewalLifecycleTest(unittest.TestCase):
    def test_full_temporary_renewal_and_permanent_upgrade_lifecycle(self):
        device = LicenseLifecycleModel()
        first_time = 1_700_000_000

        # 1. No record starts locked; first valid activation becomes active.
        self.assertEqual(device.status(first_time), "LOCKED")
        self.assertEqual(device.activate("TEMP-A", first_time), "OK")
        first = device.record
        self.assertIsNotNone(first)
        assert first is not None
        self.assertEqual(first.activation, first_time)
        self.assertGreater(first.expiration, first.activation)
        self.assertEqual(device.status(first_time + 1), "ACTIVE")

        # 2. Expiration is sticky and gates both telemetry and fan control.
        expiry = first.expiration
        self.assertEqual(device.status(expiry), "LOCKED")
        self.assertFalse(device.telemetry_and_fan_available(expiry + 1))
        self.assertTrue(device.clock.temporary_expired)

        # 3. Replaying the expired code is still rejected.
        self.assertEqual(
            device.activate("TEMP-A", expiry + 1),
            "ALREADY_USED",
        )

        # 4. A new temporary code replaces the old record and reopens both
        # output gates. The record, epochs, replay hash and clock are replaced.
        commits_before_renewal = device.eeprom_commits
        renewal_time = expiry + 2
        self.assertEqual(device.activate("TEMP-B", renewal_time), "OK")
        renewed = device.record
        self.assertIsNotNone(renewed)
        assert renewed is not None
        self.assertEqual(renewed.activation, renewal_time)
        self.assertGreater(renewed.expiration, renewal_time)
        self.assertNotEqual(renewed.replay_hash, first.replay_hash)
        self.assertFalse(device.clock.temporary_expired)
        self.assertEqual(device.clock.last_phone_time, renewal_time)
        self.assertEqual(device.eeprom_commits, commits_before_renewal + 1)
        self.assertTrue(device.telemetry_and_fan_available(renewal_time + 1))

        # 5. A reboot loads the replacement pair, not the expired pair.
        device.reboot()
        self.assertEqual(device.reset_count, 1)
        self.assertEqual(device.status(renewal_time + 1), "ACTIVE")
        self.assertEqual(device.record, renewed)

        # 6. After the renewed temporary term expires, a permanent code may
        # replace it. Permanent expiration remains zero forever.
        renewed_expiry = renewed.expiration
        self.assertEqual(device.status(renewed_expiry), "LOCKED")
        self.assertEqual(
            device.activate("PERM-C", renewed_expiry + 1, license_type="PERMANENT"),
            "OK",
        )
        permanent = device.record
        self.assertIsNotNone(permanent)
        assert permanent is not None
        self.assertEqual(permanent.license_type, "PERMANENT")
        self.assertEqual(permanent.expiration, 0)
        device.reboot()
        self.assertEqual(device.status(renewed_expiry + 10_000_000), "ACTIVE")
        self.assertTrue(device.telemetry_and_fan_available(renewed_expiry + 10_000_001))
        self.assertEqual(device.reset_count, 2)

    def test_invalid_wrong_device_stale_clock_and_signature_preserve_record(self):
        device = LicenseLifecycleModel()
        now = 1_700_000_000
        self.assertEqual(device.activate("TEMP-A", now), "OK")
        original = device.record
        commits = device.eeprom_commits

        for result in (
            device.activate("bad", now + 1, malformed=True),
            device.activate("bad-signature", now + 1, signature_valid=False),
            device.activate("wrong-device", now + 1, serial="KCG_OTHER"),
            device.activate("stale", now - 1),
        ):
            self.assertIn(
                result,
                {"DECODE_ERROR", "SIGNATURE_INVALID", "SERIAL_MISMATCH", "CLOCK_ROLLBACK"},
            )
            self.assertEqual(device.record, original)
            self.assertEqual(device.eeprom_commits, commits)

    def test_no_crash_reset_and_atomic_source_guarantees(self):
        # These are source-level assertions for properties the model cannot
        # observe: one EEPROM.commit for both records and deferred broadcast.
        start = LICENSE_CPP.index("static bool license_persist_activation(")
        end = LICENSE_CPP.index("// ---------------------------------------------------------\n// Public lifecycle", start)
        transaction = LICENSE_CPP[start:end]
        self.assertEqual(transaction.count("EEPROM.commit()"), 1)
        self.assertIn("EEPROM.put(LICENSE_EEPROM_OFFSET, licenseToSave)", transaction)
        self.assertIn("EEPROM.put(LICENSE_CLOCK_EEPROM_OFFSET, clockToSave)", transaction)

        activation_start = LICENSE_CPP.index("bool license_attempt_activate(")
        activation_end = LICENSE_CPP.index(
            "// =========================================================\n// License commands",
            activation_start,
        )
        activation = LICENSE_CPP[activation_start:activation_end]
        self.assertIn("license_persist_activation(rec, activationEpoch)", activation)
        self.assertNotIn("accept_phone_time(activationEpoch", activation)

        reply_start = INO.index("void sendLicenseWsReply(")
        reply_end = INO.index("void onWsEvent(", reply_start)
        reply = INO[reply_start:reply_end]
        self.assertIn("licenseTelemetryPending = true", reply)
        self.assertNotIn("broadcastWsData();", reply)
        loop_start = INO.index("void loop()")
        self.assertIn("if (licenseTelemetryPending)", INO[loop_start:])

        # The license path has no restart primitive; the model also records
        # that every successful renewal/replacement above used reset_count == 0
        # until the two explicit reboot checks.
        self.assertNotIn("ESP.restart()", activation)


if __name__ == "__main__":
    unittest.main(verbosity=2)
