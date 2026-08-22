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
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import androidx.car.app.validation.HostValidator
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/**
 * Android Auto front-end for Car Guard.
 *
 * يعرض نفس قراءات شاشة الموبايل على شاشة العربية في شكل كروت حية:
 * حرارة المحرك، فولت البطارية، السرعة/المسافة (من GPS الموبايل)، المروحة،
 * الدينامو، وحالة الإنذار. بيسحب `/data` من الوحدة مباشرة كل 2 ثانية
 * بنفس ألوان التطبيق (أخضر/أصفر/أحمر نيون) وبنفس منطق الحدود.
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

        // "Live" = نفس معدل التحديث اللي بيعمله التطبيق، لكن من غير ما يكون
        // الواجهة مفروض تكون مفتوحة.
        private const val POLL_INTERVAL_MS = 2000L

        // نفس باليتة النيون اللي في شاشة الموبايل (AppColors).
        private const val NEON_GREEN = 0xFF00FF88.toInt()
        private const val NEON_AMBER = 0xFFFFAA00.toInt()
        private const val NEON_RED = 0xFFFF2244.toInt()
        private const val MUTED_GRAY = 0xFF64748B.toInt()
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

    private fun customColor(color: Int): CarColor =
        CarColor.createCustom(color, color)

    private fun icon(res: Int, color: Int): CarIcon =
        CarIcon.Builder(
            IconCompat.createWithResource(carContext, res),
        ).setTint(customColor(color)).build()

    private fun gridItem(
        iconRes: Int,
        title: CharSequence,
        text: CharSequence,
        color: Int,
    ): GridItem = GridItem.Builder()
        .setImage(icon(iconRes, color), GridItem.IMAGE_TYPE_ICON)
        .setTitle(title)
        .setText(text)
        .build()

    override fun onGetTemplate(): Template {
        val l = carContext
        val current = reading
        val list = ItemList.Builder()

        if (current == null) {
            // أول اتصال — شاشة تحميل صغيرة زي شاشة الموبايل.
            list.addItem(
                gridItem(
                    R.drawable.ic_car_status,
                    l.getString(R.string.aa_connecting),
                    l.getString(R.string.aa_connecting_sub),
                    MUTED_GRAY,
                ),
            )
        } else if (!current.connected) {
            // ضياع الاتصال — كروت فاضية + حالة حمراء، نفس شكل الموبايل.
            list.addItem(
                gridItem(
                    R.drawable.ic_car_temp,
                    l.getString(R.string.aa_temp),
                    l.getString(R.string.aa_no_data),
                    MUTED_GRAY,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_battery,
                    l.getString(R.string.aa_voltage),
                    l.getString(R.string.aa_no_data),
                    MUTED_GRAY,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_speed,
                    l.getString(R.string.aa_speed),
                    speedText(),
                    MUTED_GRAY,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_fan,
                    l.getString(R.string.aa_fan),
                    l.getString(R.string.aa_no_data),
                    MUTED_GRAY,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_alternator,
                    l.getString(R.string.aa_alternator),
                    l.getString(R.string.aa_no_data),
                    MUTED_GRAY,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_alert,
                    l.getString(R.string.aa_status),
                    l.getString(R.string.aa_disconnected),
                    NEON_RED,
                ),
            )
        } else {
            // — حرارة المحرك: نفس منطق التطبيق (بدون تسامح -5) —
            val tempColor = when {
                current.temp >= current.maxTemp -> NEON_RED
                else -> NEON_GREEN
            }

            // — البطارية: ‎0.0 تعني "لا قراءة" — مطابق للتطبيق —
            val voltColor = when {
                current.volt <= 0.0 -> MUTED_GRAY
                current.volt < current.minVolt || current.volt > current.maxVolt ->
                    NEON_RED
                else -> NEON_GREEN
            }

            // — السرعة والمسافة من GPS الموبايل (مكتوبة من التطبيق) —
            val speedColor = when {
                speedKmh() >= speedLimit() -> NEON_RED
                speedKmh() <= 0.0 -> MUTED_GRAY
                else -> NEON_GREEN
            }

            val fanColor = if (current.fanOn) NEON_GREEN else NEON_AMBER

            // — الدينامو: نفس منطق "الشحن" في التطبيق (13V+) —
            val charging = current.volt >= 13.0
            val altColor = if (charging) NEON_GREEN else MUTED_GRAY
            val altText = if (charging) {
                l.getString(R.string.aa_charging)
            } else {
                l.getString(R.string.aa_not_charging)
            }

            // — الحالة: اتصال + إنذار، نفس أولوية شاشة الموبايل —
            val alarmColor = when {
                current.alarm -> NEON_RED
                current.muted -> NEON_AMBER
                else -> NEON_GREEN
            }
            val alarmText = when {
                current.alarm -> l.getString(R.string.aa_connected) +
                    " · " + l.getString(R.string.aa_active)
                current.muted -> l.getString(R.string.aa_connected) +
                    " · " + l.getString(R.string.aa_muted)
                else -> l.getString(R.string.aa_connected) +
                    " · " + l.getString(R.string.aa_ok)
            }
            val alarmIcon = if (current.alarm) {
                R.drawable.ic_car_alarm
            } else {
                R.drawable.ic_car_status
            }

            list.addItem(
                gridItem(
                    R.drawable.ic_car_temp,
                    l.getString(R.string.aa_temp),
                    String.format(Locale.US, "%.1f °C", current.temp),
                    tempColor,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_battery,
                    l.getString(R.string.aa_voltage),
                    String.format(Locale.US, "%.2f V", current.volt),
                    voltColor,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_speed,
                    l.getString(R.string.aa_speed),
                    speedText(),
                    speedColor,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_fan,
                    l.getString(R.string.aa_fan),
                    if (current.fanOn) l.getString(R.string.aa_on) else
                        l.getString(R.string.aa_off),
                    fanColor,
                ),
            )
            list.addItem(
                gridItem(
                    R.drawable.ic_car_alternator,
                    l.getString(R.string.aa_alternator),
                    altText,
                    altColor,
                ),
            )
            list.addItem(
                gridItem(
                    alarmIcon,
                    l.getString(R.string.aa_status),
                    alarmText,
                    alarmColor,
                ),
            )
        }

        return GridTemplate.Builder()
            .setTitle(l.getString(R.string.aa_title))
            .setSingleList(list.build())
            .build()
    }

    // ------------------------------------------------------------------
    // GPS bridge: التطبيق بيحفظ السرعة والمسافة في نفس الـ Preferences
    // اللي بيقرأها الـ CarAppService — عشان شاشة العربية تفضل حية حتى
    // لو واجهة Flutter واخدة وقفة.
    // ------------------------------------------------------------------

    private fun prefs(): SharedPreferences = carContext.getSharedPreferences(
        "FlutterSharedPreferences",
        CarContext.MODE_PRIVATE,
    )

    private fun speedKmh(): Double =
        prefs().getString("flutter.speed_kmh", null)?.toDoubleOrNull() ?: 0.0

    private fun distanceKm(): Double =
        prefs().getString("flutter.trip_distance_km", null)?.toDoubleOrNull() ?: 0.0

    private fun speedLimit(): Double {
        return try {
            val raw = prefs().getString("flutter.app_settings", null) ?: return 120.0
            JSONObject(raw).optDouble("speedLimit", 120.0)
        } catch (exception: Exception) {
            120.0
        }
    }

    private fun speedText(): String {
        val speed = speedKmh()
        val distance = distanceKm()
        return when {
            speed <= 0.0 && distance <= 0.0 -> carContext.getString(R.string.aa_no_data)
            speed <= 0.0 ->
                String.format(Locale.US, "-- km/h · %.1f km", distance)
            else ->
                String.format(Locale.US, "%.0f km/h · %.1f km", speed, distance)
        }
    }

    private fun loadHost(): String {
        return try {
            // 1) mDNS-discovered address من آخر جلسة — الأولوية لأنه
            //    العنوان بيتغير لو الوحدة انضمت لهوت سبوت.
            val mdnsIp = prefs().getString("flutter.mdns_module_ip", null)
                ?.trim().orEmpty()
            if (mdnsIp.isNotEmpty()) return mdnsIp

            // 2) وإلا نرجع للعنوان المحفوظ في إعدادات التطبيق.
            val raw = prefs().getString("flutter.app_settings", null)
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
