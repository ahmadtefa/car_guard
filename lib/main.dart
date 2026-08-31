// lib/main.dart
// Solar Manager - نظام إدارة محطات الطاقة الشمسية
// Phase 1: Core Architecture, Database, Models, CRUD

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/repositories/customer_repository_impl.dart';
import 'data/repositories/expense_category_repository_impl.dart';
import 'data/repositories/item_repository_impl.dart';
import 'data/repositories/station_repository_impl.dart';
import 'presentation/providers/customer_provider.dart';
import 'presentation/providers/item_provider.dart';
import 'presentation/providers/station_provider.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize database (Offline First)
  final db = AppDatabase();

  // Initialize repositories
  final customerRepo = CustomerRepositoryImpl(db);
  final stationRepo = StationRepositoryImpl(db);
  final itemRepo = ItemRepositoryImpl(db);
  final expenseCatRepo = ExpenseCategoryRepositoryImpl(db);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: db),
        ChangeNotifierProvider(
          create: (_) => CustomerProvider(customerRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => StationProvider(stationRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => ItemProvider(itemRepo, expenseCatRepo),
        ),
      ],
      child: const SolarManagerApp(),
    ),
  );
}

class SolarManagerApp extends StatelessWidget {
  const SolarManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // RTL support - Arabic primary language
      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const DashboardScreen(),
    );
  }
}
