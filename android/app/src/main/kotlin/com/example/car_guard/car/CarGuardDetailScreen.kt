package com.example.car_guard.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Header
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import java.util.Locale

enum class SensorType {
    ENGINE_TEMP,
    BATTERY,
    COOLANT,
    FAN,
    VOLTAGE_DIFF,
    SYSTEM,
}

/**
 * Diagnostic and detail screen for an individual sensor or system metric.
 */
class CarGuardDetailScreen(
    carContext: CarContext,
    private val sensorType: SensorType,
) : Screen(carContext) {

    init {
        CarStatusStore.setListener { invalidateSafely() }
    }

    private fun invalidateSafely() {
        try {
            invalidate()
        } catch (_: IllegalStateException) {
            // Not attached yet
        }
    }

    override fun onGetTemplate(): Template {
        val snapshot = CarStatusStore.read(carContext)
        val paneBuilder = Pane.Builder()

        fun row(title: String, text: String): Row = Row.Builder()
            .setTitle(title)
            .setText(text)
            .build()

        var screenTitle = "Sensor Details"

        when (sensorType) {
            SensorType.ENGINE_TEMP -> {
                screenTitle = "Engine Temperature"
                val temp = snapshot.engineTemperatureC
                val currentText = temp?.let { String.format(Locale.US, "%.1f °C", it) } ?: "No Data"
                val statusText = when {
                    !snapshot.connected -> "Device Offline"
                    temp == null -> "Waiting for sensor readings..."
                    temp >= 102.0 -> "🔴 CRITICAL - Engine Overheating!"
                    temp >= 95.0 -> "🟡 WARNING - High Operating Temperature"
                    temp < 60.0 -> "🔵 WARMING UP - Below normal operating temp"
                    else -> "🟢 OPTIMAL - Operating within safe limits"
                }

                paneBuilder.addRow(row("Current Temperature", currentText))
                paneBuilder.addRow(row("Status Evaluation", statusText))
                paneBuilder.addRow(row("Optimal Range", "80.0 °C – 95.0 °C (Max: 102.0 °C)"))
                paneBuilder.addRow(row("Safety Tip", "Ensure radiator coolant is full and fans are spinning during heavy traffic."))
            }

            SensorType.BATTERY -> {
                screenTitle = "Battery & Alternator"
                val volts = snapshot.batteryVoltage
                val currentText = volts?.let { String.format(Locale.US, "%.2f V", it) } ?: "No Data"
                val statusText = when {
                    !snapshot.connected -> "Device Offline"
                    volts == null -> "Waiting for sensor readings..."
                    volts < 11.8 -> "🔴 LOW - Battery discharge warning"
                    volts < 12.4 -> "🟡 FAIR - Low state of charge"
                    volts in 13.5..14.8 -> "🟢 HEALTHY - Alternator actively charging"
                    volts > 15.0 -> "🔴 OVERVOLTAGE - Check alternator regulator"
                    else -> "🟢 NORMAL - Stable battery voltage"
                }

                paneBuilder.addRow(row("Current Voltage", currentText))
                paneBuilder.addRow(row("Charging Status", statusText))
                paneBuilder.addRow(row("Healthy Range", "12.4V – 12.8V (Rest) / 13.6V – 14.6V (Running)"))
                paneBuilder.addRow(
                    row(
                        "Alternator Health",
                        if ((volts ?: 0.0) >= 13.5) "Alternator is charging normally" else "Alternator output may be resting or weak",
                    ),
                )
            }

            SensorType.COOLANT -> {
                screenTitle = "Coolant Level"
                val coolantOk = snapshot.coolantAvailable
                val currentText = when (coolantOk) {
                    true -> "🟢 Level OK (Sufficient)"
                    false -> "🔴 WARNING: Low Coolant Level!"
                    null -> "No Data"
                }

                paneBuilder.addRow(row("Sensor Status", currentText))
                paneBuilder.addRow(row("Detection Mode", "Radiator reservoir sensor probe"))
                paneBuilder.addRow(
                    row(
                        "Action Required",
                        if (coolantOk == false) {
                            "Stop vehicle safely and refill coolant after the engine cools down!"
                        } else {
                            "Coolant fluid level is optimal. No action required."
                        },
                    ),
                )
            }

            SensorType.FAN -> {
                screenTitle = "Radiator Fan System"
                val fanOn = snapshot.fanRunning
                val currentText = when (fanOn) {
                    true -> "🌀 ACTIVATED (Cooling Engine)"
                    false -> "⏸️ IDLE (Standby)"
                    null -> "No Data"
                }

                paneBuilder.addRow(row("Fan State", currentText))
                paneBuilder.addRow(row("Trigger Mode", "Automatic ECU / CarGuard thermostat relay"))
                paneBuilder.addRow(row("Operation", "Fans engage automatically when temperature exceeds configured threshold."))
            }

            SensorType.VOLTAGE_DIFF -> {
                screenTitle = "Voltage Difference"
                val diff = snapshot.voltageDifference
                val currentText = diff?.let { String.format(Locale.US, "Δ %.2f V", it) } ?: "0.00 V"

                paneBuilder.addRow(row("Voltage Drop / Delta", currentText))
                paneBuilder.addRow(
                    row(
                        "Line Health",
                        if ((diff ?: 0.0) < 0.4) "🟢 Low line resistance (Optimal)" else "🟡 Voltage drop detected on high electrical load",
                    ),
                )
                paneBuilder.addRow(row("Information", "Monitors difference between sensor lines to detect bad ground or high resistance."))
            }

            SensorType.SYSTEM -> {
                screenTitle = "Car Guard System"
                paneBuilder.addRow(row("Connection", if (snapshot.connected) "🟢 Connected to ESP8266" else "🔴 Offline / Disconnected"))
                paneBuilder.addRow(row("Communication", "WebSocket Real-time Telemetry"))
                paneBuilder.addRow(row("Device Model", "ESP8266 CarGuard Pro"))
            }
        }

        paneBuilder.addAction(
            Action.Builder()
                .setTitle("Back to Dashboard")
                .setOnClickListener {
                    screenManager.pop()
                }
                .build(),
        )

        return PaneTemplate.Builder(paneBuilder.build())
            .setHeader(
                Header.Builder()
                    .setTitle(screenTitle)
                    .setStartHeaderAction(Action.BACK)
                    .build(),
            )
            .build()
    }
}
