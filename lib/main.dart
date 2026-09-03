import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/boot_diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TEMP(car-crash): records the startup stages and every uncaught Dart error
  // next to the native stage log, so a head-unit crash can be read back inside
  // the app on the next launch. See lib/core/services/boot_diagnostics.dart.
  BootDiagnostics.installErrorCapture();
  BootDiagnostics.stage('dart.main');

  runApp(
    const ProviderScope(
      child: CarGuardApp(),
    ),
  );
}