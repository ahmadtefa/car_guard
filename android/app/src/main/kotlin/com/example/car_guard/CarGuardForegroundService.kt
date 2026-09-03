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
 *
 * Crash-safety rules that matter on car head units (see the phone-vs-head-unit
 * startup crash this file was hardened for):
 *
 *  * A Service that throws takes the *whole* process with it — "Car Guard keeps
 *    stopping". Nothing on the Dart side can catch that, because the throw
 *    happens on the Android main thread of the service.
 *  * Head-unit builds differ from phones in ways that only show up here:
 *    notifications/heads-up may be disabled by policy, the notification shade
 *    may not exist, foreground-service starts from the background may be
 *    rejected, and there may be no Wi-Fi service at all (wired/Ethernet
 *    units). Every one of those used to reach `startForeground()` or a lock
 *    call unguarded.
 *
 * So: every step is individually guarded and degrades to "no keep-alive
 * service" instead of "no app".
 */
class CarGuardForegroundService : Service() {

  private var wifiLock: WifiManager.WifiLock? = null
  private var wakeLock: PowerManager.WakeLock? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    // Throwable, not Exception: on stripped OEM frameworks even
    // NoSuchMethodError/NoClassDefFoundError are in play, and any of them
    // escaping here is the process dying at startup.
    try {
      if (intent?.action == ACTION_STOP) {
        stopSelf()
      } else {
        goForeground()
      }
    } catch (t: Throwable) {
      Log.w(TAG, "Foreground service disabled itself: $t")
      BootDiagnostics.warn(this, "fgService.onStartCommand", t)
      stopSelfQuietly()
    }

