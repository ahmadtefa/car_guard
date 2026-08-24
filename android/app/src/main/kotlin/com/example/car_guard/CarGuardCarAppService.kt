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
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
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
 * شاشة واحدة بكل البيانات: عداد الحرارة (نص دائري بإبرة) وعداد الفولت
 * (شريط بمناطق ملونة) — نفس رسم MiniArcGauge + MiniVoltBarGauge في
 * التطبيق — والقراءة الحية مكتوبة **تحت كل عداد** بخط واضح، ومعاهم
 * في نفس الشاشة: السرعة/المسافة، المروحة، الدينامو وحالة الإنذار.
 * البيانات حية كل 2 ثانية من /data.
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
private const val MUTED_GRAY = 0x64748B.toInt()

// خلفية / مسار العداد — نفس ألوان كروت الموبايل الداكنة.
private const val ZONE_RED = 0x55FF2244.toInt()
private const val ZONE_GREEN = 0x5500FF88.toInt()
private const val LABEL = 0x66FFFFFF.toInt()
private const val TICK = 0xB3FFFFFF.toInt()
private const val FACE_BG = 0xE60F172A.toInt()
private const val TRACK = 0xB3475569.toInt()

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

    // آخر قراءة اتبعتت للمضيف — عشان مترفعش تحديث إلا لما
    // القيم تتغير فعلًا (المضيف بيتعامل مع كل refresh كخطوة جديدة).
    private var lastSent: CarReading? = null

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    fun acquire(newHost: String) {
        host = newHost
        refs++
        if (!running) {
            running = true
            poller.run()
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
            val next = result ?: CarReading(
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

            reading = next

            if (next != lastSent) {
                lastSent = next
                listeners.forEach { it() }
            }
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
    val mdnsIp = prefs(carContext).getString("flutter.mdns_module_ip", null)
        ?.trim().orEmpty()
    if (mdnsIp.isNotEmpty()) {
        mdnsIp
    } else {
        val raw = prefs(carContext).getString("flutter.app_settings", null)
            ?: DEFAULT_HOST
        JSONObject(raw).optString("deviceHost", DEFAULT_HOST)
            .ifEmpty { DEFAULT_HOST }
    }
} catch (exception: Exception) {
    DEFAULT_HOST
}

// ----------------------------------------------------------------------
// الشاشة الرئيسية: كل البيانات في شاشة واحدة
//   عداد الحرارة + عداد الفولت (القراءة تحتهم) + السرعة/المروحة/الدينامو/الحالة
// ----------------------------------------------------------------------

class CarGuardScreen(carContext: CarContext) : Screen(carContext) {

    private val onReading = { invalidate() }

    init {
        CarReadings.addListener(onReading)
        lifecycle.addObserver(object : DefaultLifecycleObserver {
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

    private fun gaugeGridItem(
        bitmap: Bitmap,
        title: CharSequence,
        text: CharSequence,
    ): GridItem = GridItem.Builder()
        .setImage(gaugeIcon(bitmap), GridItem.IMAGE_TYPE_LARGE)
        .setTitle(title)
        .setText(text)
        .build()

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

        // — حرارة المحرك: العداد (القراءة تحت العداد) —
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

        // — فولت البطارية: العداد (القراءة تحت العداد) —
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

        // — السرعة + المسافة —
        val speedColor = when {
            speedKmh(carContext) >= speedLimit(carContext) -> NEON_RED
            speedKmh(carContext) <= 0.0 -> MUTED_GRAY
            else -> NEON_GREEN
        }
        list.addItem(
            gridItem(
                R.drawable.ic_car_speed,
                carContext.getString(R.string.aa_speed),
                speedText(carContext),
                speedColor,
            ),
        )

        // — المروحة —
        val fanColor = if (connected && current!!.fanOn) NEON_GREEN else NEON_AMBER
        list.addItem(
            gridItem(
                R.drawable.ic_car_fan,
                carContext.getString(R.string.aa_fan),
                if (connected && current!!.fanOn) {
                    carContext.getString(R.string.aa_on)
                } else {
                    carContext.getString(R.string.aa_off)
                },
                fanColor,
            ),
        )

        // — الدينامو —
        val charging = connected && current!!.volt >= 13.0
        list.addItem(
            gridItem(
                R.drawable.ic_car_alternator,
                carContext.getString(R.string.aa_alternator),
                if (charging) {
                    carContext.getString(R.string.aa_charging)
                } else {
                    carContext.getString(R.string.aa_not_charging)
                },
                if (charging) NEON_GREEN else MUTED_GRAY,
            ),
        )

        // — الحالة —
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
                alarmIcon,
                carContext.getString(R.string.aa_status),
                alarmText,
                alarmColor,
            ),
        )

        val builder = GridTemplate.Builder()
            .setTitle(
                carContext.getString(
                    if (connected) R.string.aa_title else R.string.aa_title_offline,
                ),
            )
            .setSingleList(list.build())

        if (carContext.getCarAppApiLevel() >= 8) {
            builder.setItemSize(GridTemplate.ITEM_SIZE_LARGE)
        }

        return try {
            builder.build()
        } catch (t: Throwable) {
            fallbackTemplate()
        }
    }

    private fun fallbackTemplate(): Template {
        val connected = CarReadings.reading?.connected == true
        val current = CarReadings.reading
        val rows = ItemList.Builder()

        rows.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_temp))
                .addText(
                    if (connected) {
                        String.format(Locale.US, "%.1f °C", current!!.temp)
                    } else {
                        carContext.getString(R.string.aa_no_data)
                    },
                )
                .build(),
        )
        rows.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_voltage))
                .addText(
                    if (connected) {
                        String.format(Locale.US, "%.2f V", current!!.volt)
                    } else {
                        carContext.getString(R.string.aa_no_data)
                    },
                )
                .build(),
        )
        if (connected) {
            rows.addItem(
                Row.Builder()
                    .setTitle(carContext.getString(R.string.aa_speed))
                    .addText(speedText(carContext))
                    .build(),
            )
        }
        rows.addItem(
            Row.Builder()
                .setTitle(carContext.getString(R.string.aa_status))
                .addText(
                    when {
                        !connected -> carContext.getString(R.string.aa_disconnected)
                        current!!.alarm -> carContext.getString(R.string.aa_active)
                        current!!.muted -> carContext.getString(R.string.aa_muted)
                        else -> carContext.getString(R.string.aa_ok)
                    },
                )
                .build(),
        )

        return ListTemplate.Builder()
            .setTitle(carContext.getString(R.string.aa_title))
            .setSingleList(rows.build())
            .build()
    }

    private fun gaugeSizeDp(dp: Int): Int =
        (dp * carContext.resources.displayMetrics.density).toInt()
            .coerceIn(dp, 720)

    // عداد الحرارة — الرسم زي ما هو (بدون قراءة جوه؛ القراءة تحت العداد).
    private fun tempGauge(
        temp: Double,
        maxTemp: Double,
        active: Boolean = true,
    ): Bitmap {
        val size = gaugeSizeDp(256)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)

        val cx = size / 2f
        val cy = size * 0.52f
        val faceR = size * 0.47f
        val arcR = size * 0.36f
        val stroke = size * 0.085f

        // وجه العداد الدائري — شفاف من غير مربع.
        canvas.drawCircle(
            cx,
            cy,
            faceR,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = FACE_BG },
        )

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }

        val arc = RectF(cx - arcR, cy - arcR, cx + arcR, cy + arcR)
        paint.color = TRACK
        canvas.drawArc(arc, 180f, 180f, false, paint)

        var color = MUTED_GRAY
        if (active) {
            val min = 40.0
            val max = 140.0
            val percent = ((temp - min) / (max - min)).coerceIn(0.0, 1.0)
            val sweep = (180.0 * percent).toFloat()

            color = when {
                temp >= maxTemp -> NEON_RED
                temp >= maxTemp - 10.0 -> NEON_AMBER
                else -> NEON_GREEN
            }

            paint.color = color
            if (sweep > 0f) canvas.drawArc(arc, 180f, sweep, false, paint)

            val angleRad = Math.toRadians(180.0 + 180.0 * percent)
            val tipX = cx + (arcR - stroke / 2f) * cos(angleRad).toFloat()
            val tipY = cy + (arcR - stroke / 2f) * sin(angleRad).toFloat()
            canvas.drawLine(
                cx,
                cy,
                tipX,
                tipY,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    strokeWidth = size * 0.035f
                    strokeCap = Paint.Cap.ROUND
                    this.color = 0xFFFFFFFF.toInt()
                },
            )
        }

        // تدريجات صغيرة عند طرفي القوس: 40 / 140.
        val scale = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = LABEL
            textSize = size * 0.06f
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("40", cx - arcR, cy + size * 0.04f, scale)
        canvas.drawText("140", cx + arcR, cy + size * 0.04f, scale)

        return bmp
    }

    // عداد الفولت — الرسم زي ما هو (بدون قراءة جوه؛ القراءة تحت العداد).
    private fun voltGauge(
        volt: Double,
        minVolt: Double,
        maxVolt: Double,
        active: Boolean = true,
    ): Bitmap {
        val size = gaugeSizeDp(256)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)

        // وجه مستدير شفاف — من غير مربع.
        val faceLeft = size * 0.05f
        val faceTop = size * 0.10f
        val faceRight = size * 0.95f
        val faceBottom = size * 0.90f
        val facePath = Path().apply {
            addRoundRect(
                RectF(faceLeft, faceTop, faceRight, faceBottom),
                size * 0.16f,
                size * 0.16f,
                Path.Direction.CW,
            )
        }
        canvas.drawPath(
            facePath,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = FACE_BG },
        )

        // الشريط.
        val min = 10.0
        val max = 16.0
        fun fraction(v: Double): Float =
            ((v - min) / (max - min)).coerceIn(0.0, 1.0).toFloat()

        val left = size * 0.12f
        val right = size * 0.88f
        val top = size * 0.42f
        val barHeight = size * 0.16f
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
                size * 0.055f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = 0xFFFFFFFF.toInt() },
            )
        }

        canvas.restore()

        // علامتا الحدّين فوق الشريط.
        val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = TICK
            strokeWidth = size * 0.016f
        }
        fun tickAt(f: Float) {
            canvas.drawLine(
                left + width * f,
                top - size * 0.045f,
                left + width * f,
                top + barHeight + size * 0.045f,
                tick,
            )
        }
        tickAt(lowF)
        tickAt(highF)

        // أرقام المقياس تحت الشريط: 10 / حدّي / 16.
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = LABEL
            textSize = size * 0.085f
            textAlign = Paint.Align.LEFT
        }
        val labelY = top + barHeight + size * 0.22f

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
