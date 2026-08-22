package com.example.car_guard

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      BACKGROUND_CHANNEL,
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "start" -> {
          CarGuardForegroundService.start(this)
          result.success(null)
        }
        "stop" -> {
          CarGuardForegroundService.stop(this)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  private companion object {
    const val BACKGROUND_CHANNEL = "car_guard/background"
  }
}
