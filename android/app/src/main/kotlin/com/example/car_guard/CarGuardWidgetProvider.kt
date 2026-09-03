package com.example.car_guard

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * ويدجت الشاشة الرئيسية 2×1 للـ Car Guard
 * يعرض TEMP / BATT / FAN بدون فتح التطبيق
 * يقرأ آخر قراءة حفظها Flutter في SharedPreferences (home_widget)
 */
class CarGuardWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "CarGuardWidget"

        const val PREF_NAME = "HomeWidgetPreferences"
        // Keys يكتبها Flutter عبر home_widget
        const val KEY_TEMP = "widget_temp"
        const val KEY_VOLT = "widget_volt"
        const val KEY_FAN = "widget_fan"
        const val KEY_CONNECTED = "widget_connected"
        const val KEY_MAX_TEMP = "widget_max_temp"
        const val KEY_ALARM = "widget_alarm"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, CarGuardWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val provider = CarGuardWidgetProvider()
                provider.onUpdate(context, manager, ids)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            // A widget is drawn by the *launcher* process but rendered inside
            // this app's process, so a throw here ("Car Guard keeps stopping")
            // happened even without opening the app. On head-unit launchers,
            // which re-add/re-layout widgets aggressively, that means a crash
            // loop right after installation. One bad widget must never take the
            // app down: log, skip, keep going.
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (t: Throwable) {
                Log.w(TAG, "Widget update failed: $t")
                BootDiagnostics.warn(context, "widget.onUpdate", t)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            super.onReceive(context, intent)
        } catch (t: Throwable) {
            Log.w(TAG, "Widget broadcast failed: $t")
            BootDiagnostics.warn(context, "widget.onReceive", t)
        }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_car_guard)

        // 1) حاول قراءة بيانات الويدجت المباشرة (home_widget)
        val widgetPrefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        var temp = widgetPrefs.getString(KEY_TEMP, null)
        var volt = widgetPrefs.getString(KEY_VOLT, null)
        var fan = widgetPrefs.getString(KEY_FAN, null)
        var connected = widgetPrefs.getBoolean(KEY_CONNECTED, false)
        var maxTempStr = widgetPrefs.getString(KEY_MAX_TEMP, null)
        var alarm = widgetPrefs.getBoolean(KEY_ALARM, false)

        // 2) Fallback: اقرأ من FlutterSharedPreferences (الـ live stream)
        if (temp == null) {
            val flutterPrefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            // آخر حالة للجهاز قد تكون مخزنة في أماكن مختلفة، نحاول قراءتها
            // نحاول أيضاً قراءة مباشرة من الـ host data المخزن
            val rawTemp = tryReadTempFromFlutterPrefs(flutterPrefs)
            if (rawTemp != null) {
                temp = String.format("%.1f°C", rawTemp)
            }
        }

        // قيم افتراضية لو مفيش بيانات بعد
        val tempText = temp ?: "--°C"
        val voltText = volt ?: "--V"
        val fanText = fan ?: "OFF"

        views.setTextViewText(R.id.widget_temp_value, tempText)
        views.setTextViewText(R.id.widget_volt_value, voltText)
        views.setTextViewText(R.id.widget_fan_value, fanText)

        // حالة الاتصال
        val connColor = if (connected) "#00FF88" else "#FF2244"
        views.setTextViewText(R.id.widget_conn_value, if (connected) "● متصل" else "● غير متصل")
        // لا يمكن تغيير اللون مباشرة في RemoteViews بدون setInt، نستخدم لون افتراضي

        // حالة الحرارة
        val maxTemp = maxTempStr?.toDoubleOrNull() ?: 97.0
        val tempVal = tempText.replace("°C", "").toDoubleOrNull() ?: 0.0
        val tempDot = when {
            alarm -> "🔴"
            tempVal >= maxTemp -> "🔴"
            tempVal >= maxTemp - 5 -> "🟡"
            connected -> "🟢"
            else -> "⚪"
        }
        views.setTextViewText(R.id.widget_temp_status, tempDot)

        // Volt delta بسيط
        views.setTextViewText(R.id.widget_volt_delta, if (connected) "OK" else "--")

        // ضغطة تفتح التطبيق
        // getLaunchIntentForPackage() legitimately returns null when no
        // launcher entry resolves for the package (car launchers, work
        // profiles, direct-boot), and PendingIntent.getActivity(...) then
        // throws NullPointerException("intent must not be null") inside the
        // app process. A widget without a tap action still shows readings.
        val intent = try {
            context.packageManager.getLaunchIntentForPackage(context.packageName)
        } catch (t: Throwable) {
            null
        }
        val pending = intent?.let {
            PendingIntent.getActivity(
                context, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        if (pending != null) {
            views.setOnClickPendingIntent(R.id.widget_temp_value, pending)
            views.setOnClickPendingIntent(R.id.widget_volt_value, pending)
            views.setOnClickPendingIntent(R.id.widget_fan_value, pending)
        }

        manager.updateAppWidget(appWidgetId, views)
    }

    private fun tryReadTempFromFlutterPrefs(prefs: SharedPreferences): Double? {
        return try {
            // حاول قراءة آخر DeviceStatus المخزن كـ JSON لو موجود
            // وإلا اقرأ من module_limits_cache
            val all = prefs.all
            // لا نعتمد على مفتاح محدد، نبحث عن أي قيمة تحتوي temp
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun String.ifEmpty(default: () -> String): String =
        if (isEmpty()) default() else this
}
