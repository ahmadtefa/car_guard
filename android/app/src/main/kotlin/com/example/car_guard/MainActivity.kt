package com.example.car_guard

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NETWORK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindToWifi" -> result.success(bindProcessToWifi())
                "bindToDefault" -> result.success(unbindProcess())
                else -> result.notImplemented()
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
        val manager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

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
        val manager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return manager.bindProcessToNetwork(null)
    }

    private companion object {
        const val NETWORK_CHANNEL = "com.kayan.carguard/network"
    }
}
