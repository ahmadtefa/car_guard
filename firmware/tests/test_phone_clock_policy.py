#!/usr/bin/env python3
"""Host-side executable specification for the phone-clock anti-rollback policy.

The Arduino toolchain is not part of this checkout. These tests model the
small state machine implemented by license.cpp, including its persisted clock
record, monotonic millis() progression, rollback flag, and sticky temporary
expiry state. They intentionally do not model or weaken cryptographic checks.
"""

import unittest


MIN_VALID_EPOCH = 1_640_995_200
PERSIST_INTERVAL = 60
TEMPORARY_TERM_SECONDS = 100


class PhoneClockPolicy:
    def __init__(self, persisted=None):
        self.last_phone_time = persisted["last_phone_time"] if persisted else None
        self.persisted_last_phone_time = self.last_phone_time
        self.clock_rollback = bool(persisted and persisted["clock_rollback"])
        self.temporary_expired = bool(persisted and persisted["temporary_expired"])
        self._persisted_rollback = self.clock_rollback
        self._persisted_expired = self.temporary_expired
        self._runtime_base = self.last_phone_time
        self._elapsed = 0
        self.write_count = 1 if persisted else 0
        self.temporary_expiration = None
        self.permanent_active = False

    @property
    def now(self):
        if self._runtime_base is None:
            return None
        return self._runtime_base + self._elapsed

    def advance(self, seconds):
        self._elapsed += seconds
        self._mark_expired_if_due()

    def reboot(self):
        persisted = {
            "last_phone_time": self.persisted_last_phone_time,
            "clock_rollback": self._persisted_rollback,
            "temporary_expired": self._persisted_expired,
        }
        return PhoneClockPolicy(persisted)

    def _persist(self, phone_time, rollback, expired):
        self.persisted_last_phone_time = phone_time
        self._persisted_rollback = rollback
        self._persisted_expired = expired
        self.write_count += 1

    def receive(self, phone_time, force=False, clear_expired=False):
        if phone_time < MIN_VALID_EPOCH:
            return "INVALID_TIMESTAMP"
        if self.last_phone_time is not None and phone_time < self.last_phone_time:
            self.clock_rollback = True
            if not self._persisted_rollback:
                self._persist(self.last_phone_time, True, self.temporary_expired)
            return "CLOCK_ROLLBACK"

        needs_persist = (
            force
            or self.persisted_last_phone_time is None
            or phone_time - self.persisted_last_phone_time >= PERSIST_INTERVAL
            or self.clock_rollback != self._persisted_rollback
            or (clear_expired and self.temporary_expired)
        )
        next_expired = False if clear_expired else self.temporary_expired
        if needs_persist:
            self._persist(phone_time, self.clock_rollback, next_expired)

        self.last_phone_time = phone_time
        if self._runtime_base is None or phone_time > self.now:
            self._runtime_base = phone_time
            self._elapsed = 0
        if clear_expired:
            self.temporary_expired = False
        return "ACCEPTED"

    def activate_temporary(self, phone_time):
        if self.last_phone_time is not None and phone_time < self.last_phone_time:
            self.receive(phone_time)
            return False
        result = self.receive(phone_time, force=True, clear_expired=True)
        if result != "ACCEPTED":
            return False
        self.temporary_expiration = phone_time + TEMPORARY_TERM_SECONDS
        self.permanent_active = False
        return True

    def activate_permanent(self, phone_time):
        if self.last_phone_time is not None and phone_time < self.last_phone_time:
            self.receive(phone_time)
            return False
        result = self.receive(phone_time, force=True, clear_expired=True)
        if result != "ACCEPTED":
            return False
        self.temporary_expiration = None
        self.permanent_active = True
        return True

    def _mark_expired_if_due(self):
        if (
            not self.permanent_active
            and self.temporary_expiration is not None
            and self.now is not None
            and self.now >= self.temporary_expiration
        ):
            self.temporary_expired = True
            if not self._persisted_expired:
                self._persist(
                    self.last_phone_time,
                    self.clock_rollback,
                    True,
                )

    def temporary_is_active(self):
        self._mark_expired_if_due()
        return (
            not self.permanent_active
            and not self.temporary_expired
            and self.temporary_expiration is not None
            and self.now is not None
            and self.now < self.temporary_expiration
        )

    def permanent_is_active(self):
        return self.permanent_active


