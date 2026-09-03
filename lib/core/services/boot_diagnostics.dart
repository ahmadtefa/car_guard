import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TEMP(car-crash) — startup diagnostics bridge, Dart side.
///
/// The app starts fine on phones and dies with the system "Car Guard keeps
/// stopping" dialog on the car head unit. The fatal paths for that symptom all
/// live *below* Dart (the foreground service, the Android Auto template
/// service, Wi-Fi locks, the Flutter renderer), so no Dart `try/catch` can see
/// them. The native half (`android/.../BootDiagnostics.kt`) records a stage
/// marker before every startup step plus the last uncaught Java crash; this
/// file only reads that back.
///
/// The point is to diagnose the crash **on the head unit itself** — no adb, no
/// logcat, nothing to install. Delete this file together with
/// `BootDiagnostics.kt`, the `car_guard/boot` channel in `MainActivity.kt` and
/// the three call sites below once car start-up is confirmed healthy.
abstract final class BootDiagnostics {
  static const MethodChannel _channel = MethodChannel('car_guard/boot');

  /// Android only, decided without `dart:io` so the web/desktop builds keep
  /// compiling this file.
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Forwards every uncaught Flutter/Dart error into the native stage log.
  ///
  /// Called once from `main()`. The framework handlers are chained rather than
  /// replaced, so whatever the framework did with an error before, it still
  /// does — the diagnostics can not change app behaviour.
  static void installErrorCapture() {
    if (!_supported) {
      return;
    }

    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousFlutterError?.call(details);
      stage('dart.flutterError: ${details.exceptionAsString()}');
    };

    // WidgetsBinding owns the same dispatcher the engine installs its default
    // handler on; reading it through the binding keeps `dart:ui` out of the
    // imports. Returning the previous result keeps error handling identical.
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final previousDispatcher = dispatcher.onError;
    dispatcher.onError = (Object error, StackTrace stack) {
      stage('dart.uncaught: $error');
      return previousDispatcher?.call(error, stack) ?? true;
    };
  }

  /// Appends a stage marker: fire and forget, never throws.
  static void stage(String name) {
    if (!_supported) {
      return;
    }

    unawaited(
      _channel
          .invokeMethod<void>('stage', <String, String>{'name': name})
          .catchError((Object _) {
            // No plugin (tests, desktop, iOS) or a dead engine — diagnostics
            // must never become a failure of their own.
          }),
    );
  }

  /// Reads back the previous run's crash plus this run's trace.
  ///
  /// Returns null when there is nothing to show.
  static Future<BootReport?> drainLastReport() async {
    if (!_supported) {
      return null;
    }

    try {
      final raw = await _channel.invokeMethod<Object>('drain');
      if (raw is! Map) {
        return null;
      }

      final crash = (raw['crash'] as String?)?.trim() ?? '';
      final trace = (raw['trace'] as String?)?.trim() ?? '';
      final device = (raw['device'] as String?)?.trim() ?? '';

      if (crash.isEmpty && trace.isEmpty) {
        return null;
      }

      return BootReport(crash: crash, trace: trace, device: device);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('BOOT DIAGNOSTICS UNAVAILABLE: $error');
      return null;
    }
  }

  /// Marks the report as read, so the same crash is not shown on every launch.
  static Future<void> clearReport() async {
    if (!_supported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('clearCrash');
    } on PlatformException {
      // Best effort.
    }
  }

  /// Shows the recorded crash once, on top of the dashboard.
  ///
  /// Only reachable when the *previous* run died: a healthy install never sees
  /// this dialog, so the app's normal UI and behaviour stay untouched.
  static Future<void> showLastCrash(BuildContext context) async {
    final report = await drainLastReport();

    if (report == null || !context.mounted) {
      return;
    }

    await clearReport();

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('تشخيص بدء التشغيل / startup diagnostics'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(report.describe()),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق / OK'),
            ),
          ],
        );
      },
    );
  }
}

/// One recorded boot: the crash of the previous run plus the stage trace.
class BootReport {
  const BootReport({
    required this.crash,
    required this.trace,
    required this.device,
  });

  final String crash;
  final String trace;
  final String device;

  bool get hasCrash => crash.isNotEmpty;

  String describe() {
    final buffer = StringBuffer();

    if (device.isNotEmpty) {
      buffer.writeln(device);
    }

    if (hasCrash) {
      buffer
        ..writeln('')
        ..writeln('— آخر انهيار / last crash —')
        ..writeln(crash);
    } else {
      buffer.writeln(
        'لا سجل لانهيار جافا — الانهيار غالبًا داخل محرك Flutter (native) '
        'بعد آخر مرحلة مذكورة أدناه.',
      );
    }

    if (trace.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('— مراحل التشغيل / boot stages —')
        ..writeln(trace);
    }

    return buffer.toString();
  }
}
