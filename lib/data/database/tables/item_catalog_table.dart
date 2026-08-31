// lib/data/database/tables/item_catalog_table.dart

import 'package:drift/drift.dart';

@DataClassName('ItemRow')
class ItemCatalogTable extends Table {
  @override
  String get tableName => 'item_catalog';

  TextColumn get id => text().named('id')();
  TextColumn get name => text().named('name').withLength(max: 200)();
  TextColumn get categoryId => text().named('category_id')();
  TextColumn get unit => text().named('unit').nullable()(); // Piece, Meter, Kg, etc.
  TextColumn get brand => text().named('brand').nullable()();
  TextColumn get model => text().named('model').nullable()();
  TextColumn get description => text().named('description').nullable()();

  // Current price stored as millimes
  IntColumn get unitPriceMillimes => integer().named('unit_price_millimes').withDefault(const Constant(0))();

  TextColumn get supplier => text().named('supplier').nullable()();
  TextColumn get notes => text().named('notes').nullable()();
  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  TextColumn get createdBy => text().named('created_by').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
