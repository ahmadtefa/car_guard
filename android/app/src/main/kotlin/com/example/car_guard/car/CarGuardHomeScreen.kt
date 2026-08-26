package com.example.car_guard.car

import android.text.format.DateUtils
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.Header
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import com.example.car_guard.R
import java.util.Locale

/**
 * Main Android Auto dashboard screen: presents live vehicle telemetry
 * (engine temperature, battery voltage, coolant level, radiator fans,
 * voltage delta, and connection status) using a clean glanceable grid
 * with dynamic status tints and interactive detail screens.
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

    private fun createIcon(resId: Int, tint: CarColor): CarIcon {
        return CarIcon.Builder(
            IconCompat.createWithResource(carContext, resId),
        ).setTint(tint).build()
    }

    override fun onGetTemplate(): Template {
        val snapshot = CarStatusStore.read(carContext)
        val itemListBuilder = ItemList.Builder()

        // 1. Engine Temperature Card
        val temp = snapshot.engineTemperatureC
        val tempTitle = temp?.let { String.format(Locale.US, "%.1f °C", it) } ?: "-- °C"
        val tempSubtitle = when {
            !snapshot.connected -> "Engine Temp (Offline)"
            temp == null -> "Waiting..."
            temp >= 102.0 -> "🔥 OVERHEAT"
            temp >= 95.0 -> "⚠️ High Temp"
            temp < 60.0 -> "❄️ Cold"
            else -> "Engine Temp (OK)"
        }
        val tempTint = when {
            !snapshot.connected -> CarColor.DEFAULT
            temp == null -> CarColor.DEFAULT
            temp >= 102.0 -> CarColor.RED
            temp >= 95.0 -> CarColor.YELLOW
            temp < 60.0 -> CarColor.BLUE
            else -> CarColor.GREEN
        }
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle(tempTitle)
                .setText(tempSubtitle)
                .setImage(createIcon(R.drawable.ic_engine_temp, tempTint), GridItem.IMAGE_TYPE_ICON)
                .setOnClickListener {
                    screenManager.push(CarGuardDetailScreen(carContext, SensorType.ENGINE_TEMP))
                }
                .build(),
        )

        // 2. Battery Voltage Card
        val volts = snapshot.batteryVoltage
        val voltsTitle = volts?.let { String.format(Locale.US, "%.2f V", it) } ?: "-- V"
        val voltsSubtitle = when {
            !snapshot.connected -> "Battery (Offline)"
            volts == null -> "Waiting..."
            volts < 11.8 -> "⚠️ Low Battery"
            volts in 13.5..14.8 -> "⚡ Charging (OK)"
            volts > 15.0 -> "⚠️ High Voltage"
            else -> "Battery Voltage"
        }
        val voltsTint = when {
            !snapshot.connected -> CarColor.DEFAULT
            volts == null -> CarColor.DEFAULT
            volts < 11.8 || volts > 15.0 -> CarColor.RED
            volts < 12.4 -> CarColor.YELLOW
            else -> CarColor.GREEN
        }
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle(voltsTitle)
                .setText(voltsSubtitle)
                .setImage(createIcon(R.drawable.ic_battery, voltsTint), GridItem.IMAGE_TYPE_ICON)
                .setOnClickListener {
                    screenManager.push(CarGuardDetailScreen(carContext, SensorType.BATTERY))
                }
                .build(),
        )

        // 3. Coolant Level Card
        val coolant = snapshot.coolantAvailable
        val coolantTitle = when (coolant) {
            true -> "Level OK"
            false -> "LOW COOLANT"
            null -> "--"
        }
        val coolantSubtitle = when {
            !snapshot.connected -> "Coolant (Offline)"
            coolant == false -> "⚠️ Refill Required"
            coolant == true -> "Radiator Coolant"
            else -> "Waiting..."
        }
        val coolantTint = when {
            !snapshot.connected -> CarColor.DEFAULT
            coolant == false -> CarColor.RED
            coolant == true -> CarColor.GREEN
            else -> CarColor.DEFAULT
        }
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle(coolantTitle)
                .setText(coolantSubtitle)
                .setImage(createIcon(R.drawable.ic_coolant, coolantTint), GridItem.IMAGE_TYPE_ICON)
                .setOnClickListener {
                    screenManager.push(CarGuardDetailScreen(carContext, SensorType.COOLANT))
                }
                .build(),
        )

        // 4. Radiator Fan State Card
        val fan = snapshot.fanRunning
        val fanTitle = when (fan) {
            true -> "Fan ON"
            false -> "Fan OFF"
            null -> "--"
        }
        val fanSubtitle = when {
            !snapshot.connected -> "Radiator Fan (Offline)"
            fan == true -> "🌀 Cooling Active"
            fan == false -> "Standby Mode"
            else -> "Radiator Fan"
        }
        val fanTint = when {
            !snapshot.connected -> CarColor.DEFAULT
            fan == true -> CarColor.BLUE
            else -> CarColor.DEFAULT
        }
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle(fanTitle)
                .setText(fanSubtitle)
                .setImage(createIcon(R.drawable.ic_fan, fanTint), GridItem.IMAGE_TYPE_ICON)
                .setOnClickListener {
                    screenManager.push(CarGuardDetailScreen(carContext, SensorType.FAN))
                }
                .build(),
        )

        // 5. Voltage Delta Card
        val diff = snapshot.voltageDifference
        val diffTitle = diff?.let { String.format(Locale.US, "Δ %.2f V", it) } ?: "Δ 0.00 V"
        val diffSubtitle = if (snapshot.connected) "Voltage Delta" else "Delta (Offline)"
        val diffTint = if ((diff ?: 0.0) > 0.4) CarColor.YELLOW else CarColor.GREEN
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle(diffTitle)
                .setText(diffSubtitle)
                .setImage(createIcon(R.drawable.ic_voltage_diff, diffTint), GridItem.IMAGE_TYPE_ICON)
                .setOnClickListener {
                    screenManager.push(CarGuardDetailScreen(carContext, SensorType.VOLTAGE_DIFF))
                }
                .build(),
        )

        // 6. System Connection Card
        val connTitle = if (snapshot.connected) "Connected" else "Offline"
        val connSubtitle = if (snapshot.lastUpdatedMs > 0L) {
            DateUtils.getRelativeTimeSpanString(
                snapshot.lastUpdatedMs,
                System.currentTimeMillis(),
                DateUtils.SECOND_IN_MILLIS,
            ).toString()
        } else {
            "ESP8266 Live"
        }
        val connTint = if (snapshot.connected) CarColor.GREEN else CarColor.RED
        itemListBuilder.addItem(
            GridItem.Builder()
                .setTitle(connTitle)
                .setText(connSubtitle)
                .setImage(createIcon(R.drawable.ic_status, connTint), GridItem.IMAGE_TYPE_ICON)
                .setOnClickListener {
                    screenManager.push(CarGuardDetailScreen(carContext, SensorType.SYSTEM))
                }
                .build(),
        )

        val refreshAction = Action.Builder()
            .setIcon(createIcon(R.drawable.ic_refresh, CarColor.PRIMARY))
            .setOnClickListener {
                CarToast.makeText(carContext, "Refreshing Status...", CarToast.LENGTH_SHORT).show()
                invalidateSafely()
            }
            .build()

        return GridTemplate.Builder()
            .setHeader(
                Header.Builder()
                    .setTitle("Car Guard · Dashboard")
                    .setStartHeaderAction(Action.APP_ICON)
                    .addAction(refreshAction)
                    .build(),
            )
            .setSingleList(itemListBuilder.build())
            .build()
    }
}
