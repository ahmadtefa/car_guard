// lib/data/database/tables/price_history_table.dart

import 'package:drift/drift.dart';

/// Records price changes for items in master catalog
@DataClassName('PriceHistoryRow')
class PriceHistoryTable extends Table {
  @override
  String get tableName => 'price_history';

  TextColumn get id => text().named('id')();
  TextColumn get itemId => text().named('item_id')();
  IntColumn get oldPriceMillimes => integer().named('old_price_millimes')();
  IntColumn get newPriceMillimes => integer().named('new_price_millimes')();
  DateTimeColumn get changedAt => dateTime().named('changed_at')();
  TextColumn get changedBy => text().named('changed_by').nullable()();
  TextColumn get reason => text().named('reason').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
