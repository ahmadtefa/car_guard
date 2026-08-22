package com.example.car_guard

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import androidx.core.graphics.drawable.IconCompat
import androidx.car.app.CarAppService
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import androidx.car.app.Session
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarText
import androidx.car.app.model.ForegroundCarColorSpan
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.validation.HostValidator
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
 * The screen mirrors the mobile dashboard:
 * - a grid of cards: two neon gauges (engine temp + battery voltage) drawn
 *   the same way the Flutter app draws them, plus fan / alternator / alarm /
 *   system tiles with green-amber-red icons instead of emoji,
 * - tapping a gauge opens a full-screen HUD for that gauge (like the mobile
 *   HUD mode), tapping the other tiles opens a details screen,
 * - the header action strip carries the connection indicator and the module
 *   info screen.
 *
 * It polls the module directly over HTTP (same `/data` endpoint the Flutter
 * app uses) and reads the saved device address from the Flutter
 * SharedPreferences, so it works even when the app UI is closed.
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

/**
 * Shared poller: keeps one HTTP poll loop alive while any car screen is
 * visible and notifies all of them on every new reading, so pushed screens
 * (HUD, details) stay live too.
 */
object CarGuardEngine {

    private const val DEFAULT_HOST = "192.168.4.1"
    private const val POLL_INTERVAL_MS = 2500L

    @Volatile
    var reading: CarReading? = null
        private set

    @Volatile
    var host: String = DEFAULT_HOST
        private set

    private val handler = Handler(Looper.getMainLooper())
    private val listeners = mutableListOf<() -> Unit>()
    private var started = false

