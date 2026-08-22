package com.example.car_guard

import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
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
import kotlin.math.cos
import kotlin.math.sin

/**
 * Android Auto front-end for Car Guard.
 *
 * شاشة حية بنفس قراءات الموبايل: حرارة المحرك على **عداد نص دائري**
 * وفولت البطارية على **شريط ملون بمناطق خضراء/حمراء** (نفس رسم
 * MiniArcGauge + MiniVoltBarGauge في التطبيق)، مع سرعة/مسافة GPS،
 * المروحة، الدينامو وحالة الإنذار. بتسحب `/data` كل 2 ثانية بنفس
 * ألوان النيون وبنفس منطق الحدود.
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
        private const val POLL_INTERVAL_MS = 2000L

        // نفس باليتة النيون اللي في شاشة الموبايل (AppColors).
        private const val NEON_GREEN = 0x00FF88.toInt()
        private const val NEON_AMBER = 0xFFAA00.toInt()
        private const val NEON_RED = 0xFF2244.toInt()
        private const val MUTED_GRAY = 0x64748B.toInt()

        // خلفية / مسار العداد — نفس ألوان كروت الموبايل الداكنة.
        private const val CARD_BG = 0x0F172A.toInt()
        private const val TRACK = 0x1E293B.toInt()
        private const val ZONE_RED = 0x55FF2244.toInt()
        private const val ZONE_GREEN = 0x5500FF88.toInt()
        private const val LABEL = 0x66FFFFFF.toInt()
        private const val TICK = 0xB3FFFFFF.toInt()
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

    private fun gaugeIcon(bitmap: Bitmap): CarIcon =
        CarIcon.Builder(IconCompat.createWithBitmap(bitmap)).build()

    // الأيقونات الصغيرة: IMAGE_TYPE_LARGE عشان تتعرض بحجم واضح
    // على شاشة العربية (نفس حجم صور العدادات تقريبًا).
    private fun gridItem(
        iconRes: Int,
        title: CharSequence,
        text: CharSequence,
        color: Int,
    ): GridItem = GridItem.Builder()
        .setImage(icon(iconRes, color), GridItem.IMAGE_TYPE_LARGE)
        .setTitle(title)
        .setText(text)
        .build()

    private fun gaugeGridItem(
        bitmap: Bitmap,
        title: CharSequence,
        text: CharSequence,
    ): GridItem = GridItem.Builder()
        .setImage(gaugeIcon(bitmap), GridItem.IMAGE_TYPE_LARGE)
        .setTitle(title)
        .setText(text)
        .build()

    override fun onGetTemplate(): Template {
        val l = carContext
        val current = reading
        val list = ItemList.Builder()

        if (current == null) {
            list.addItem(
                gaugeGridItem(
                    tempGauge(0.0, 97.0, active = false),
                    l.getString(R.string.aa_temp),
                    l.getString(R.string.aa_no_data),
                ),
            )
            list.addItem(
                gaugeGridItem(
                    voltGauge(0.0, 12.0, 14.8, active = false),
                    l.getString(R.string.aa_voltage),
                    l.getString(R.string.aa_no_data),
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
        } else if (!current.connected) {
            list.addItem(
                gaugeGridItem(
                    tempGauge(0.0, current.maxTemp, active = false),
                    l.getString(R.string.aa_temp),
                    l.getString(R.string.aa_no_data),
                ),
            )
            list.addItem(
                gaugeGridItem(
                    voltGauge(0.0, current.minVolt, current.maxVolt, active = false),
                    l.getString(R.string.aa_voltage),
                    l.getString(R.string.aa_no_data),
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
            // — حرارة المحرك: عداد نص دائري (نفس نطاق وحدود الموبايل) —
            list.addItem(
                gaugeGridItem(
                    tempGauge(current.temp, current.maxTemp),
                    l.getString(R.string.aa_temp),
                    String.format(Locale.US, "%.1f °C", current.temp),
                ),
            )

            // — فولت البطارية: شريط بمناطق ‎10—16V مع حدّي min/max —
            list.addItem(
                gaugeGridItem(
                    voltGauge(current.volt, current.minVolt, current.maxVolt),
                    l.getString(R.string.aa_voltage),
                    String.format(Locale.US, "%.2f V", current.volt),
                ),
            )

            val speedColor = when {
                speedKmh() >= speedLimit() -> NEON_RED
                speedKmh() <= 0.0 -> MUTED_GRAY
                else -> NEON_GREEN
            }

            val fanColor = if (current.fanOn) NEON_GREEN else NEON_AMBER

            val charging = current.volt >= 13.0
            val altColor = if (charging) NEON_GREEN else MUTED_GRAY
            val altText = if (charging) {
                l.getString(R.string.aa_charging)
            } else {
                l.getString(R.string.aa_not_charging)
            }

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

        val builder = GridTemplate.Builder()
            .setTitle(l.getString(R.string.aa_title))
            .setSingleList(list.build())

        // Car API 8+ hosts: كبّر كل عناصر الشبكة (العدادات والكروت).
        // على الـ hosts الأقدم بتتجاهل الـ feature بأمان.
        if (carContext.getCarAppApiLevel() >= 8) {
            builder.setItemSize(GridTemplate.ITEM_SIZE_LARGE)
        }

        return builder.build()
    }

    // ------------------------------------------------------------------
    // عدادات مرسومة (Bitmap) — نطاق وحدود نفس شاشة الموبايل:
    //   الحرارة: 40 → 140°C (نصف دائرة + إبرة)
    //   الفولت:  10 → 16V  (شريط بمناطق ملونة + حدّي min/max)
    // ------------------------------------------------------------------

    private fun gaugeSizeDp(dp: Int): Int =
        (dp * carContext.resources.displayMetrics.density).toInt()
            .coerceIn(dp, 512)

    private fun tempGauge(
        temp: Double,
        maxTemp: Double,
        active: Boolean = true,
    ): Bitmap {
        val size = gaugeSizeDp(180)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(CARD_BG)

        val stroke = size * 0.085f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }

        val cx = size / 2f
        val cy = size * 0.58f
        val radius = size * 0.38f
        val arc = RectF(cx - radius, cy - radius, cx + radius, cy + radius)

        // مسار خلفي داكن.
        paint.color = TRACK
        canvas.drawArc(arc, 180f, 180f, false, paint)

        if (!active) {
            paint.color = MUTED_GRAY
            canvas.drawArc(arc, 180f, 180f, false, paint)
            return bmp
        }

        val min = 40.0
        val max = 140.0
        val percent = ((temp - min) / (max - min)).coerceIn(0.0, 1.0)
        val sweep = (180.0 * percent).toFloat()

        // نفس منطق الألوان في التطبيق: بعده عن maxTemp بيعمل تحذير.
        val color = when {
            temp >= maxTemp -> NEON_RED
            temp >= maxTemp - 10.0 -> NEON_AMBER
            else -> NEON_GREEN
        }

        paint.color = color
        if (sweep > 0f) canvas.drawArc(arc, 180f, sweep, false, paint)

        // الإبرة البيضاء + مركز ملون.
        val angleRad = Math.toRadians(180.0 + 180.0 * percent)
        val needle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = size * 0.045f
            strokeCap = Paint.Cap.ROUND
            this.color = TICK
        }
        val tipX = cx + (radius - stroke) * cos(angleRad).toFloat()
        val tipY = cy + (radius - stroke) * sin(angleRad).toFloat()

        canvas.drawLine(cx, cy, tipX, tipY, needle)
        canvas.drawCircle(
            cx,
            cy,
            size * 0.07f,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color },
        )

        return bmp
    }

    private fun voltGauge(
        volt: Double,
        minVolt: Double,
        maxVolt: Double,
        active: Boolean = true,
    ): Bitmap {
        val size = gaugeSizeDp(180)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(CARD_BG)

        // نفس نطاق شريط الموبايل: 10 → 16V.
        val min = 10.0
        val max = 16.0
        fun fraction(v: Double): Float =
            ((v - min) / (max - min)).coerceIn(0.0, 1.0).toFloat()

        val left = size * 0.06f
        val top = size * 0.50f
        val barHeight = size * 0.13f
        val right = size - left
        val width = right - left

        val barRect = RectF(left, top, right, top + barHeight)

        // مسار مدوّر للحواف (Android 23+ مفيش clipRoundRect مضمون،
        // فبنستخدم Path.addRoundRect مع clipPath).
        val barPath = Path().apply {
            addRoundRect(barRect, barHeight / 2f, barHeight / 2f, Path.Direction.CW)
        }

        // مناطق خافتة (أحمر | أخضر | أحمر) زي شريط الموبايل بالظبط.
        canvas.save()
        canvas.clipPath(barPath)

        val zone = Paint(Paint.ANTI_ALIAS_FLAG)
        zone.color = TRACK
        canvas.drawRect(barRect, zone)

        val lowF = fraction(minVolt)
        val highF = fraction(maxVolt)

        zone.color = ZONE_RED
        canvas.drawRect(
            RectF(left, top, left + width * lowF, top + barHeight),
            zone,
        )
        zone.color = ZONE_GREEN
        canvas.drawRect(
            RectF(left + width * lowF, top, left + width * highF, top + barHeight),
            zone,
        )
        zone.color = ZONE_RED
        canvas.drawRect(
            RectF(left + width * highF, top, right, top + barHeight),
            zone,
        )

        // التعبئة حتى القراءة الحالية بتدرج نفس ألوان التطبيق.
        if (active && volt > 0.0) {
            val fill = Paint(Paint.ANTI_ALIAS_FLAG)
            fill.shader = LinearGradient(
                left,
                0f,
                right,
                0f,
                intArrayOf(NEON_RED, NEON_AMBER, NEON_GREEN, NEON_AMBER, NEON_RED),
                null,
                Shader.TileMode.CLAMP,
            )
            canvas.drawRect(
                RectF(left, top, left + width * fraction(volt), top + barHeight),
                fill,
            )

            // مقبض أبيض عند القراءة.
            canvas.drawCircle(
                left + width * fraction(volt),
                top + barHeight / 2f,
                size * 0.045f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = TICK },
            )
        }

        canvas.restore()

        // علامتا حدّي الأدنى/الأقصى.
        val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = TICK
            strokeWidth = size * 0.016f
        }
        fun tickAt(f: Float) {
            canvas.drawLine(
                left + width * f,
                top - size * 0.04f,
                left + width * f,
                top + barHeight + size * 0.04f,
                tick,
            )
        }
        tickAt(lowF)
        tickAt(highF)

        // أرقام المقياس: 10 … min–max … 16.
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = LABEL
            textSize = size * 0.085f
            textAlign = Paint.Align.LEFT
        }
        val labelY = top + barHeight + size * 0.24f

        canvas.drawText("10", left, labelY, label)

        label.textAlign = Paint.Align.CENTER
        label.color = TICK
        canvas.drawText(
            String.format(Locale.US, "%.1f–%.1f", minVolt, maxVolt),
            left + width / 2f,
            labelY,
            label,
        )

        label.color = LABEL
        label.textAlign = Paint.Align.RIGHT
        canvas.drawText("16", right, labelY, label)

        return bmp
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
