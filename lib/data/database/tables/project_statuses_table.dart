// lib/data/database/tables/project_statuses_table.dart

import 'package:drift/drift.dart';

/// User-configurable project statuses
@DataClassName('ProjectStatusRow')
class ProjectStatusesTable extends Table {
  @override
  String get tableName => 'project_statuses';

  TextColumn get id => text().named('id')();
  TextColumn get nameAr => text().named('name_ar').withLength(max: 200)();
  TextColumn get nameEn => text().named('name_en').withLength(max: 200)();
  TextColumn get colorHex => text().named('color_hex').nullable()(); // e.g., '#4CAF50'
  IntColumn get sortOrder => integer().named('sort_order').withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().named('is_default').withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
