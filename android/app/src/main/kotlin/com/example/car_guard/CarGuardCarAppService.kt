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
import androidx.car.app.model.Action
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
 * الشاشة الرئيسية فيها عدادين **كبيرين**: حرارة المحرك (نصف دائرة بإبرة)
 * وفولت البطارية (شريط بمناطق ملونة) — نفس رسم MiniArcGauge +
 * MiniVoltBarGauge في التطبيق. كروت السرعة/المروحة/الدينامو/الحالة
 * في شاشة "قراءات إضافية" بتتفتح بضغطة على أي عداد أو من الزر
 * العائم. البيانات حية كل 2 ثانية من /data.
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

// ----------------------------------------------------------------------
// إعدادات مشتركة
// ----------------------------------------------------------------------

private const val DEFAULT_HOST = "192.168.4.1"
private const val POLL_INTERVAL_MS = 2000L

// نفس باليتة النيون اللي في شاشة الموبايل (AppColors).
private const val NEON_GREEN = 0x00FF88.toInt()
private const val NEON_AMBER = 0xFFAA00.toInt()
private const val NEON_RED = 0xFF2244.toInt()
private const val NEON_CYAN = 0x00D4FF.toInt()
private const val MUTED_GRAY = 0x64748B.toInt()

// خلفية / مسار العداد — نفس ألوان كروت الموبايل الداكنة.
private const val CARD_BG = 0x0F172A.toInt()
private const val TRACK = 0x1E293B.toInt()
private const val ZONE_RED = 0x55FF2244.toInt()
private const val ZONE_GREEN = 0x5500FF88.toInt()
private const val LABEL = 0x66FFFFFF.toInt()
private const val TICK = 0xB3FFFFFF.toInt()

// ----------------------------------------------------------------------
// قراءات مشتركة: poller واحد فقط مهما كان عدد الشاشات المفتوحة
// ----------------------------------------------------------------------

private object CarReadings {
    var reading: CarReading? = null
        private set

    private var host: String = DEFAULT_HOST
    private var running = false
    private var refs = 0

    private val handler = Handler(Looper.getMainLooper())
    private val listeners = mutableListOf<() -> Unit>()

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    /** كل شاشة بتطلب الـ poller (عندما تبقى ظاهرة) وبتفرّغه عند إخفائها. */
    fun acquire(newHost: String) {
        host = newHost
        refs++
        if (!running) {
            running = true
            poll()
        }
    }

    fun release() {
        refs = (refs - 1).coerceAtLeast(0)
        if (refs == 0 && running) {
            running = false
            handler.removeCallbacks(poller)
        }
    }

    private val poller = object : Runnable {
        override fun run() {
            Thread { fetch() }.start()
            handler.postDelayed(this, POLL_INTERVAL_MS)
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

            listeners.forEach { it() }
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

// ----------------------------------------------------------------------
// دوال مساعدة مشتركة (أيقونات + قراءة إعدادات GPS)
// ----------------------------------------------------------------------

private fun customColor(color: Int): CarColor =
    CarColor.createCustom(color, color)

private fun carIcon(carContext: CarContext, res: Int, color: Int): CarIcon =
    CarIcon.Builder(
        IconCompat.createWithResource(carContext, res),
    ).setTint(customColor(color)).build()

private fun gaugeIcon(bitmap: Bitmap): CarIcon =
    CarIcon.Builder(IconCompat.createWithBitmap(bitmap)).build()

private fun prefs(carContext: CarContext): SharedPreferences =
    carContext.getSharedPreferences(
        "FlutterSharedPreferences",
        CarContext.MODE_PRIVATE,
    )

private fun speedKmh(carContext: CarContext): Double =
    prefs(carContext).getString("flutter.speed_kmh", null)
        ?.toDoubleOrNull() ?: 0.0

private fun distanceKm(carContext: CarContext): Double =
    prefs(carContext).getString("flutter.trip_distance_km", null)
        ?.toDoubleOrNull() ?: 0.0

private fun speedLimit(carContext: CarContext): Double = try {
    val raw = prefs(carContext).getString("flutter.app_settings", null)
    if (raw != null) {
        JSONObject(raw).optDouble("speedLimit", 120.0)
    } else {
        120.0
    }
} catch (exception: Exception) {
    120.0
}

private fun speedText(carContext: CarContext): String {
    val speed = speedKmh(carContext)
    val distance = distanceKm(carContext)
    return when {
        speed <= 0.0 && distance <= 0.0 ->
            carContext.getString(R.string.aa_no_data)
        speed <= 0.0 ->
            String.format(Locale.US, "-- km/h · %.1f km", distance)
        else ->
            String.format(Locale.US, "%.0f km/h · %.1f km", speed, distance)
    }
}

private fun loadHost(carContext: CarContext): String = try {
    // 1) عنوان اكتشفه mDNS آخر مرة — الأولوية لأنه بيتغير مع الهوت سبوت.
    val mdnsIp = prefs(carContext).getString("flutter.mdns_module_ip", null)
        ?.trim().orEmpty()
    if (mdnsIp.isNotEmpty()) {
        mdnsIp
    } else {
        // 2) وإلا العنوان المحفوظ في إعدادات التطبيق.
        val raw = prefs(carContext).getString("flutter.app_settings", null)
            ?: DEFAULT_HOST
        JSONObject(raw).optString("deviceHost", DEFAULT_HOST)
            .ifEmpty { DEFAULT_HOST }
    }
} catch (exception: Exception) {
    DEFAULT_HOST
}

// ----------------------------------------------------------------------
// الشاشة الرئيسية: عدادين كبيرين
// ----------------------------------------------------------------------

class CarGuardScreen(carContext: CarContext) : Screen(carContext) {

    private val onReading = { invalidate() }

    init {
        CarReadings.addListener(onReading)
        getLifecycle().addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                CarReadings.acquire(loadHost(carContext))
            }

            override fun onStop(owner: LifecycleOwner) {
                CarReadings.release()
            }

            override fun onDestroy(owner: LifecycleOwner) {
                CarReadings.removeListener(onReading)
            }
        })
    }

