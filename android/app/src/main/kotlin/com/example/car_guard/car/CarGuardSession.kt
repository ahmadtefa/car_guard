package com.example.car_guard.car

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

/**
 * A car app session: holds the screen stack while the app is shown on the
 * car display. Currently the app has a single dashboard screen.
 */
class CarGuardSession : Session() {

    override fun onCreateScreen(intent: Intent): Screen =
        CarGuardDashboardScreen(carContext)
}
