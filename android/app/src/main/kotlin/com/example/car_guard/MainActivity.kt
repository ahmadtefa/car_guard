package com.example.car_guard

import com.example.car_guard.car.CarStatusStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CAR_STATUS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishStatus" -> {
                    val snapshot = CarStatusStore.Snapshot(
                        connected = call.argument<Boolean>("connected") ?: false,
                        engineTemperatureC = call.argument<Double>("engineTemperatureC"),
                        batteryVoltage = call.argument<Double>("batteryVoltage"),
                        coolantAvailable = call.argument<Boolean>("coolantAvailable"),
                        fanRunning = call.argument<Boolean>("fanRunning"),
                        lastUpdatedMs = System.currentTimeMillis(),
                    )
                    CarStatusStore.save(applicationContext, snapshot)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CAR_STATUS_CHANNEL = "car_guard/car_status"
    }
}
