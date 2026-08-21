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
        private const val POLL_INTERVAL_MS = 2500L
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

    private fun row(title: String, value: String): Row =
        Row.Builder()
            .setTitle(title)
            .addText(value)
            .build()

    override fun onGetTemplate(): Template {
        val listBuilder = ItemList.Builder()
        val current = reading

        if (current == null) {
            listBuilder.addItem(row("Car Guard", "Connecting to module…"))
            listBuilder.addItem(row("Tip", "افتح التطبيق مرة واحدة لتحفظ عنوان الجهاز"))
        } else if (!current.connected) {
            listBuilder.addItem(row("Status", "🔴 غير متصل - تأكد من WiFi CarGuard"))
            listBuilder.addItem(row("Host", host))
            listBuilder.addItem(row("Tip", "الويدجت يعرض آخر قراءة حتى بدون فتح التطبيق"))
        } else {
            // حالة الحرارة - نفس منطق التطبيق بعد التعديل الأخير (بدون -5)
            val tempStatus = when {
                current.temp >= current.maxTemp -> "🔴 حرج!"
                else -> "🟢 طبيعي"
            }

            val voltStatus = when {
                current.volt == 0.0 -> "⚪"
                current.volt < current.minVolt || current.volt > current.maxVolt -> "🔴"
                else -> "🟢"
            }

            // سطر الحرارة كبير وواضح للقيادة
            listBuilder.addItem(
                row("🌡️ حرارة المحرك", "$tempStatus ${String.format(Locale.US, "%.1f °C", current.temp)} / ${String.format(Locale.US, "%.0f°C", current.maxTemp)}"),
            )

            listBuilder.addItem(
                row("🔋 البطارية", "$voltStatus ${String.format(Locale.US, "%.2f V", current.volt)} (${String.format(Locale.US, "%.1f-%.1fV", current.minVolt, current.maxVolt)})"),
            )

            listBuilder.addItem(
                row("🌀 المروحة", if (current.fanOn) "🟢 شغالة" else "⚪ متوقفة"),
            )

            listBuilder.addItem(
                row(
                    "🔔 الإنذار",
                    when {
                        current.alarm -> "🔴 شغال!"
                        current.muted -> "🔕 مكتوم"
                        else -> "🟢 هادئ"
                    },
                ),
            )

            // ويدجت الشاشة الرئيسية - تذكير
            listBuilder.addItem(
                row("🏠 الويدجت", "اضغط مطولاً على الشاشة الرئيسية → ويدجتس → Car Guard 2×1"),
            )
        }

        return ListTemplate.Builder()
            .setTitle("Car Guard • ${if (reading?.connected == true) "متصل 🟢" else "غير متصل 🔴"}")
            .setSingleList(listBuilder.build())
            .build()
    }

    private fun loadHost(): String {
        return try {
            val prefs: SharedPreferences = carContext.getSharedPreferences(
                "FlutterSharedPreferences",
                CarContext.MODE_PRIVATE,
            )

            // 1) An mDNS-discovered address from the last app session wins
            //    when the module joined a hotspot (its DHCP IP is dynamic).
            val mdnsIp = prefs.getString("flutter.mdns_module_ip", null)
                ?.trim().orEmpty()
            if (mdnsIp.isNotEmpty()) return mdnsIp

            // 2) Otherwise fall back to the saved settings (or the default).
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
