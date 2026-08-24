package com.example.car_guard.car

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Single source of truth shared between the Flutter side of the app and the
 * Android Auto car UI.
 *
 * Flutter publishes snapshots through the `car_guard/car_status`
 * [io.flutter.plugin.common.MethodChannel] (see `MainActivity`), and the
 * `CarGuardCarAppService` screens read the latest snapshot to render it on
 * the car display (or on the Desktop Head Unit while testing).
 */
object CarStatusStore {

    /** Latest known state of the ESP8266 device installed in the car. */
    data class Snapshot(
        val connected: Boolean = false,
        val engineTemperatureC: Double? = null,
        val batteryVoltage: Double? = null,
        val coolantAvailable: Boolean? = null,
        val fanRunning: Boolean? = null,
        val lastUpdatedMs: Long = 0L,
    )

    private const val PREFS_NAME = "car_guard_car_status"
    private const val KEY_CONNECTED = "connected"
    private const val KEY_ENGINE_TEMP = "engine_temperature_c"
    private const val KEY_BATTERY_VOLTAGE = "battery_voltage"
    private const val KEY_COOLANT_AVAILABLE = "coolant_available"
    private const val KEY_FAN_RUNNING = "fan_running"
    private const val KEY_LAST_UPDATED = "last_updated_ms"

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var listener: (() -> Unit)? = null

    /** Persists [snapshot] locally so it survives process restarts, then notifies the car UI. */
    fun save(context: Context, snapshot: Snapshot) {
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .apply {
                putBoolean(KEY_CONNECTED, snapshot.connected)
                putLong(KEY_LAST_UPDATED, snapshot.lastUpdatedMs)
                if (snapshot.engineTemperatureC != null) {
                    putString(KEY_ENGINE_TEMP, snapshot.engineTemperatureC.toString())
                } else {
                    remove(KEY_ENGINE_TEMP)
                }
                if (snapshot.batteryVoltage != null) {
                    putString(KEY_BATTERY_VOLTAGE, snapshot.batteryVoltage.toString())
                } else {
                    remove(KEY_BATTERY_VOLTAGE)
                }
                if (snapshot.coolantAvailable != null) {
                    putBoolean(KEY_COOLANT_AVAILABLE, snapshot.coolantAvailable)
                } else {
                    remove(KEY_COOLANT_AVAILABLE)
                }
                if (snapshot.fanRunning != null) {
                    putBoolean(KEY_FAN_RUNNING, snapshot.fanRunning)
                } else {
                    remove(KEY_FAN_RUNNING)
                }
            }
            .apply()

        // Car App Library screens may only be invalidated on the main thread.
        mainHandler.post { listener?.invoke() }
    }

    /** Reads the latest persisted snapshot (never null). */
    fun read(context: Context): Snapshot {
        val prefs = context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return Snapshot(
            connected = prefs.getBoolean(KEY_CONNECTED, false),
            engineTemperatureC = prefs.getString(KEY_ENGINE_TEMP, null)?.toDoubleOrNull(),
            batteryVoltage = prefs.getString(KEY_BATTERY_VOLTAGE, null)?.toDoubleOrNull(),
            coolantAvailable = if (prefs.contains(KEY_COOLANT_AVAILABLE)) {
                prefs.getBoolean(KEY_COOLANT_AVAILABLE, true)
            } else {
                null
            },
            fanRunning = if (prefs.contains(KEY_FAN_RUNNING)) {
                prefs.getBoolean(KEY_FAN_RUNNING, false)
            } else {
                null
            },
            lastUpdatedMs = prefs.getLong(KEY_LAST_UPDATED, 0L),
        )
    }

    /**
     * Registers a callback that is invoked on the main thread whenever a new
     * snapshot is saved while the car UI is visible. Pass `null` to unregister.
     */
    fun setListener(newListener: (() -> Unit)?) {
        listener = newListener
    }
}
