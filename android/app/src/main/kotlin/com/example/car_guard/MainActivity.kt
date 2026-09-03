package com.example.car_guard

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** Active callback while the app-scoped module Wi-Fi pairing lives. */
    private var moduleWifiPairing: ConnectivityManager.NetworkCallback? = null

    /**
     * TEMP(car-crash): earliest possible hook — installs the stage log and the
     * uncaught-exception recorder before the Flutter engine, the plugins and the
     * foreground service exist. Remove together with BootDiagnostics.
     */
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        BootDiagnostics.install(this)
        BootDiagnostics.stage(this, "activity.onCreate")
        try {
            super.onCreate(savedInstanceState)
        } catch (t: Throwable) {
            // A crash here (engine/GPU/ABI related) is exactly what the head
            // unit hits; record the stage + trace, then rethrow unchanged.
            BootDiagnostics.warn(this, "activity.onCreate failed", t)
            throw t
        }
    }

    /**
     * mDNS multicast lock. Several Android vendors silently drop multicast
     * traffic until an app holds it — without this, car_guard.local lookups
     * hang and fail. Held for the process lifetime (foreground app); the
     * Kotlin runtime throws on duplicate acquire, so we guard with a flag.
     */
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        BootDiagnostics.stage(this, "engine.configured")

        acquireMulticastLock()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NETWORK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            // Every handler body runs on the Android main thread: an exception
            // escaping from here is NOT delivered to Dart, it kills the whole
            // process (the "Car Guard keeps stopping" dialog). Dispatch through
            // reply() so any failure comes back as a Dart PlatformException
            // instead — the Dart side already handles those.
            reply(result) {
                when (call.method) {
                    "bindToWifi" -> bindProcessToWifi()
                    "bindToDefault" -> unbindProcess()
                    "androidSdkInt" -> Build.VERSION.SDK_INT
                    "pairModuleWifi" -> {
                        val ssid = call.argument<String>("ssid").orEmpty()
                        val password = call.argument<String>("password").orEmpty()
                        pairModuleWifi(ssid, password)
                    }
                    "unpairModuleWifi" -> unpairModuleWifi()
                    "suggestModuleWifi" -> {
                        val ssid = call.argument<String>("ssid").orEmpty()
                        val password = call.argument<String>("password").orEmpty()
                        suggestModuleWifi(ssid, password)
                    }
                    "removeModuleWifiSuggestion" -> {
                        val ssid = call.argument<String>("ssid").orEmpty()
                        val password = call.argument<String>("password").orEmpty()
                        removeModuleWifiSuggestion(ssid, password)
                    }
                    "openInternetSettings" -> openInternetSettings()
                    else -> {
                        result.notImplemented()
                        null
                    }
                }
            }
        }

        // Keep-alive foreground service channel: the Dart side promotes the
        // process to a foreground service while the device connection and/or
        // the GPS trip tracking need to keep running in the background.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_CHANNEL,
        ).setMethodCallHandler { call, result ->
            reply(result) {
                when (call.method) {
                    "start" -> CarGuardForegroundService.start(this)
                    "stop" -> CarGuardForegroundService.stop(this)
                    else -> {
                        result.notImplemented()
                        null
                    }
                }
            }
        }

        // TEMP(car-crash): startup stage trace + last crash, read by the Dart
        // side so the failing step is visible on the head unit itself.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BOOT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            reply(result) {
                when (call.method) {
                    "stage" -> {
                        BootDiagnostics.stage(
                            this,
                            call.argument<String>("name").orEmpty(),
                        )
                        null
                    }
                    "drain" -> BootDiagnostics.drain(this)
                    "clearCrash" -> {
                        BootDiagnostics.clearCrash(this)
                        null
                    }
                    else -> {
                        result.notImplemented()
                        null
                    }
                }
            }
        }

        BootDiagnostics.stage(this, "channels.ready")
    }

    /** Runs [block] and replies on [result]; never lets a throw reach the UI thread. */
    private inline fun reply(result: MethodChannel.Result, block: () -> Any?) {
        try {
            val value = block()
            // Unit is not encodable by the standard message codec, and Dart
            // handlers expect `null` for "no value".
            result.success(if (value is Unit) null else value)
        } catch (t: Throwable) {
            BootDiagnostics.warn(this, "channel call failed", t)
            try {
                result.error(
                    "car_guard_native_error",
                    "${t.javaClass.simpleName}: ${t.message}",
                    null,
                )
            } catch (ignored: Throwable) {
                // The reply was already submitted — nothing left to report.
            }
        }
    }

    /**
     * Pins this process' sockets (Dart HttpClient/WebSocket included) to the
     * Wi-Fi network — i.e. the Car Guard module access point. The rest of the
     * phone keeps using mobile data (4G) for internet once Android marks the
     * module Wi-Fi as "no internet".
     *
     * Returns true when a Wi-Fi network was found and bound.
     */
    private fun bindProcessToWifi(): Boolean {
        val manager = connectivityManager() ?: return false

        for (network in manager.allNetworks) {
            val capabilities = manager.getNetworkCapabilities(network) ?: continue

            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                return manager.bindProcessToNetwork(network)
            }
        }

        return false
    }

    /** Releases the Wi-Fi binding; the app follows the system network again. */
    private fun unbindProcess(): Boolean {
        val manager = connectivityManager() ?: return false
        return manager.bindProcessToNetwork(null)
    }

    /**
     * `getSystemService` answers null on builds where the service is not
     * published, and a bare `as ConnectivityManager` cast on null throws a
     * NullPointerException on the main thread — fatal for the whole process
     * when it happens inside a platform-channel handler. Every access here goes
     * through this nullable helper instead.
     */
    private fun connectivityManager(): ConnectivityManager? = try {
        getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
    } catch (t: Throwable) {
        BootDiagnostics.warn(this, "ConnectivityManager unavailable", t)
        null
    }

    /** Nullable Wi-Fi manager: many automotive/Wi-Fi-less head units have no
     *  Wi-Fi service at all, and the previous hard cast crashed on them. */
    private fun wifiManager(): WifiManager? = try {
        applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
    } catch (t: Throwable) {
        BootDiagnostics.warn(this, "WifiManager unavailable", t)
        null
    }

    /**
     * Direct, APP-SCOPED connection to the module access point
     * (WifiNetworkSpecifier, Android 10+).
     *
     * The request explicitly removes the INTERNET capability so Android never
     * treats the module Wi-Fi as the phone's internet network: the system
     * default route stays on 4G, other apps never lose connectivity, and no
     * "network has no internet" dance is needed. The system shows its one-tap
     * pairing sheet on the first request.
     */
    private fun pairModuleWifi(ssid: String, password: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || ssid.isEmpty()) {
            return false
        }

        val manager = connectivityManager() ?: return false

        val specifier = WifiNetworkSpecifier.Builder().apply {
            setSsid(ssid)
            if (password.isNotEmpty()) {
                setWpa2Passphrase(password)
            }
        }.build()

        // removeCapability(INTERNET) is the crucial bit — it promises the
        // system this link is a device link, not the phone's internet.
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        moduleWifiPairing?.let {
            runCatching { manager.unregisterNetworkCallback(it) }
        }

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                manager.bindProcessToNetwork(network)
            }

            override fun onLost(network: Network) {
                if (moduleWifiPairing === this) {
                    manager.bindProcessToNetwork(null)
                }
            }
        }

        moduleWifiPairing = callback

        return try {
            manager.requestNetwork(request, callback, PAIRING_TIMEOUT_MS)
            true
        } catch (e: SecurityException) {
            // NEARBY_WIFI_DEVICES (Android 13+) / fine location (older) missing.
            false
        } catch (e: RuntimeException) {
            false
        }
    }

    /**
     * Builds a system-level Wi-Fi suggestion for the module access point
     * (Android 10+). Uses WPA2 when a passphrase is provided, otherwise an
     * open network scheme.
     */
    private fun buildWifiSuggestion(
        ssid: String,
        password: String,
    ): WifiNetworkSuggestion? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || ssid.isEmpty()) {
            return null
        }

        return WifiNetworkSuggestion.Builder().apply {
            setSsid(ssid)
            if (password.isNotEmpty()) {
                setWpa2Passphrase(password)
            }
            // default: the system may auto-connect without any app
            // interaction (setIsAppInteractionRequired(false)).
        }.build()
    }

    /**
     * SYSTEM-LEVEL auto-join for the module network (WifiNetworkSuggestion).
     *
     * Unlike [pairModuleWifi] — a temporary app-scoped link — this registers
     * the module AP with Android itself: after the user approves the
     * one-time system prompt, the phone joins the module Wi-Fi automatically
     * whenever it is in range, like any other saved network, and the
     * registration survives reboots. Adding the same suggestion again simply
     * updates it, so re-registering on app start is cheap and idempotent.
     */
    private fun suggestModuleWifi(ssid: String, password: String): Boolean {
        val suggestion = buildWifiSuggestion(ssid, password) ?: return false

        // A head unit without Wi-Fi simply has no WifiManager — report
        // "not applied" instead of crashing (see wifiManager()).
        val wifiManager = wifiManager() ?: return false

        return try {
            wifiManager.addNetworkSuggestions(listOf(suggestion)) ==
                WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS
        } catch (e: Exception) {
            // Some OEM builds reject/queue suggestions — the Dart side turns
            // that into a snack instead of a crash.
            false
        }
    }

    /** Removes the auto-join registration (matched by suggestion content). */
    private fun removeModuleWifiSuggestion(ssid: String, password: String): Boolean {
        val suggestion = buildWifiSuggestion(ssid, password) ?: return false

        val wifiManager = wifiManager() ?: return false

        return try {
            wifiManager.removeNetworkSuggestions(listOf(suggestion)) ==
                WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS
        } catch (e: Exception) {
            false
        }
    }

    /** Drops the app-scoped pairing and releases the binding. */
    private fun unpairModuleWifi(): Boolean {
        val manager = connectivityManager()

        moduleWifiPairing?.let {
            runCatching { manager?.unregisterNetworkCallback(it) }
        }
        moduleWifiPairing = null

        return manager?.bindProcessToNetwork(null) ?: true
    }

    /**
     * Opens the system internet connectivity panel (the same sheet that hosts
     * the "keep Wi-Fi without internet" choice), so guidance users land on
     * the right toggle with one tap.
     */
    private fun openInternetSettings(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startActivity(Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY))
            } else {
                startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Holds the mDNS multicast lock for the process while the app is up. */
    private fun acquireMulticastLock() {
        if (multicastLock != null) return

        try {
            val wifiManager = wifiManager() ?: return

            multicastLock = wifiManager.createMulticastLock("car_guard_mdns").apply {
                setReferenceCounted(false)
                acquire()
            }
            BootDiagnostics.stage(this, "multicastLock.acquired")
        } catch (t: Throwable) {
            // Multicast lookup will still work OEM-dependently; never crash.
            // Throwable, not Exception: stripped OEM frameworks have been known
            // to answer with NoSuchMethodError on this very call.
            BootDiagnostics.warn(this, "multicastLock failed", t)
        }
    }

    override fun onDestroy() {
        multicastLock?.let {
            if (it.isHeld) {
                try {
                    it.release()
                } catch (e: Exception) {
                    // ignore
                }
            }
        }
        multicastLock = null
        BootDiagnostics.stage(this, "activity.onDestroy")
        super.onDestroy()
    }

    private companion object {
        const val NETWORK_CHANNEL = "com.kayan.carguard/network"
        const val BACKGROUND_CHANNEL = "car_guard/background"
        const val BOOT_CHANNEL = "car_guard/boot"
        const val PAIRING_TIMEOUT_MS = 30_000
    }
}
