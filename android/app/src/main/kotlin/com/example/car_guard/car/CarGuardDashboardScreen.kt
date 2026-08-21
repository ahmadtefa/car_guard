package com.example.car_guard.car

import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarText
import androidx.car.app.model.ForegroundCarColorSpan
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.OnClickListener
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import com.example.car_guard.R
import java.util.Locale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * The main Android Auto screen of Car Guard.
 *
 * Shows the live readings of the ESP8266 guard device (battery voltage,
 * engine temperature, coolant level, radiator fan, alarm state) and refreshes
 * automatically every [REFRESH_INTERVAL_MS] while the screen is visible.
 *
 * All values that pass a safety threshold are highlighted in red so they can
 * be caught with a quick glance while driving.
 */
class CarGuardDashboardScreen(carContext: CarContext) : Screen(carContext) {

    private val deviceClient = DeviceClient(carContext)

    @Volatile
    private var snapshot: DeviceSnapshot? = null
    private var refreshInFlight = false

    init {
        refresh()
        // Periodic refresh loop; it is cancelled automatically when the
        // screen is destroyed and skips cycles while the app is not visible.
        lifecycleScope.launch {
            while (lifecycle.currentState.isAtLeast(Lifecycle.State.INITIALIZED)) {
                delay(REFRESH_INTERVAL_MS)
                if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                    refresh()
                }
            }
        }
    }

    override fun onGetTemplate(): Template {
        val data = snapshot ?: return loadingTemplate()
        return if (data.connected) dashboardTemplate(data) else disconnectedTemplate()
    }

    /** Triggers an async reload; the template is invalidated when data arrives. */
    private fun refresh() {
        if (refreshInFlight) return
        refreshInFlight = true
        lifecycleScope.launch {
            snapshot = runCatching { deviceClient.fetchStatus() }
                .getOrElse { DeviceSnapshot.disconnected() }
            refreshInFlight = false
            invalidate()
        }
    }

    private fun onMuteAlarm() {
        lifecycleScope.launch {
            val ok = deviceClient.muteAlarm()
            CarToast.makeText(
                carContext,
                getString(if (ok) R.string.car_toast_mute_ok else R.string.car_toast_mute_failed),
                CarToast.LENGTH_LONG,
            ).show()
            refresh()
        }
    }

    // ---------------------------------------------------------------------
    // Templates
    // ---------------------------------------------------------------------

    private fun loadingTemplate(): Template =
        MessageTemplate.Builder(getString(R.string.car_loading))
            .setTitle(getString(R.string.car_app_title))
            .setIcon(iconOf(R.mipmap.ic_launcher))
            .addAction(refreshAction())
            .build()

    private fun disconnectedTemplate(): Template =
        MessageTemplate.Builder(getString(R.string.car_disconnected_message))
            .setTitle(getString(R.string.car_disconnected_title))
            .setIcon(iconOf(R.mipmap.ic_launcher))
            .addAction(refreshAction())
            .build()

    private fun dashboardTemplate(data: DeviceSnapshot): Template {
        val list = ItemList.Builder()

        // While the alarm is active its row replaces the connection row so
        // the list always stays within the driving content limit (6 rows).
        if (data.buzzerActive == true) {
            list.addItem(
                Row.Builder()
                    .setTitle(getString(R.string.car_row_alarm))
                    .setImage(iconOf(R.drawable.ic_bell_24))
                    .addText(warning(getString(R.string.car_alarm_on), true))
                    .build(),
            )
        } else {
            list.addItem(
                Row.Builder()
                    .setTitle(getString(R.string.car_row_connection))
                    .setImage(iconOf(R.drawable.ic_wifi_24))
                    .addText(getString(R.string.car_connected))
                    .build(),
            )
        }

        // Battery voltage (with the optional voltage difference).
        val batteryRow = Row.Builder()
            .setTitle(getString(R.string.car_row_battery))
            .setImage(iconOf(R.drawable.ic_battery_24))
            .addText(warning(formatVolts(data.voltage), isLowBattery(data.voltage)))
        data.voltageDiff?.let {
            batteryRow.addText("${getString(R.string.car_row_volt_diff)}: ${formatVolts(it)}")
        }
        list.addItem(batteryRow.build())

        // Engine temperature.
        list.addItem(
            Row.Builder()
                .setTitle(getString(R.string.car_row_temp))
                .setImage(iconOf(R.drawable.ic_thermometer_24))
                .addText(warning(formatTemp(data.temperatureC), isHot(data.temperatureC)))
                .build(),
        )

        // Coolant level.
        list.addItem(
            Row.Builder()
                .setTitle(getString(R.string.car_row_coolant))
                .setImage(iconOf(R.drawable.ic_water_drop_24))
                .addText(warning(coolantText(data.coolantOk), data.coolantOk == false))
                .build(),
        )

        // Radiator fan.
        list.addItem(
            Row.Builder()
                .setTitle(getString(R.string.car_row_fan))
                .setImage(iconOf(R.drawable.ic_power_24))
                .addText(fanText(data.fanRunning))
                .build(),
        )

        val muteAction = Action.Builder()
            .setTitle(getString(R.string.car_action_mute))
            .setIcon(iconOf(R.drawable.ic_bell_off_24))
            .setOnClickListener(OnClickListener { onMuteAlarm() })
            .build()

        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle(getString(R.string.car_app_title))
            .setHeaderAction(refreshAction())
            .setActionStrip(ActionStrip.Builder().addAction(muteAction).build())
            .build()
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    private fun refreshAction(): Action =
        Action.Builder()
            .setIcon(iconOf(R.drawable.ic_refresh_24))
            .setOnClickListener(OnClickListener { refresh() })
            .build()

    private fun iconOf(resId: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, resId)).build()

    /** Wraps [text] in red when [isWarning] so it pops out while driving. */
    private fun warning(text: String, isWarning: Boolean): CarText =
        CarText.Builder(text)
            .apply { if (isWarning) addSpan(ForegroundCarColorSpan.create(CarColor.RED)) }
            .build()

    private fun getString(resId: Int): String = carContext.getString(resId)

    private fun isLowBattery(volts: Double?): Boolean = volts != null && volts < 11.5

    private fun isHot(tempC: Double?): Boolean = tempC != null && tempC >= 100.0

    private fun formatVolts(value: Double?): String =
        value?.let { String.format(Locale.US, "%.2f V", it) } ?: "--"

    private fun formatTemp(value: Double?): String =
        value?.let { String.format(Locale.US, "%.1f °C", it) } ?: "--"

    private fun coolantText(ok: Boolean?): String = when (ok) {
        true -> getString(R.string.car_coolant_ok)
        false -> getString(R.string.car_coolant_low)
        null -> "--"
    }

    private fun fanText(running: Boolean?): String = when (running) {
        true -> getString(R.string.car_fan_on)
        false -> getString(R.string.car_fan_off)
        null -> "--"
    }

    private companion object {
        const val REFRESH_INTERVAL_MS = 3_000L
    }
}
