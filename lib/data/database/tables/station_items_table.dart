// lib/data/database/tables/station_items_table.dart

import 'package:drift/drift.dart';

/// Items added to a specific station.
/// Prices are SNAPSHOTS - they don't change when master catalog prices change.
@DataClassName('StationItemRow')
class StationItemsTable extends Table {
  @override
  String get tableName => 'station_items';

  TextColumn get id => text().named('id')();
  TextColumn get stationId => text().named('station_id')();
  TextColumn get itemId => text().named('item_id').nullable()(); // null = custom item not in catalog
  TextColumn get description => text().named('description').withLength(max: 500)();
  TextColumn get brand => text().named('brand').nullable()();
  TextColumn get model => text().named('model').nullable()();
  TextColumn get unit => text().named('unit').nullable()();

  // Quantity * 1000 to support 3 decimal places stored as int
  IntColumn get quantityMilliunits => integer().named('quantity_milliunits').withDefault(const Constant(1000))();

  /// PRICE SNAPSHOT - captured when item was added to station
  IntColumn get unitPriceSnapshotMillimes => integer().named('unit_price_snapshot_millimes').withDefault(const Constant(0))();

  /// Discount in percentage (0-100) * 100 for 2 decimal precision
  IntColumn get discountPercentageCents => integer().named('discount_percentage_cents').withDefault(const Constant(0))();

  /// Tax in percentage (0-100) * 100 for 2 decimal precision
  IntColumn get taxPercentageCents => integer().named('tax_percentage_cents').withDefault(const Constant(0))();

  TextColumn get notes => text().named('notes').nullable()();
  IntColumn get sortOrder => integer().named('sort_order').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  TextColumn get addedBy => text().named('added_by').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
