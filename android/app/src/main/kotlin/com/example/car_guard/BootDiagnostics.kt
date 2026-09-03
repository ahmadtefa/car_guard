package com.example.car_guard

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * TEMPORARY startup instrumentation (car-screen crash hunting).
 *
 * Why this exists
 * -------------
 * The app starts fine on phones but dies with the system "Car Guard keeps
 * stopping" dialog on the car head unit. Almost every fatal startup path in
 * this project is on the *Android* side (foreground service, Android Auto
 * template service, Wi-Fi locks, the Flutter renderer), and a crash in any of
 * them kills the whole process — Dart never gets a chance to report anything.
 *
 * What it does
 * ------------
 *  1. Writes a numbered stage marker before/after every risky startup step, so
 *     the LAST marker seen tells which step the process died in.
 *  2. Chains a default uncaught-exception handler that stores the full stack
 *     trace of the crash, then hands the exception to the original handler so
 *     the system behaviour (dialog, restart) is completely unchanged.
 *  3. Persists both in the app's own SharedPreferences, so the previous crash
 *     can be shown *inside the app* on the next launch — no adb required,
 *     which matters because a car head unit usually has none.
 *
 * Everything here is deliberately defensive: a diagnostic facility that can
 * itself throw would be worse than no diagnostics at all, so every entry point
 * swallows Throwable.
 *
 * Remove this file (plus the `BootDiagnostics.*` call sites, the
 * `car_guard/boot` channel and `lib/core/services/boot_diagnostics.dart`)
 * once the head-unit crash is confirmed fixed.
 */
object BootDiagnostics {

    private const val TAG = "CarGuardBoot"

    /** The file `shared_preferences` uses, so Dart and the car UI can read it. */
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_TRACE = "flutter.boot_trace"
    private const val KEY_CRASH = "flutter.last_crash"

    private const val MAX_LINES = 40
    private const val MAX_CRASH_CHARS = 6000

    @Volatile
    private var handlerInstalled = false

    /** One boot session, so stages from the previous run can't be mixed in. */
    private val sessionId = System.currentTimeMillis()

    private val lines = ArrayList<String>(MAX_LINES)

    /**
     * Installs the crash recorder and starts a new trace. Called from
     * `MainActivity.onCreate()` — i.e. as early as an app process can be.
     */
    fun install(context: Context) {
        // The handler outlives the activity, so only the application context
        // may be captured here — an Activity reference would leak it.
        val appContext = context.applicationContext

        stage(appContext, "install")
        if (handlerInstalled) {
            return
        }
        handlerInstalled = true

        val previous = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            // Record first, then let the platform do exactly what it did
            // before (log, show the dialog, kill the process).
            runCatching {
                recordCrash(appContext, thread, throwable)
            }
            runCatching {
                previous?.uncaughtException(thread, throwable)
            }
        }
    }

    /**
     * Appends a stage marker. The last marker written before a hard process
     * death names the step that killed the app.
     */
    fun stage(context: Context?, name: String) {
        if (context == null) {
            Log.i(TAG, "stage=$name")
            return
        }
        append(context, "stage=$name")
    }

    /** Low grade marker for non-fatal but suspicious failures. */
    fun warn(context: Context?, name: String, detail: Any? = null) {
        val text = if (detail == null) name else "$name :: $detail"
        Log.w(TAG, text)
        append(context, "warn=$text")
    }

    /**
     * Returns `trace` (stages of the current boot) and `crash` (the uncaught
     * exception of the *previous* run, cleared on read so it is reported once),
     * for the Dart side to surface on the car screen.
     */
    fun drain(context: Context?): Map<String, Any?> {
        val prefs = prefs(context) ?: return emptyMap()

        val crash = runCatching { prefs.getString(KEY_CRASH, null) }.getOrNull()
        val trace = runCatching { prefs.getString(KEY_TRACE, null) }.getOrNull()

        if (crash != null) {
            runCatching { prefs.edit().remove(KEY_CRASH).commit() }
        }

        return mapOf(
            "trace" to (trace ?: ""),
            "crash" to (crash ?: ""),
            "hasCrash" to (crash != null),
            "device" to deviceSummary(),
        )
    }

    /** Frees the recorded crash when the user dismissed the report. */
    fun clearCrash(context: Context?) {
        prefs(context)?.let { p ->
            runCatching { p.edit().remove(KEY_CRASH).commit() }
        }
    }

    // ------------------------------------------------------------------------
    // internals
    // ------------------------------------------------------------------------

    private fun append(context: Context?, message: String) {
        // SimpleDateFormat is not thread-safe and stages arrive from the UI
        // thread, a service and the crash handler — build one per entry.
        val stamp = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val entry = "$stamp [session=$sessionId] $message"
        Log.i(TAG, entry)

        if (context == null) {
            // No context (a service that died before attach, or the car
            // session before the host handed one over): logcat only.
            return
        }

        synchronized(lines) {
            lines.add(entry)
            while (lines.size > MAX_LINES) {
                lines.removeAt(0)
            }
        }

        val prefs = prefs(context) ?: return
        // commit(): a crash can kill the process before apply() would flush.
        runCatching {
            prefs.edit().putString(KEY_TRACE, lines.joinToString("\n")).commit()
        }
    }

    private fun recordCrash(context: Context?, thread: Thread, throwable: Throwable) {
        val builder = StringBuilder()
        builder.append("FATAL in thread '").append(thread.name).append("'\n")
        var current: Throwable? = throwable
        var depth = 0
        while (current != null && depth < 6) {
            builder.append(current.javaClass.name).append(": ").append(current.message).append('\n')
            current.stackTrace.take(28).forEach { frame ->
                builder.append("    at ").append(frame).append('\n')
            }
            current = current.cause
            depth++
        }
        if (builder.length > MAX_CRASH_CHARS) {
            builder.setLength(MAX_CRASH_CHARS)
        }

        append(context, "CRASH=${throwable.javaClass.simpleName}")

        prefs(context)?.let { p ->
            runCatching { p.edit().putString(KEY_CRASH, builder.toString()).commit() }
        }
    }

    private fun prefs(context: Context?): SharedPreferences? = try {
        context
            ?.applicationContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    } catch (t: Throwable) {
        null
    }

    private fun deviceSummary(): String =
        "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}), " +
            "${Build.MANUFACTURER} ${Build.MODEL}, " +
            "abis=${Build.SUPPORTED_ABIS?.joinToString() ?: "?"}"
}