    private val poller = object : Runnable {
        override fun run() {
            Thread { fetch() }.start()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    fun bind(context: Context, listener: () -> Unit) {
        listeners.add(listener)
        start(context)
    }

    fun unbind(listener: () -> Unit) {
        listeners.remove(listener)
        if (listeners.isEmpty()) {
            stop()
        }
    }

    private fun start(context: Context) {
        host = loadHost(context)
        if (started) {
            return
        }
        started = true
        poller.run()
    }

    private fun stop() {
        started = false
        handler.removeCallbacks(poller)
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

    private fun loadHost(context: Context): String {
        return try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
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
}

/**
 * Draws the same neon dial gauges the Flutter dashboard uses: dark dial,
 * green/amber/red zone arcs, tick marks, a needle and the big value in the
 * middle.
 */
object GaugePainter {

    private const val TEMP_MIN = 40.0
    private const val TEMP_MAX = 110.0
    private const val VOLT_MIN = 10.0
    private const val VOLT_MAX = 16.0

    // Neon palette — mirrors AppColors in the Flutter app.
    private const val BG = 0xFF0F172A.toInt()
    private const val RING = 0xFF1E293B.toInt()
    private const val NEON_CYAN = 0xFF00D4FF.toInt()
    private const val NEON_GREEN = 0xFF00FF88.toInt()
    private const val NEON_AMBER = 0xFFFFAA00.toInt()
    private const val NEON_RED = 0xFFFF2244.toInt()
    private const val TEXT_DIM = 0xFF64748B.toInt()
    private const val WHITE = 0xFFF8FAFC.toInt()

    private class Zone(val from: Double, val to: Double, val color: Int)

    fun temperature(value: Double, maxTemp: Double, size: Int): Bitmap {
        val limit = maxTemp.coerceIn(TEMP_MIN + 20.0, TEMP_MAX)
        val zones = listOf(
            Zone(TEMP_MIN, limit - 10.0, NEON_GREEN),
            Zone(limit - 10.0, limit, NEON_AMBER),
            Zone(limit, TEMP_MAX, NEON_RED),
        )
        val warning = value >= limit

        return draw(
            size = size,
            min = TEMP_MIN,
            max = TEMP_MAX,
            value = value,
            zones = zones,
            tickStep = 10.0,
            mainText = String.format(Locale.US, "%.0f", value),
            unitText = "°C",
            mainColor = if (warning) NEON_RED else WHITE,
            warning = warning,
        )
    }

    fun voltage(value: Double, minVolt: Double, maxVolt: Double, size: Int): Bitmap {
        val low = minVolt.coerceIn(VOLT_MIN, VOLT_MAX - 1.0)
        val high = maxVolt.coerceIn(low + 1.0, VOLT_MAX)
        val zones = listOf(
            Zone(VOLT_MIN, low, NEON_RED),
            Zone(low, high, NEON_GREEN),
            Zone(high, VOLT_MAX, NEON_AMBER),
        )
        val warning = value != 0.0 && (value < low || value > high)

        return draw(
            size = size,
            min = VOLT_MIN,
            max = VOLT_MAX,
            value = value,
            zones = zones,
            tickStep = 1.0,
            mainText = if (value == 0.0) "--" else String.format(Locale.US, "%.1f", value),
            unitText = "V",
            mainColor = if (warning) NEON_RED else WHITE,
            warning = warning,
        )
    }

    private fun draw(
        size: Int,
        min: Double,
        max: Double,
        value: Double,
        zones: List<Zone>,
        tickStep: Double,
        mainText: String,
        unitText: String,
        mainColor: Int,
        warning: Boolean,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        val startAngle = 135f
        val sweep = 270f

        fun angleOf(v: Double): Float =
            startAngle + (sweep * ((v - min) / (max - min)).coerceIn(0.0, 1.0)).toFloat()

        // Dial background + outer ring.
        canvas.drawCircle(
            center, center, center * 0.98f,
            Paint().apply {
                isAntiAlias = true
                color = BG
                style = Paint.Style.FILL
            },
        )
        canvas.drawCircle(
            center, center, center * 0.98f,
            Paint().apply {
                isAntiAlias = true
                color = RING
                style = Paint.Style.STROKE
                strokeWidth = size * 0.015f
            },
        )

        // Zone arcs (glow pass + crisp pass) — like the segments gauge.
        val arcPaint = Paint().apply {
            isAntiAlias = true
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        val arcRadius = center * 0.40f
        val glowRadius = center * 0.47f
        val arcRect = RectF(
            center - arcRadius, center - arcRadius,
            center + arcRadius, center + arcRadius,
        )
        val glowRect = RectF(
            center - glowRadius, center - glowRadius,
            center + glowRadius, center + glowRadius,
        )

        for (zone in zones) {
            val from = angleOf(zone.from)
            val sweepAngle = angleOf(zone.to) - from

            arcPaint.color = zone.color
            arcPaint.alpha = 55
            arcPaint.strokeWidth = size * 0.13f
            canvas.drawArc(glowRect, from, sweepAngle, false, arcPaint)

            arcPaint.alpha = 255
            arcPaint.strokeWidth = size * 0.055f
            canvas.drawArc(arcRect, from, sweepAngle, false, arcPaint)
        }

        // Tick marks.
        val tickPaint = Paint().apply {
            isAntiAlias = true
            color = TEXT_DIM
            strokeWidth = size * 0.012f
            strokeCap = Paint.Cap.ROUND
        }
        var tickValue = min
        while (tickValue <= max + 0.001) {
            val angle = Math.toRadians(angleOf(tickValue).toDouble())
            val inner = center * 0.30f
            val outer = center * 0.35f
            canvas.drawLine(
                center + (inner * cos(angle)).toFloat(),
                center + (inner * sin(angle)).toFloat(),
                center + (outer * cos(angle)).toFloat(),
                center + (outer * sin(angle)).toFloat(),
                tickPaint,
            )
            tickValue += tickStep
        }

        // Needle + hub.
        val needleAngle = Math.toRadians(angleOf(value).toDouble())
        val needlePaint = Paint().apply {
            isAntiAlias = true
            color = if (warning) NEON_RED else NEON_CYAN
            strokeWidth = size * 0.022f
            strokeCap = Paint.Cap.ROUND
        }
        val needleIn = center * 0.12f
        val needleOut = center * 0.44f
        canvas.drawLine(
            center + (needleIn * cos(needleAngle)).toFloat(),
            center + (needleIn * sin(needleAngle)).toFloat(),
            center + (needleOut * cos(needleAngle)).toFloat(),
            center + (needleOut * sin(needleAngle)).toFloat(),
            needlePaint,
        )
        canvas.drawCircle(
            center, center, center * 0.055f,
            Paint().apply { isAntiAlias = true; color = WHITE },
        )
        canvas.drawCircle(
            center, center, center * 0.075f,
            Paint().apply {
                isAntiAlias = true
                color = if (warning) NEON_RED else NEON_CYAN
                style = Paint.Style.STROKE
                strokeWidth = size * 0.012f
            },
        )

        // Big value + unit in the middle.
        val mainPaint = Paint().apply {
            isAntiAlias = true
            color = mainColor
            textSize = size * 0.20f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        val unitPaint = Paint().apply {
            isAntiAlias = true
            color = if (warning) NEON_RED else NEON_CYAN
            textSize = size * 0.085f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        canvas.drawText(mainText, center, center + size * 0.12f, mainPaint)
        canvas.drawText(unitText, center, center + size * 0.24f, unitPaint)

        return bitmap
    }
}

/** Small helpers shared by the car screens. */
private fun colored(text: String, color: CarColor): CarText {
    // Car spans ride on a SpannableString; the CarText.Builder keeps
    // CarSpan instances (like ForegroundCarColorSpan) and drops others.
    val spanned = SpannableString(text)
    spanned.setSpan(
        ForegroundCarColorSpan.create(color),
        0,
        text.length,
        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
    return CarText.Builder(spanned).build()
}

/**
 * Main screen — a dashboard grid that mirrors the mobile app:
 * temp gauge, battery gauge, fan, alternator, alarm, system status.
 */
class CarGuardScreen(carContext: CarContext) : Screen(carContext) {

    private val onUpdate = { invalidate() }

    // Gauge bitmaps are redrawn only when the numbers change.
    private var tempKey: String? = null
    private var tempBitmap: Bitmap? = null
    private var voltKey: String? = null
    private var voltBitmap: Bitmap? = null

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                CarGuardEngine.bind(carContext, onUpdate)
            }

            override fun onStop(owner: LifecycleOwner) {
                CarGuardEngine.unbind(onUpdate)
            }
        })
    }

    private fun push(screen: Screen) {
        carContext.getCarService(ScreenManager::class.java).push(screen)
    }

    private fun vectorIcon(drawableId: Int, tint: CarColor?): CarIcon {
        val icon = IconCompat.createWithResource(carContext, drawableId)
        val builder = CarIcon.Builder(icon)
        if (tint != null) {
            builder.setTint(tint)
        }
        return builder.build()
    }

    private fun gaugeIcon(bitmap: Bitmap): CarIcon =
        CarIcon.Builder(IconCompat.createWithBitmap(bitmap)).build()

    private fun tile(
        title: String,
        text: String,
        icon: CarIcon,
        onClick: () -> Unit,
    ): GridItem = GridItem.Builder()
        .setTitle(title)
        .setText(text)
        .setImage(icon)
        .setOnClickListener { onClick() }
        .build()

    private fun tempGaugeIcon(reading: CarReading): CarIcon {
        val key = "${reading.temp}|${reading.maxTemp}"
        if (tempKey != key || tempBitmap == null) {
            tempBitmap = GaugePainter.temperature(reading.temp, reading.maxTemp, 320)
            tempKey = key
        }
        return gaugeIcon(tempBitmap!!)
    }

    private fun voltGaugeIcon(reading: CarReading): CarIcon {
        val key = "${reading.volt}|${reading.minVolt}|${reading.maxVolt}"
        if (voltKey != key || voltBitmap == null) {
            voltBitmap = GaugePainter.voltage(reading.volt, reading.minVolt, reading.maxVolt, 320)
            voltKey = key
        }
        return gaugeIcon(voltBitmap!!)
    }

    override fun onGetTemplate(): Template {
        val current = CarGuardEngine.reading

        return when {
            current == null -> connectingTemplate()
            !current.connected -> disconnectedTemplate()
            else -> dashboardTemplate(current)
        }
    }

    private fun connectingTemplate(): Template =
        ListTemplate.Builder()
            .setTitle("Car Guard")
            .setLoading(true)
            .build()

    private fun disconnectedTemplate(): Template =
        ListTemplate.Builder()
            .setTitle("Car Guard")
            .setSingleList(
                ItemList.Builder()
                    .addItem(
                        Row.Builder()
                            .setTitle("الحالة")
                            .addText(colored("غير متصل", CarColor.RED))
                            .setImage(vectorIcon(R.drawable.ic_wifi, CarColor.RED))
                            .build(),
                    )
                    .addItem(
                        Row.Builder()
                            .setTitle("العنوان")
                            .addText(CarGuardEngine.host)
                            .build(),
                    )
                    .addItem(
                        Row.Builder()
                            .setTitle("نصيحة")
                            .addText("اتصل بنفس واي فاي الوحدة (CarGuard) ثم افتح التطبيق مرة واحدة")
                            .build(),
                    )
                    .build(),
            )
            .build()

    private fun dashboardTemplate(reading: CarReading): Template {
        val tempCritical = reading.temp >= reading.maxTemp
        val voltBad = reading.volt != 0.0 &&
            (reading.volt < reading.minVolt || reading.volt > reading.maxVolt)
        val charging = reading.volt >= 13.0
        val systemWarning = tempCritical || voltBad || reading.alarm

        val tempTitle = String.format(Locale.US, "%.1f °C", reading.temp)
        val voltTitle =
            if (reading.volt == 0.0) "-- V"
            else String.format(Locale.US, "%.2f V", reading.volt)

        val grid = ItemList.Builder()

            // The two gauges, exactly like the top of the mobile dashboard.
            .addItem(
                tile(tempTitle, "حرارة المحرك", tempGaugeIcon(reading)) {
                    push(GaugeHudScreen(carContext, GaugeHudScreen.KIND_TEMP))
                },
            )
            .addItem(
                tile(voltTitle, "جهد البطارية", voltGaugeIcon(reading)) {
                    push(GaugeHudScreen(carContext, GaugeHudScreen.KIND_VOLT))
                },
            )

            // Compact status row — fan.
            .addItem(
                tile(
                    if (reading.fanOn) "تعمل" else "متوقفة",
                    "المروحة",
                    vectorIcon(
                        R.drawable.ic_fan,
                        if (reading.fanOn) CarColor.GREEN else CarColor.YELLOW,
                    ),
                ) {
                    push(DetailsScreen(carContext))
                },
            )

            // Compact status row — alternator.
            .addItem(
                tile(
                    if (charging) "يشحن" else "لا يشحن",
                    "الدينامو",
                    vectorIcon(
                        R.drawable.ic_bolt,
                        if (charging) CarColor.GREEN else CarColor.DEFAULT,
                    ),
                ) {
                    push(DetailsScreen(carContext))
                },
            )

            // Alarm state.
            .addItem(
                tile(
                    when {
                        reading.alarm -> "شغّال"
                        reading.muted -> "مكتوم"
                        else -> "هادئ"
                    },
                    "الإنذار",
                    vectorIcon(
                        R.drawable.ic_bell,
                        when {
                            reading.alarm -> CarColor.RED
                            reading.muted -> CarColor.YELLOW
                            else -> CarColor.GREEN
                        },
                    ),
                ) {
                    push(DetailsScreen(carContext))
                },
            )

            // System status card.
            .addItem(
                tile(
                    if (systemWarning) "تحذير" else "النظام يعمل",
                    "النظام",
                    vectorIcon(
                        if (systemWarning) R.drawable.ic_warning else R.drawable.ic_check,
                        if (systemWarning) CarColor.RED else CarColor.GREEN,
                    ),
                ) {
                    push(DetailsScreen(carContext))
                },
            )
            .build()

        return GridTemplate.Builder()
            .setTitle("Car Guard • متصل")
            .setActionStrip(
                ActionStrip.Builder()
                    .addAction(
                        Action.Builder()
                            .setIcon(
                                vectorIcon(R.drawable.ic_wifi, CarColor.GREEN),
                            )
                            .setOnClickListener {
                                push(ConnectionScreen(carContext))
                            }
                            .build(),
                    )
                    .addAction(
                        Action.Builder()
                            .setIcon(vectorIcon(R.drawable.ic_settings, null))
                            .setOnClickListener {
                                push(ModuleInfoScreen(carContext))
                            }
                            .build(),
                    )
                    .build(),
            )
            .setSingleList(grid)
            .build()
    }
}

/**
 * Full-screen HUD for one gauge — the same big neon dial as the mobile
 * HUD mode, with the limit shown underneath. Stays live while visible.
 */
class GaugeHudScreen(carContext: CarContext, private val kind: String) : Screen(carContext) {

    private val onUpdate = { invalidate() }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                CarGuardEngine.bind(carContext, onUpdate)
            }

            override fun onStop(owner: LifecycleOwner) {
                CarGuardEngine.unbind(onUpdate)
            }
        })
    }

