package com.example.car_guard.car

import android.content.Context
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * A snapshot of the ESP8266 guard device readings, as used by the car UI.
 *
 * Fields are nullable so the UI can show "--" for values the firmware does
 * not report (the device answers either JSON or a CSV line).
 */
data class DeviceSnapshot(
    val connected: Boolean,
    val voltage: Double? = null,
    val voltageDiff: Double? = null,
    val temperatureC: Double? = null,
    val coolantOk: Boolean? = null,
    val fanRunning: Boolean? = null,
    val buzzerActive: Boolean? = null,
    val lastUpdatedMillis: Long = 0L,
) {
    companion object {
        fun disconnected() = DeviceSnapshot(connected = false)
    }
}

/**
 * Minimal HTTP client that talks directly to the ESP8266 guard device.
 *
 * The Flutter UI polls the very same endpoints (see Esp8266Repository on the
 * Dart side), so the Android Auto screen keeps working even when the phone UI
 * is not in the foreground.
 *
 * The device address is shared with the Flutter side through the file used by
 * the `shared_preferences` plugin: the Dart key `device_host` is persisted as
 * `flutter.device_host` inside the "FlutterSharedPreferences" file.
 */
class DeviceClient(private val context: Context) {

    companion object {
        private const val TAG = "CarGuardDeviceClient"
        private const val FLUTTER_PREFS_FILE = "FlutterSharedPreferences"
        private const val KEY_DEVICE_HOST = "flutter.device_host"
        private const val DEFAULT_HOST = "192.168.4.1"
        private const val CONNECT_TIMEOUT_MS = 2500
        private const val READ_TIMEOUT_MS = 2500
    }

    /** Resolves the device IP/host, falling back to the ESP8266 AP default. */
    fun deviceHost(): String {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS_FILE, Context.MODE_PRIVATE)
        val saved = prefs.getString(KEY_DEVICE_HOST, null)?.trim().orEmpty()
        return saved.ifEmpty { DEFAULT_HOST }
    }

    /** Fetches and parses `http://<host>/data`. */
    suspend fun fetchStatus(): DeviceSnapshot = withContext(Dispatchers.IO) {
        val body = httpGet("http://${deviceHost()}/data")
            ?: return@withContext DeviceSnapshot.disconnected()
        parse(body)
    }

    /** Sends the mute-alarm command (`/mute`). Returns true on HTTP 200. */
    suspend fun muteAlarm(): Boolean = withContext(Dispatchers.IO) {
        httpGet("http://${deviceHost()}/mute") != null
    }

    private fun httpGet(url: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                requestMethod = "GET"
            }
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return null
            connection.inputStream.bufferedReader().use { it.readText() }
        } catch (e: Exception) {
            Log.d(TAG, "GET $url failed: ${e.message}")
            null
        } finally {
            connection?.disconnect()
        }
    }

    /**
     * Mirrors Esp8266Repository._handleData on the Dart side: a JSON payload
     * like {"volt":12.4,"temp":87.5,"fanState":1,...} or a CSV line
     * "temp,volt,coolant,fan,buzzer[,voltDiff]".
     */
    private fun parse(raw: String): DeviceSnapshot {
        val data = raw.trim()
        return try {
            if (data.startsWith("{")) parseJson(data) else parseCsv(data)
        } catch (e: Exception) {
            Log.d(TAG, "Failed to parse device payload: ${e.message}")
            DeviceSnapshot.disconnected()
        }
    }

    private fun parseJson(data: String): DeviceSnapshot {
        val json = JSONObject(data)

        fun num(key: String): Double? =
            if (json.has(key) && !json.isNull(key)) json.optDouble(key) else null

        // The firmware flags states as 0/1 while other builds use booleans.
        fun truthy(key: String): Boolean? =
            if (json.has(key)) json.optInt(key, -1) == 1 || json.optBoolean(key, false) else null

        // The Dart side treats a payload without "volt" as unparsable too.
        val voltage = num("volt") ?: return DeviceSnapshot.disconnected()

        return DeviceSnapshot(
            connected = true,
            voltage = voltage,
            voltageDiff = num("voltDiff") ?: num("voltageDifference"),
            temperatureC = num("temp"),
            coolantOk = truthy("coolantAvailable") ?: truthy("coolant"),
            fanRunning = truthy("fanState") ?: truthy("fanRunning"),
            buzzerActive = truthy("buzzerState")
                ?: truthy("buzzerActive")
                ?: truthy("alarm")
                ?: truthy("alarmState"),
            lastUpdatedMillis = System.currentTimeMillis(),
        )
    }

    private fun parseCsv(data: String): DeviceSnapshot {
        val parts = data.split(',').map { it.trim() }
        if (parts.size < 4) return DeviceSnapshot.disconnected()

        val temperature = parts[0].toDoubleOrNull() ?: return DeviceSnapshot.disconnected()
        val voltage = parts[1].toDoubleOrNull() ?: return DeviceSnapshot.disconnected()

        return DeviceSnapshot(
            connected = true,
            voltage = voltage,
            voltageDiff = parts.getOrNull(5)?.toDoubleOrNull(),
            temperatureC = temperature,
            coolantOk = parts.getOrNull(2)?.let { it == "1" },
            fanRunning = parts.getOrNull(3)?.let { it == "1" },
            buzzerActive = parts.getOrNull(4)?.let { it == "1" },
            lastUpdatedMillis = System.currentTimeMillis(),
        )
    }
}
