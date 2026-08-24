package com.example.car_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * Keeps the app process in foreground state while it talks to the Car Guard
 * device. Without this, Android suspends the WebSocket socket and the
 * polling timers a few seconds after the app is sent to the background or
 * the screen turns off, which freezes all readings.
 */
class CarGuardForegroundService : Service() {

  private var wifiLock: WifiManager.WifiLock? = null
  private var wakeLock: PowerManager.WakeLock? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == ACTION_STOP) {
      stopSelf()
    } else {
      goForeground()
    }

    // If the app dies the service must die with it instead of leaving a
    // zombie notification behind without the Flutter engine.
    return START_NOT_STICKY
  }

  override fun onDestroy() {
    releaseLocks()
    unbindNetwork()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_REMOVE)
    } else {
      @Suppress("DEPRECATION")
      stopForeground(true)
    }

    super.onDestroy()
  }

  private fun goForeground() {
    createNotificationChannel()

    val notification = buildNotification()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE

      // Add the location type so GPS speed/distance keeps updating in the
      // background — but only once the app actually holds the location
      // permission, otherwise startForeground throws a SecurityException.
      if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
          android.content.pm.PackageManager.PERMISSION_GRANTED) {
        serviceType =
          serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
      }

      startForeground(NOTIFICATION_ID, notification, serviceType)
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }

    acquireLocks()
    bindToWifiNetwork()
  }

  private fun buildNotification(): Notification {
    // Tapping the notification brings the app back to the foreground.
    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
    val contentIntent = launchIntent?.let {
      PendingIntent.getActivity(
        this,
        0,
        it,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    }

    val builder =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(this, CHANNEL_ID)
      } else {
        @Suppress("DEPRECATION")
        Notification.Builder(this)
      }

    return builder
      .setContentTitle("Car Guard")
      .setContentText("Monitoring device and trip in the background")
      .setSmallIcon(applicationInfo.icon)
      .setOngoing(true)
      .apply { contentIntent?.let { setContentIntent(it) } }
      .build()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Device connection",
        NotificationManager.IMPORTANCE_LOW,
      )
      val manager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      manager.createNotificationChannel(channel)
    }
  }

  /**
   * Keeps the CPU and the Wi-Fi radio awake so the timers and the periodic
   * polling keep firing while the screen is off or the app is backgrounded.
   */
  private fun acquireLocks() {
    if (wakeLock == null) {
      val powerManager =
        getSystemService(Context.POWER_SERVICE) as PowerManager
      wakeLock = powerManager.newWakeLock(
        PowerManager.PARTIAL_WAKE_LOCK,
        "car_guard:device_connection",
      ).apply {
        setReferenceCounted(false)
        acquire()
      }
    }

    if (wifiLock == null) {
      val wifiManager =
        applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
      wifiLock = wifiManager.createWifiLock(
        WifiManager.WIFI_MODE_FULL_LOW_LATENCY,
        "car_guard:device_connection",
      ).apply {
        setReferenceCounted(false)
        acquire()
      }
    }
  }

  private fun releaseLocks() {
    wifiLock?.let { if (it.isHeld) it.release() }
    wifiLock = null

    wakeLock?.let { if (it.isHeld) it.release() }
    wakeLock = null
  }

  /**
   * The device hotspot offers no internet access, so Android prefers other
   * networks (e.g. mobile data) for app traffic and may drop the hotspot in
   * the background. Binding the process to the current Wi-Fi network forces
   * the device traffic through it for as long as the service runs.
   */
  private fun bindToWifiNetwork() {
    try {
      val connectivityManager =
        getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

      @Suppress("DEPRECATION")
      val network = connectivityManager.activeNetwork ?: return
      val capabilities =
        connectivityManager.getNetworkCapabilities(network) ?: return

      if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
        connectivityManager.bindProcessToNetwork(network)
      }
    } catch (e: Exception) {
      Log.w(TAG, "Could not bind to Wi-Fi network: $e")
    }
  }

  private fun unbindNetwork() {
    try {
      val connectivityManager =
        getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
      connectivityManager.bindProcessToNetwork(null)
    } catch (e: Exception) {
      Log.w(TAG, "Could not unbind network: $e")
    }
  }

  companion object {
    private const val TAG = "CarGuardFgService"
    private const val CHANNEL_ID = "car_guard_connection"
    private const val NOTIFICATION_ID = 1001
    private const val ACTION_STOP = "car_guard.action.STOP"

    fun start(context: Context) {
      try {
        val intent = Intent(context, CarGuardForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          context.startForegroundService(intent)
        } else {
          context.startService(intent)
        }
      } catch (e: Exception) {
        // Android 12+ can block starting a foreground service while the app
        // itself is in the background; the next connect event retries.
        Log.w(TAG, "Cannot start foreground service: $e")
      }
    }

    fun stop(context: Context) {
      val intent = Intent(context, CarGuardForegroundService::class.java)
        .setAction(ACTION_STOP)
      context.startService(intent)
    }
  }
}
