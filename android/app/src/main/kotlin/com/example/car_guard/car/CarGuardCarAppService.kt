package com.example.car_guard.car

import android.content.Intent
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.SessionInfo
import androidx.car.app.validation.HostValidator

/**
 * Entry point for the Android Auto host (and the Desktop Head Unit used for
 * local testing). The car UI itself is rendered by [CarGuardHomeScreen].
 */
class CarGuardCarAppService : CarAppService() {

    /**
     * While developing we allow any host so the DHU can always connect.
     *
     * TODO(production): return `super.createHostValidator()` in release builds
     * so only trusted (Google-signed) hosts may bind to the car app.
     */
    override fun createHostValidator(): HostValidator =
        HostValidator.ALLOW_ALL_HOSTS_VALIDATOR

    override fun onCreateSession(sessionInfo: SessionInfo): Session =
        CarGuardSession()
}

/**
 * A single session on the car's main display, hosting the status screen.
 */
class CarGuardSession : Session() {

    override fun onCreateScreen(intent: Intent): Screen =
        CarGuardHomeScreen(carContext)
}