    private fun openDetails() {
        screenManager.push(CarGuardDetailsScreen(carContext))
    }

    private fun gaugeGridItem(
        bitmap: Bitmap,
        title: CharSequence,
        text: CharSequence,
        clickable: Boolean = true,
    ): GridItem {
        val builder = GridItem.Builder()
            .setImage(gaugeIcon(bitmap), GridItem.IMAGE_TYPE_LARGE)
            .setTitle(title)
            .setText(text)
        if (clickable) {
            builder.setOnClickListener { openDetails() }
        }
        return builder.build()
    }

    override fun onGetTemplate(): Template {
        val connected = CarReadings.reading?.connected == true
        val current = CarReadings.reading
        val list = ItemList.Builder()

        // — الحرارة: عداد كبير (ضبطة → القراءات الإضافية) —
        list.addItem(
            gaugeGridItem(
                tempGauge(
                    current?.temp ?: 0.0,
                    current?.maxTemp ?: 97.0,
                    active = connected,
                ),
                carContext.getString(R.string.aa_temp),
                if (connected) {
                    String.format(Locale.US, "%.1f °C", current!!.temp)
                } else {
                    carContext.getString(R.string.aa_no_data)
                },
            ),
        )

        // — الفولت: شريط كبير —
        list.addItem(
            gaugeGridItem(
                voltGauge(
                    current?.volt ?: 0.0,
                    current?.minVolt ?: 12.0,
                    current?.maxVolt ?: 14.8,
                    active = connected,
                ),
                carContext.getString(R.string.aa_voltage),
                if (connected) {
                    String.format(Locale.US, "%.2f V", current!!.volt)
                } else {
                    carContext.getString(R.string.aa_no_data)
                },
            ),
        )

        val builder = GridTemplate.Builder()
            .setTitle(
                carContext.getString(
                    if (connected) R.string.aa_title else R.string.aa_title_offline,
                ),
            )
            .setSingleList(list.build())

        if (carContext.getCarAppApiLevel() >= 7) {
            builder.addAction(
                Action.Builder()
                    .setTitle(carContext.getString(R.string.aa_more))
                    .setIcon(carIcon(carContext, R.drawable.ic_car_status, NEON_CYAN))
                    .setBackgroundColor(customColor(CARD_BG))
                    .setOnClickListener { openDetails() }
                    .build(),
            )
        }

        // Car API 8+: أكبر حجم ممكن لكل عناصر الشبكة.
        if (carContext.getCarAppApiLevel() >= 8) {
            builder.setItemSize(GridTemplate.ITEM_SIZE_LARGE)
        }

        return builder.build()
    }

    private fun gaugeSizeDp(dp: Int): Int =
        (dp * carContext.resources.displayMetrics.density).toInt()
            .coerceIn(dp, 720)

    private fun tempGauge(
        temp: Double,
        maxTemp: Double,
        active: Boolean = true,
    ): Bitmap {
        val size = gaugeSizeDp(240)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(CARD_BG)

        val stroke = size * 0.10f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }

        val cx = size / 2f
        val cy = size * 0.60f
        val radius = size * 0.40f
        val arc = RectF(cx - radius, cy - radius, cx + radius, cy + radius)

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

        val color = when {
            temp >= maxTemp -> NEON_RED
            temp >= maxTemp - 10.0 -> NEON_AMBER
            else -> NEON_GREEN
        }

        paint.color = color
        if (sweep > 0f) canvas.drawArc(arc, 180f, sweep, false, paint)