class PhoneClockPolicyTest(unittest.TestCase):
    def test_first_valid_phone_time(self):
        clock = PhoneClockPolicy()
        self.assertEqual(clock.receive(1_800_000_000), "ACCEPTED")
        self.assertEqual(clock.last_phone_time, 1_800_000_000)
        self.assertEqual(clock.persisted_last_phone_time, 1_800_000_000)

    def test_increasing_phone_time(self):
        clock = PhoneClockPolicy()
        clock.receive(1_800_000_000)
        clock.receive(1_800_000_030)
        self.assertEqual(clock.last_phone_time, 1_800_000_030)
        # The runtime value moves immediately, while EEPROM persistence is
        # deferred until the wear-avoidance interval.
        self.assertEqual(clock.persisted_last_phone_time, 1_800_000_000)
        clock.receive(1_800_000_060)
        self.assertEqual(clock.persisted_last_phone_time, 1_800_000_060)

    def test_equal_phone_time_is_accepted_without_an_eeprom_write(self):
        clock = PhoneClockPolicy()
        clock.receive(1_800_000_000)
        writes = clock.write_count
        self.assertEqual(clock.receive(1_800_000_000), "ACCEPTED")
        self.assertEqual(clock.write_count, writes)

    def test_rollback_is_rejected_and_recorded(self):
        clock = PhoneClockPolicy()
        clock.receive(1_800_000_000)
        writes = clock.write_count
        self.assertEqual(clock.receive(1_799_999_999), "CLOCK_ROLLBACK")
        self.assertEqual(clock.last_phone_time, 1_800_000_000)
        self.assertTrue(clock.clock_rollback)
        self.assertEqual(clock.write_count, writes + 1)

    def test_rollback_after_reboot_is_rejected(self):
        clock = PhoneClockPolicy()
        clock.receive(1_800_000_000)
        rebooted = clock.reboot()
        self.assertEqual(rebooted.receive(1_799_999_000), "CLOCK_ROLLBACK")
        self.assertEqual(rebooted.last_phone_time, 1_800_000_000)
        self.assertTrue(rebooted.clock_rollback)

    def test_expired_temporary_license_cannot_be_revived_by_rollback(self):
        clock = PhoneClockPolicy()
        self.assertTrue(clock.activate_temporary(1_800_000_000))
        clock.advance(TEMPORARY_TERM_SECONDS + 1)
        self.assertFalse(clock.temporary_is_active())
        rebooted = clock.reboot()
        self.assertEqual(rebooted.receive(1_800_000_050), "ACCEPTED")
        self.assertTrue(rebooted.temporary_expired)
        self.assertFalse(rebooted.temporary_is_active())
        self.assertFalse(rebooted.activate_temporary(1_799_999_000))
        self.assertFalse(rebooted.temporary_is_active())
        self.assertEqual(rebooted.receive(1_799_999_000), "CLOCK_ROLLBACK")
        self.assertFalse(rebooted.temporary_is_active())

    def test_permanent_license_is_unaffected_by_clock_rollback(self):
        clock = PhoneClockPolicy()
        self.assertTrue(clock.activate_permanent(1_800_000_000))
        self.assertTrue(clock.permanent_is_active())
        self.assertEqual(clock.receive(1_799_999_000), "CLOCK_ROLLBACK")
        self.assertTrue(clock.permanent_is_active())


if __name__ == "__main__":
    unittest.main(verbosity=2)
