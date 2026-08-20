package com.example.car_guard

import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarAppService
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarText
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.validation.HostValidator
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/**
 * Android Auto front-end for Car Guard.
 *
 * Shows live engine temperature, battery voltage, fan state and the module
 * alarm state on the car's head unit. It polls the module directly over
 * HTTP (same `/data` endpoint the Flutter app uses) and reads the saved
 * device address from the Flutter SharedPreferences.
 *
 * Note: distributed as a personal/sideloaded app — vehicle-monitoring is
 * not a Play-Store-distributable Android Auto category.
 */
class CarGuardCarAppService : CarAppService() {
    override fun onCreateSession(): Session = CarGuardSession()

    override fun createHostValidator(): HostValidator =
        HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
}

class CarGuardSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen = CarGuardScreen(carContext)
}

data class CarReading(
    val connected: Boolean,
    val temp: Double,
    val volt: Double,
    val fanOn: Boolean,
    val alarm: Boolean,
    val muted: Boolean,
    val maxTemp: Double,
    val minVolt: Double,
    val maxVolt: Double,
)

class CarGuardScreen(carContext: CarContext) : Screen(carContext) {

    companion object {
        private const val DEFAULT_HOST = "192.168.4.1"
        private const val POLL_INTERVAL_MS = 5000L
    }

    private var reading: CarReading? = null
    private var host: String = DEFAULT_HOST

    private val handler = Handler(Looper.getMainLooper())

    private val poller = object : Runnable {
        override fun run() {
            Thread { fetch() }.start()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                host = loadHost()
                poller.run()
            }

            override fun onStop(owner: LifecycleOwner) {
                handler.removeCallbacks(poller)
            }
        })
    }

    private fun coloredText(text: String, color: CarColor): CarText =
        CarText.Builder(text).setCarColor(color).build()

    private fun row(title: String, value: String, color: CarColor): Row =
        Row.Builder()
            .setTitle(title)
            .addText(coloredText(value, color))
            .build()

    override fun onGetTemplate(): Template {
        val listBuilder = ItemList.Builder()
        val current = reading

        if (current == null) {
            listBuilder.addItem(row("Car Guard", "Connecting to module…", CarColor.DEFAULT))
        } else if (!current.connected) {
            listBuilder.addItem(row("Status", "Disconnected", CarColor.RED))
            listBuilder.addItem(row("Module address", host, CarColor.DEFAULT))
        } else {
            val tempColor = when {
                current.temp >= current.maxTemp -> CarColor.RED
                current.temp >= current.maxTemp - 5 -> CarColor.YELLOW
                else -> CarColor.GREEN
            }

            val voltColor = when {
                current.volt < current.minVolt || current.volt > current.maxVolt -> CarColor.RED
                else -> CarColor.GREEN
            }

            listBuilder.addItem(
                row("Engine temperature", String.format(Locale.US, "%.1f °C", current.temp), tempColor),
            )

            listBuilder.addItem(
                row("Battery voltage", String.format(Locale.US, "%.2f V", current.volt), voltColor),
            )

            listBuilder.addItem(
                row("Radiator fan", if (current.fanOn) "ON" else "OFF", if (current.fanOn) CarColor.GREEN else CarColor.DEFAULT),
            )

            listBuilder.addItem(
                row(
                    "Module alarm",
                    when {
                        current.alarm -> "ACTIVE!"
                        current.muted -> "Muted"
                        else -> "OK"
                    },
                    if (current.alarm) CarColor.RED else CarColor.DEFAULT,
                ),
            )
        }

        return ListTemplate.Builder()
            .setTitle("Car Guard")
            .setSingleList(listBuilder.build())
            .build()
    }

    private fun loadHost(): String {
        return try {
            val prefs: SharedPreferences = carContext.getSharedPreferences(
                "FlutterSharedPreferences",
                CarContext.MODE_PRIVATE,
            )

            val raw = prefs.getString("flutter.app_settings", null)
                ?: return DEFAULT_HOST

            JSONObject(raw).optString("deviceHost", DEFAULT_HOST)
                .ifEmpty { DEFAULT_HOST }
        } catch (exception: Exception) {
            DEFAULT_HOST
        }
    }

    private fun fetch() {
        val result: CarReading? = try {
            val connection = URL("http://$host/data").openConnection()
                as HttpURLConnection

            connection.connectTimeout = 4000
            connection.readTimeout = 4000

            val body = connection.inputStream.bufferedReader().readText()
            connection.disconnect()

            parse(body)
        } catch (exception: Exception) {
            null
        }

        handler.post {
            reading = result ?: CarReading(
                connected = false,
                temp = 0.0,
                volt = 0.0,
                fanOn = false,
                alarm = false,
                muted = false,
                maxTemp = 97.0,
                minVolt = 12.0,
                maxVolt = 14.8,
            )

            invalidate()
        }
    }

    private fun parse(body: String): CarReading? {
        return try {
            val json = JSONObject(body)

            CarReading(
                connected = true,
                temp = json.optDouble("temp", 0.0),
                volt = json.optDouble("volt", 0.0),
                fanOn = json.optInt("fanState", 0) == 1,
                alarm = json.optInt("alarm", 0) == 1,
                muted = json.optInt("muted", 0) == 1,
                maxTemp = json.optDouble("maxTemp", 97.0),
                minVolt = json.optDouble("minVolt", 12.0),
                maxVolt = json.optDouble("maxVolt", 14.8),
            )
        } catch (exception: Exception) {
            null
        }
    }
}
