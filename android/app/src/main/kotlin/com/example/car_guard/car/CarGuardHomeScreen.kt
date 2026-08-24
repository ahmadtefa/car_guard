package com.example.car_guard.car

import android.text.format.DateUtils
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Header
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import java.util.Locale

/**
 * Main car screen: shows the live status of the Car Guard device
 * (engine temperature, battery voltage, coolant level and fan state)
 * on the Android Auto display.
 *
 * The data is pushed from the Flutter app through [CarStatusStore]; whenever
 * a newer snapshot arrives the screen is invalidated and re-rendered.
 */
class CarGuardHomeScreen(carContext: CarContext) : Screen(carContext) {

    init {
        CarStatusStore.setListener { invalidateSafely() }
    }

    private fun invalidateSafely() {
        try {
            invalidate()
        } catch (_: IllegalStateException) {
            // The screen is not attached to a session (yet) – nothing to do.
        }
    }

    override fun onGetTemplate(): Template {
        val snapshot = CarStatusStore.read(carContext)

        fun row(title: String, text: String): Row = Row.Builder()
            .setTitle(title)
            .setText(text)
            .build()

        val connectedText = buildString {
            append(if (snapshot.connected) "Connected" else "Offline")
            if (snapshot.lastUpdatedMs > 0L) {
                append(" · ")
                append(
                    DateUtils.getRelativeTimeSpanString(
                        snapshot.lastUpdatedMs,
                        System.currentTimeMillis(),
                        DateUtils.SECOND_IN_MILLIS,
                    ),
                )
            }
        }
        val rows = mutableListOf(row("Connection", connectedText))

        snapshot.engineTemperatureC?.let {
            rows.add(row("Engine temperature", String.format(Locale.US, "%.1f °C", it)))
        }
        snapshot.batteryVoltage?.let {
            rows.add(row("Battery voltage", String.format(Locale.US, "%.2f V", it)))
        }
        snapshot.coolantAvailable?.let {
            rows.add(row("Coolant", if (it) "OK" else "Low"))
        }
        snapshot.fanRunning?.let {
            rows.add(row("Fan", if (it) "ON" else "OFF"))
        }

        val pane = Pane.Builder().apply {
            rows.forEach { addRow(it) }
        }.build()

        return PaneTemplate.Builder(pane)
            .setHeader(
                Header.Builder()
                    .setTitle("Car Guard")
                    .setStartHeaderAction(Action.APP_ICON)
                    .build(),
            )
            .build()
    }
}