    override fun onGetTemplate(): Template {
        val reading = CarGuardEngine.reading

        // The gauge image lives on the Pane (single-arg setImage, CarApi 4+);
        // hosts below that level simply show the numbers without the dial.
        val showImage = carContext.carAppApiLevel >= 4

        val title: String
        val pane: Pane

        if (reading == null || !reading.connected) {
            title = "غير متصل"
            pane = Pane.Builder()
                .addText("مش قادرين نوصل للوحدة دلوقتي")
                .build()
        } else if (kind == KIND_TEMP) {
            val warning = reading.temp >= reading.maxTemp
            title = String.format(Locale.US, "%.1f °C", reading.temp)
            val builder = Pane.Builder()
                .addText(
                    String.format(
                        Locale.US,
                        "الحد الأقصى %.0f °C — %s",
                        reading.maxTemp,
                        if (warning) "حرارة حرجة" else "حرارة طبيعية",
                    ),
                )
            if (showImage) {
                builder.setImage(
                    gaugeIcon(
                        GaugePainter.temperature(reading.temp, reading.maxTemp, 640),
                    ),
                )
            }
            pane = builder.build()
        } else {
            val warning = reading.volt != 0.0 &&
                (reading.volt < reading.minVolt || reading.volt > reading.maxVolt)
            title = String.format(Locale.US, "%.2f V", reading.volt)
            val builder = Pane.Builder()
                .addText(
                    String.format(
                        Locale.US,
                        "المدى %.1f – %.1f V — %s",
                        reading.minVolt,
                        reading.maxVolt,
                        if (reading.volt >= 13.0) "الدينامو يشحن" else "لا يوجد شحن",
                    ),
                )
            if (showImage) {
                builder.setImage(
                    gaugeIcon(
                        GaugePainter.voltage(
                            reading.volt,
                            reading.minVolt,
                            reading.maxVolt,
                            640,
                        ),
                    ),
                )
            }
            pane = builder.build()
        }

        return PaneTemplate.Builder(pane)
            .setTitle(title)
            .setHeaderAction(Action.BACK)
            .build()
    }

