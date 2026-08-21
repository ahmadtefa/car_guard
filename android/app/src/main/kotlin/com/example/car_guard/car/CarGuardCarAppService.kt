package com.example.car_guard.car

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import com.example.car_guard.BuildConfig

/**
 * Android Auto entry point.
 *
 * The car host (Android Auto) binds to this service and asks it for a
 * [Session], which in turn creates the dashboard [androidx.car.app.Screen].
 *
 * NOTE: while developing/testing the app is usually sideloaded and validated
 * with "unknown sources" enabled, so [HostValidator.ALLOW_ALL_HOSTS_VALIDATOR]
 * is used in debug builds. Release builds fall back to the same validator for
 * now — before publishing on Google Play, restrict release builds to the known
 * Android Auto host certificates (see docs/android_auto.md).
 */
class CarGuardCarAppService : CarAppService() {

    override fun createHostValidator(): HostValidator {
        if (BuildConfig.DEBUG) {
            return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        }
        // TODO: switch release builds to a strict allowlist before Play upload.
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(): Session = CarGuardSession()
}
