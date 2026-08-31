// lib/data/database/app_database.dart
// Drift database - run `flutter pub run build_runner build` to generate app_database.g.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/customers_table.dart';
import 'tables/stations_table.dart';
import 'tables/station_items_table.dart';
import 'tables/item_catalog_table.dart';
import 'tables/item_categories_table.dart';
import 'tables/expenses_table.dart';
import 'tables/expense_categories_table.dart';
import 'tables/station_photos_table.dart';
import 'tables/station_documents_table.dart';
import 'tables/price_history_table.dart';
import 'tables/station_history_table.dart';
import 'tables/project_statuses_table.dart';
import 'tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    CustomersTable,
    StationsTable,
    StationItemsTable,
    ItemCatalogTable,
    ItemCategoriesTable,
    ExpensesTable,
    ExpenseCategoriesTable,
    StationPhotosTable,
    StationDocumentsTable,
    PriceHistoryTable,
    StationHistoryTable,
    ProjectStatusesTable,
    UsersTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with an in-memory database
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _insertDefaultData();
      },
      onUpgrade: (m, from, to) async {
        // Future schema migrations go here
        // Always add addColumn, createTable calls - never drop
      },
    );
  }

  /// Seed the database with default data on first run
  Future<void> _insertDefaultData() async {
    final now = DateTime.now();

    // Default project statuses (user can add more)
    const statuses = [
      (key: 'study', nameAr: 'دراسة', nameEn: 'Study', order: 1),
      (key: 'inspection', nameAr: 'معاينة', nameEn: 'Inspection', order: 2),
      (key: 'pricing', nameAr: 'تسعير', nameEn: 'Pricing', order: 3),
      (key: 'quotation', nameAr: 'عرض سعر', nameEn: 'Quotation', order: 4),
      (key: 'contracted', nameAr: 'تعاقد', nameEn: 'Contracted', order: 5),
      (key: 'under_execution', nameAr: 'تحت التنفيذ', nameEn: 'Under Execution', order: 6),
      (key: 'completed', nameAr: 'مكتمل', nameEn: 'Completed', order: 7),
      (key: 'suspended', nameAr: 'متوقف', nameEn: 'Suspended', order: 8),
      (key: 'cancelled', nameAr: 'ملغي', nameEn: 'Cancelled', order: 9),
    ];

    for (final s in statuses) {
      await into(projectStatusesTable).insert(
        ProjectStatusesTableCompanion.insert(
          id: s.key,
          nameAr: s.nameAr,
          nameEn: s.nameEn,
          sortOrder: Value(s.order),
          isDefault: const Value(true),
          createdAt: Value(now),
        ),
      );
    }

    // Default item categories (user can add more)
    const categories = [
      (key: 'panels', nameAr: 'ألواح شمسية', nameEn: 'Solar Panels', order: 1),
      (key: 'inverters', nameAr: 'إنفرترات', nameEn: 'Inverters', order: 2),
      (key: 'cables', nameAr: 'كابلات', nameEn: 'Cables', order: 3),
      (key: 'structures', nameAr: 'هياكل تركيب', nameEn: 'Mounting Structures', order: 4),
      (key: 'protection', nameAr: 'حماية', nameEn: 'Protection', order: 5),
      (key: 'batteries', nameAr: 'بطاريات', nameEn: 'Batteries', order: 6),
      (key: 'monitoring', nameAr: 'مراقبة', nameEn: 'Monitoring', order: 7),
      (key: 'labor', nameAr: 'عمالة', nameEn: 'Labor', order: 8),
      (key: 'transportation', nameAr: 'نقل', nameEn: 'Transportation', order: 9),
      (key: 'equipment', nameAr: 'معدات', nameEn: 'Equipment', order: 10),
      (key: 'other', nameAr: 'أخرى', nameEn: 'Other', order: 11),
    ];

    for (final c in categories) {
      await into(itemCategoriesTable).insert(
        ItemCategoriesTableCompanion.insert(
          id: c.key,
          nameAr: c.nameAr,
          nameEn: c.nameEn,
          sortOrder: Value(c.order),
          isDefault: const Value(true),
          createdAt: Value(now),
        ),
      );
    }

    // Default expense categories (user can add more)
    const expenseCategories = [
      (key: 'labor', nameAr: 'عمالة', nameEn: 'Labor', order: 1),
      (key: 'transportation', nameAr: 'نقل', nameEn: 'Transportation', order: 2),
      (key: 'fuel', nameAr: 'وقود', nameEn: 'Fuel', order: 3),
      (key: 'accommodation', nameAr: 'إقامة', nameEn: 'Accommodation', order: 4),
      (key: 'food', nameAr: 'طعام', nameEn: 'Food', order: 5),
      (key: 'equipment_rental', nameAr: 'استئجار معدات', nameEn: 'Equipment Rental', order: 6),
      (key: 'crane', nameAr: 'رافعة', nameEn: 'Crane', order: 7),
      (key: 'contractor', nameAr: 'مقاول', nameEn: 'Contractor', order: 8),
      (key: 'shipping', nameAr: 'شحن', nameEn: 'Shipping', order: 9),
      (key: 'customs', nameAr: 'جمارك', nameEn: 'Customs', order: 10),
      (key: 'site_expenses', nameAr: 'مصاريف الموقع', nameEn: 'Site Expenses', order: 11),
      (key: 'administrative', nameAr: 'مصاريف إدارية', nameEn: 'Administrative', order: 12),
      (key: 'other', nameAr: 'أخرى', nameEn: 'Other', order: 13),
    ];

    for (final ec in expenseCategories) {
      await into(expenseCategoriesTable).insert(
        ExpenseCategoriesTableCompanion.insert(
          id: ec.key,
          nameAr: ec.nameAr,
          nameEn: ec.nameEn,
          sortOrder: Value(ec.order),
          isDefault: const Value(true),
          createdAt: Value(now),
        ),
      );
    }

    // Default system user (for local single-user mode)
    await into(usersTable).insert(
      UsersTableCompanion.insert(
        id: 'system',
        name: 'مدير النظام',
        role: const Value('admin'),
        isActive: const Value(true),
        createdAt: Value(now),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'solar_manager.db'));
    return driftDatabase(path: file.path);
  });
}