    companion object {
        const val KIND_TEMP = "temp"
        const val KIND_VOLT = "volt"
    }
}

/** Numbers + limits breakdown — the car version of the app's data sheet. */
class DetailsScreen(carContext: CarContext) : Screen(carContext) {

    private fun row(label: String, value: String, color: CarColor? = null): Row {
        val builder = Row.Builder().setTitle(label)
        if (color == null) {
            builder.addText(value)
        } else {
            builder.addText(colored(value, color))
        }
        return builder.build()
    }

    /** Section divider rendered as a plain title-only row. */
    private fun header(text: String): Row =
        Row.Builder().setTitle(text).build()

    override fun onGetTemplate(): Template {
        val reading = CarGuardEngine.reading
        val builder = ListTemplate.Builder()
            .setTitle("التفاصيل")
            .setHeaderAction(Action.BACK)

        if (reading == null || !reading.connected) {
            return builder
                .setSingleList(
                    ItemList.Builder()
                        .addItem(
                            Row.Builder()
                                .setTitle("غير متصل")
                                .addText("ارجع للشاشة الرئيسية وراقب حالة الاتصال")
                                .build(),
                        )
                        .build(),
                )
                .build()
        }

        val tempCritical = reading.temp >= reading.maxTemp
        val voltBad = reading.volt != 0.0 &&
            (reading.volt < reading.minVolt || reading.volt > reading.maxVolt)

        return builder
            .setSingleList(
                ItemList.Builder()
                    .addItem(header("الحرارة"))
                    .addItem(
                        row(
                            "القيمة",
                            String.format(Locale.US, "%.1f °C", reading.temp),
                            if (tempCritical) CarColor.RED else CarColor.GREEN,
                        ),
                    )
                    .addItem(
                        row(
                            "الحد الأقصى",
                            String.format(Locale.US, "%.0f °C", reading.maxTemp),
                        ),
                    )
                    .addItem(
                        row(
                            "الحالة",
                            if (tempCritical) "حرجة" else "طبيعي",
                            if (tempCritical) CarColor.RED else CarColor.GREEN,
                        ),
                    )
                    .addItem(header("البطارية"))
                    .addItem(
                        row(
                            "القيمة",
                            String.format(Locale.US, "%.2f V", reading.volt),
                            if (voltBad) CarColor.RED else CarColor.GREEN,
                        ),
                    )
                    .addItem(
                        row(
                            "المدى المسموح",
                            String.format(
                                Locale.US,
                                "%.1f – %.1f V",
                                reading.minVolt,
                                reading.maxVolt,
                            ),
                        ),
                    )
                    .addItem(
                        row(
                            "الدينامو",
                            if (reading.volt >= 13.0) "يشحن" else "لا يشحن",
                            if (reading.volt >= 13.0) CarColor.GREEN else CarColor.DEFAULT,
                        ),
                    )
                    .addItem(header("المروحة والإنذار"))
                    .addItem(
                        row(
                            "المروحة",
                            if (reading.fanOn) "تعمل" else "متوقفة",
                            if (reading.fanOn) CarColor.GREEN else CarColor.DEFAULT,
                        ),
                    )
                    .addItem(
                        row(
                            "الإنذار",
                            when {
                                reading.alarm -> "شغّال"
                                reading.muted -> "مكتوم"
                                else -> "هادئ"
                            },
                            when {
                                reading.alarm -> CarColor.RED
                                reading.muted -> CarColor.YELLOW
                                else -> CarColor.GREEN
                            },
                        ),
                    )
                    .build(),
            )
            .build()
    }
}

