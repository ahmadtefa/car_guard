import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/background_monitor.dart';
import 'app.dart';

/// Application entry point for the Car Guard app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restart the background monitoring service if the user enabled it
  // (covers the case where the phone rebooted).
  unawaited(BackgroundMonitor.ensureFromStorage());

  runApp(const ProviderScope(child: CarGuardApp()));
}
