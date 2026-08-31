// lib/data/database/tables/expenses_table.dart

import 'package:drift/drift.dart';

@DataClassName('ExpenseRow')
class ExpensesTable extends Table {
  @override
  String get tableName => 'expenses';

  TextColumn get id => text().named('id')();
  TextColumn get stationId => text().named('station_id')();
  DateTimeColumn get expenseDate => dateTime().named('expense_date')();
  TextColumn get categoryId => text().named('category_id')();
  TextColumn get description => text().named('description').withLength(max: 500)();

  // Quantity * 1000 to support 3 decimal places stored as int
  IntColumn get quantityMilliunits => integer().named('quantity_milliunits').withDefault(const Constant(1000))();
  TextColumn get unit => text().named('unit').nullable()();

  // Price stored as millimes
  IntColumn get unitPriceMillimes => integer().named('unit_price_millimes').withDefault(const Constant(0))();

  TextColumn get addedBy => text().named('added_by').nullable()();
  TextColumn get notes => text().named('notes').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