/** Connection state + host + tips (opened from the wifi action). */
class ConnectionScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val connected = CarGuardEngine.reading?.connected == true

        return ListTemplate.Builder()
            .setTitle("الاتصال")
            .setHeaderAction(Action.BACK)
            .setSingleList(
                ItemList.Builder()
                    .addItem(
                        Row.Builder()
                            .setTitle("الحالة")
                            .addText(
                                colored(
                                    if (connected) "متصل" else "غير متصل",
                                    if (connected) CarColor.GREEN else CarColor.RED,
                                ),
                            )
                            .setImage(
                                vectorIcon(
                                    R.drawable.ic_wifi,
                                    if (connected) CarColor.GREEN else CarColor.RED,
                                ),
                            )
                            .build(),
                    )
                    .addItem(
                        Row.Builder()
                            .setTitle("العنوان")
                            .addText(CarGuardEngine.host)
                            .build(),
                    )
                    .addItem(
                        Row.Builder()
                            .setTitle("ملحوظة")
                            .addText("شاشة العربية بتقرأ من الوحدة مباشرة حتى لو التطبيق مقفول")
                            .build(),
                    )
                    .addItem(
                        Row.Builder()
                            .setTitle("نصيحة")
                            .addText("لو العنوان غلط: افتح التطبيق على الموبايل ووصّل مرة واحدة")
                            .build(),
                    )
                    .build(),
            )
            .build()
    }
}

