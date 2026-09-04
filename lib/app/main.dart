import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Application entry point for the Car Guard app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CarGuardApp starts background monitoring only after a fresh ACTIVE
  // response from the ESP8266. Startup itself must never trust persisted
  // license or monitoring state.
  runApp(const ProviderScope(child: CarGuardApp()));
}