        val angleRad = Math.toRadians(180.0 + 180.0 * percent)
        val needle = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = size * 0.05f
            strokeCap = Paint.Cap.ROUND
            this.color = TICK
        }
        val tipX = cx + (radius - stroke) * cos(angleRad).toFloat()
        val tipY = cy + (radius - stroke) * sin(angleRad).toFloat()

        canvas.drawLine(cx, cy, tipX, tipY, needle)
        canvas.drawCircle(
            cx,
            cy,
            size * 0.08f,
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
        val size = gaugeSizeDp(240)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(CARD_BG)

        val min = 10.0
        val max = 16.0
        fun fraction(v: Double): Float =
            ((v - min) / (max - min)).coerceIn(0.0, 1.0).toFloat()

        val left = size * 0.06f
        val top = size * 0.44f
        val barHeight = size * 0.20f
        val right = size - left
        val width = right - left

        val barRect = RectF(left, top, right, top + barHeight)
        val barPath = Path().apply {
            addRoundRect(barRect, barHeight / 2f, barHeight / 2f, Path.Direction.CW)
        }

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

            canvas.drawCircle(
                left + width * fraction(volt),
                top + barHeight / 2f,
                size * 0.07f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = TICK },
            )
        }

        canvas.restore()

        val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = TICK
            strokeWidth = size * 0.02f
        }
        fun tickAt(f: Float) {
            canvas.drawLine(
                left + width * f,
                top - size * 0.05f,
                left + width * f,
                top + barHeight + size * 0.05f,
                tick,
            )
        }
        tickAt(lowF)
        tickAt(highF)

        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = LABEL
            textSize = size * 0.11f
            textAlign = Paint.Align.LEFT
        }
        val labelY = top + barHeight + size * 0.26f

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
}

// ----------------------------------------------------------------------
// شاشة القراءات الإضافية: سرعة، مروحة، دينامو، حالة
// ----------------------------------------------------------------------

class CarGuardDetailsScreen(carContext: CarContext) : Screen(carContext) {

    private val onReading = { invalidate() }

    init {
        CarReadings.addListener(onReading)
        getLifecycle().addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                CarReadings.acquire(loadHost(carContext))
            }

            override fun onStop(owner: LifecycleOwner) {
                CarReadings.release()
            }

            override fun onDestroy(owner: LifecycleOwner) {
                CarReadings.removeListener(onReading)
            }
        })
    }

    private fun gridItem(
        iconRes: Int,
        title: CharSequence,
        text: CharSequence,
        color: Int,
    ): GridItem = GridItem.Builder()
        .setImage(carIcon(carContext, iconRes, color), GridItem.IMAGE_TYPE_LARGE)
        .setTitle(title)
        .setText(text)
        .build()

    override fun onGetTemplate(): Template {
        val current = CarReadings.reading
        val connected = current?.connected == true
        val list = ItemList.Builder()

        val speedColor = when {
            speedKmh(carContext) >= speedLimit(carContext) -> NEON_RED
            speedKmh(carContext) <= 0.0 -> MUTED_GRAY
            else -> NEON_GREEN
        }

        val fanColor = if (connected && current!!.fanOn) NEON_GREEN else NEON_AMBER
        val fanText = if (connected && current!!.fanOn) {
            carContext.getString(R.string.aa_on)
        } else {
            carContext.getString(R.string.aa_off)
        }

        val charging = connected && current!!.volt >= 13.0
        val altColor = if (charging) NEON_GREEN else MUTED_GRAY
        val altText = if (charging) {
            carContext.getString(R.string.aa_charging)
        } else {
            carContext.getString(R.string.aa_not_charging)
        }

        val alarmColor = when {
            connected && current!!.alarm -> NEON_RED
            connected && current!!.muted -> NEON_AMBER
            connected -> NEON_GREEN
            else -> NEON_RED
        }
        val alarmText = when {
            !connected -> carContext.getString(R.string.aa_disconnected)
            current!!.alarm -> carContext.getString(R.string.aa_active)
            current!!.muted -> carContext.getString(R.string.aa_muted)
            else -> carContext.getString(R.string.aa_ok)
        }
        val alarmIcon = if (connected && current!!.alarm) {
            R.drawable.ic_car_alarm
        } else {
            R.drawable.ic_car_status
        }

        list.addItem(
            gridItem(
                R.drawable.ic_car_speed,
                carContext.getString(R.string.aa_speed),
                speedText(carContext),
                speedColor,
            ),
        )
        list.addItem(
            gridItem(
                R.drawable.ic_car_fan,
                carContext.getString(R.string.aa_fan),
                fanText,
                fanColor,
            ),
        )
        list.addItem(
            gridItem(
                R.drawable.ic_car_alternator,
                carContext.getString(R.string.aa_alternator),
                altText,
                altColor,
            ),
        )
        list.addItem(
            gridItem(
                alarmIcon,
                carContext.getString(R.string.aa_status),
                alarmText,
                alarmColor,
            ),
        )

        val builder = GridTemplate.Builder()
            .setTitle(carContext.getString(R.string.aa_more))
            .setHeaderAction(Action.BACK)
            .setSingleList(list.build())

        if (carContext.getCarAppApiLevel() >= 8) {
            builder.setItemSize(GridTemplate.ITEM_SIZE_LARGE)
        }

        return builder.build()
    }
}