/** Module limits + calibration — mirrors the app's module info sheet. */
class ModuleInfoScreen(carContext: CarContext) : Screen(carContext) {

    private data class ModuleSettings(
        val maxTemp: Double?,
        val fanOnTemp: Double?,
        val minVolt: Double?,
        val maxVolt: Double?,
        val offset: Double?,
    )

    private var settings: ModuleSettings? = null
    private var loading = true

    private val handler = Handler(Looper.getMainLooper())

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                loading = true
                settings = null
                Thread { fetch() }.start()
            }
        })
    }

    private fun fetch() {
        val fetched: ModuleSettings? = try {
            val connection = URL("http://${CarGuardEngine.host}/getallsettings")
                .openConnection() as HttpURLConnection

            connection.connectTimeout = 4000
            connection.readTimeout = 4000

            val body = connection.inputStream.bufferedReader().readText()
            connection.disconnect()

            val json = JSONObject(body)
            ModuleSettings(
                maxTemp = if (json.has("maxTemp")) json.optDouble("maxTemp") else null,
                fanOnTemp = if (json.has("fanOnTemp")) json.optDouble("fanOnTemp") else null,
                minVolt = if (json.has("minVolt")) json.optDouble("minVolt") else null,
                maxVolt = if (json.has("maxVolt")) json.optDouble("maxVolt") else null,
                offset = if (json.has("offset")) json.optDouble("offset") else null,
            )
        } catch (exception: Exception) {
            null
        }

        handler.post {
            settings = fetched
            loading = false
            invalidate()
        }
    }

    private fun retry() {
        loading = true
        invalidate()
        Thread { fetch() }.start()
    }

    private fun valueRow(label: String, value: Double?, suffix: String, decimals: Int): Row {
        val text = if (value == null) {
            "--"
        } else {
            String.format(Locale.US, "%." + decimals + "f " + suffix, value)
        }
        return Row.Builder().setTitle(label).addText(text).build()
    }

    override fun onGetTemplate(): Template {
        val builder = ListTemplate.Builder()
            .setTitle("بيانات الوحدة")
            .setHeaderAction(Action.BACK)

        if (loading) {
            return builder
                .setLoading(true)
                .build()
        }

        val current = settings
        if (current == null) {
            return builder
                .setSingleList(
                    ItemList.Builder()
                        .addItem(
                            Row.Builder()
                                .setTitle("مش قادرين نقرأ إعدادات الوحدة")
                                .addText("تأكد إن الموبايل على شبكة الوحدة")
                                .setOnClickListener { retry() }
                                .build(),
                        )
                        .build(),
                )
                .build()
        }

        return builder
            .setSingleList(
                ItemList.Builder()
                    .addItem(
                        Row.Builder()
                            .setTitle("العنوان")
                            .addText(CarGuardEngine.host)
                            .build(),
                    )
                    .addItem(valueRow("الحد الأقصى للحرارة", current.maxTemp, "°C", 0))
                    .addItem(valueRow("حرارة تشغيل المروحة", current.fanOnTemp, "°C", 0))
                    .addItem(valueRow("أدنى جهد للبطارية", current.minVolt, "V", 1))
                    .addItem(valueRow("أقصى جهد للبطارية", current.maxVolt, "V", 1))
                    .addItem(valueRow("المعايرة", current.offset, "", 1))
                    .build(),
            )
            .build()
    }
}