    // If the app dies the service must die with it instead of leaving a
    // zombie notification behind without the Flutter engine.
    return START_NOT_STICKY
  }

  override fun onDestroy() {
    try {
      releaseLocks()
    } catch (t: Throwable) {
      Log.w(TAG, "Lock release failed: $t")
    }

    try {
      unbindNetwork()
    } catch (t: Throwable) {
      Log.w(TAG, "Network unbind failed: $t")
    }

    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        stopForeground(STOP_FOREGROUND_REMOVE)
      } else {
        @Suppress("DEPRECATION")
        stopForeground(true)
      }
    } catch (t: Throwable) {
      // Stopping must never throw either (a dead service object is common
      // when the notification was rejected while starting).
      Log.w(TAG, "stopForeground failed: $t")
    }

    super.onDestroy()
  }

  private fun goForeground() {
    BootDiagnostics.stage(this, "fgService.goForeground")

    createNotificationChannel()

    val notification = buildNotification()

    startForegroundCompat(notification)

    acquireLocks()
    bindToWifiNetwork()
  }

  /**
   * Promotes the service, walking down a list of foreground-service types
   * until one is accepted.
   *
   * Why a ladder: on Android 10+ the type must be one of the types declared in
   * the manifest, and on Android 14+ the *matching permission* must also be
   * held — `location` without a granted runtime permission throws
   * SecurityException, and vendor builds reject `connectedDevice` outright on
   * occasion. One hard-coded type therefore crashes some head units while
   * working on every phone. Falling through keeps the keep-alive alive where
   * possible and drops it silently where not.
   */
  private fun startForegroundCompat(notification: Notification) {
    val types = ArrayList<Int>(3)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE

      // Add the location type so GPS speed/distance keeps updating in the
      // background — but only once the app actually holds the location
      // permission, otherwise startForeground throws a SecurityException.
      if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
          android.content.pm.PackageManager.PERMISSION_GRANTED
      ) {
        serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
      }

      types += serviceType
      types += ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
    }

    for (type in types) {
      val promoted = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          startForeground(NOTIFICATION_ID, notification, type)
        } else {
          @Suppress("DEPRECATION")
          startForeground(NOTIFICATION_ID, notification)
        }
        true
      } catch (t: Throwable) {
        Log.w(TAG, "startForeground(type=$type) refused: $t")
        BootDiagnostics.warn(this, "fgService.startForeground type=$type", t)
        false
      }

      if (promoted) {
        BootDiagnostics.stage(this, "fgService.promoted(type=$type)")
        return
      }
    }

    // Last resort, and also the path taken on API < 29: the untyped overload.
    // Skipping startForeground entirely is not an option — a service started
    // with startForegroundService() that never promotes is killed with
    // ForegroundServiceDidNotStartInTimeException, which looks exactly like an
    // app crash to the user.
    try {
      @Suppress("DEPRECATION")
      startForeground(NOTIFICATION_ID, notification)
      BootDiagnostics.stage(this, "fgService.promoted(untyped)")
    } catch (t: Throwable) {
      Log.w(TAG, "startForeground() refused entirely: $t")
      BootDiagnostics.warn(this, "fgService.startForeground untyped", t)
      stopSelfQuietly()
    }
  }

  /** Stops the service and drops any pending "must call startForeground" timer. */
  private fun stopSelfQuietly() {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        stopForeground(STOP_FOREGROUND_REMOVE)
      }
    } catch (t: Throwable) {
      Log.w(TAG, "stopForeground during bail-out failed: $t")
    }
    try {
      stopSelf()
    } catch (t: Throwable) {
      Log.w(TAG, "stopSelf failed: $t")
    }
  }

  private fun buildNotification(): Notification {
    // Tapping the notification brings the app back to the foreground.
    val launchIntent = try {
      packageManager.getLaunchIntentForPackage(packageName)
    } catch (t: Throwable) {
      Log.w(TAG, "Launch intent unavailable: $t")
      null
    }

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
      .setSmallIcon(notificationIcon())
      .setOngoing(true)
      .apply { contentIntent?.let { setContentIntent(it) } }
      .build()
  }

  /**
   * A plain bitmap drawable for the notification icon.
   *
   * `applicationInfo.icon` is the *launcher* icon, which on API 26+ resolves
   * to the adaptive-icon XML in `mipmap-anydpi-v26`. Phones tolerate that;
   * plenty of automotive/system builds do not render adaptive drawables in the
   * status-bar slot and instead answer with
   * `RemoteServiceException: Bad notification for startForeground`, thrown into
   * the app process a moment after the service starts — i.e. an instant crash
   * right after launch, on the car screen only.
   */
  private fun notificationIcon(): Int =
    if (runCatching { resources.getResourceName(R.drawable.ic_launcher_foreground) }.isSuccess) {
      R.drawable.ic_launcher_foreground
    } else {
      applicationInfo.icon
    }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      return
    }

    try {
      val manager =
        getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

      // recreated on purpose: on builds where notifications were turned off (a
      // very common head-unit/kiosk policy) the channel is gone, and promoting
      // with a notification that points at a deleted channel is fatal.
      if (manager.getNotificationChannel(CHANNEL_ID) == null) {
        val channel = NotificationChannel(
          CHANNEL_ID,
          "Device connection",
          NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
      }

      if (manager.getNotificationChannel(CHANNEL_ID) == null) {
        Log.w(TAG, "Notification channel could not be created — keeping service without promotion")
        BootDiagnostics.warn(this, "fgService.notificationChannel unavailable")
      }
    } catch (t: Throwable) {
      Log.w(TAG, "Notification channel failed: $t")
      BootDiagnostics.warn(this, "fgService.notificationChannel", t)
    }
  }

  /**
   * Keeps the CPU and the Wi-Fi radio awake so the timers and the periodic
   * polling keep firing while the screen is off or the app is backgrounded.
   *
   * Both locks are optional: they only improve background latency, and a unit
   * that refuses one must keep monitoring rather than crash.
   */
  private fun acquireLocks() {
    try {
      if (wakeLock == null) {
        val powerManager =
          getSystemService(Context.POWER_SERVICE) as? PowerManager
        wakeLock = powerManager?.newWakeLock(
          PowerManager.PARTIAL_WAKE_LOCK,
          "car_guard:device_connection",
        )?.apply {
          setReferenceCounted(false)
          acquire()
        }
      }
    } catch (t: Throwable) {
      Log.w(TAG, "Wake lock unavailable: $t")
      BootDiagnostics.warn(this, "fgService.wakeLock", t)
    }

    try {
      if (wifiLock == null) {
        val wifiManager =
          applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        // Wi-Fi-less units (wired automotive builds) return a null service
        // here — previously the `as WifiManager` cast crashed the process.
        if (wifiManager != null) {
          // WIFI_MODE_FULL_LOW_LATENCY only exists on API 29+; asking an
          // older Wi-Fi service for an unknown lock mode throws
          // IllegalArgumentException out of acquire().
          val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            WifiManager.WIFI_MODE_FULL_LOW_LATENCY
          } else {
            @Suppress("DEPRECATION")
            WifiManager.WIFI_MODE_FULL_HIGH_PERF
          }

          wifiLock = wifiManager.createWifiLock(mode, "car_guard:device_connection")
            ?.apply {
              setReferenceCounted(false)
              acquire()
            }
        }
      }
    } catch (t: Throwable) {
      Log.w(TAG, "Wi-Fi lock unavailable: $t")
      BootDiagnostics.warn(this, "fgService.wifiLock", t)
    }
  }

  private fun releaseLocks() {
    wifiLock?.let {
      if (it.isHeld) {
        try {
          it.release()
        } catch (t: Throwable) {
          Log.w(TAG, "Wi-Fi lock release failed: $t")
        }
      }
    }
    wifiLock = null

    wakeLock?.let {
      if (it.isHeld) {
        try {
          it.release()
        } catch (t: Throwable) {
          Log.w(TAG, "Wake lock release failed: $t")
        }
      }
    }
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
        getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return

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
        getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
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
      } catch (t: Throwable) {
        // Android 12+ can block starting a foreground service while the app
        // itself is in the background; the next connect event retries.
        // Throwable on purpose: ForegroundServiceStartNotAllowedException is a
        // RuntimeException and used to escape into the platform-channel
        // handler, which killed the app on background-launch builds.
        Log.w(TAG, "Cannot start foreground service: $t")
        BootDiagnostics.warn(context, "fgService.start", t)
      }
    }

    fun stop(context: Context) {
      // stopService() rather than startService(ACTION_STOP): starting a service
      // while the app is in the background throws IllegalStateException on
      // Android 8+, and stop() is usually called right when the app goes away.
      try {
        context.stopService(
          Intent(context, CarGuardForegroundService::class.java).setAction(ACTION_STOP),
        )
      } catch (t: Throwable) {
        Log.w(TAG, "Cannot stop foreground service: $t")
      }
    }
  }
}
