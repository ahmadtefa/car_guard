// lib/data/database/tables/station_history_table.dart

import 'package:drift/drift.dart';

/// Audit log for all changes to a station
@DataClassName('StationHistoryRow')
class StationHistoryTable extends Table {
  @override
  String get tableName => 'station_history';

  TextColumn get id => text().named('id')();
  TextColumn get stationId => text().named('station_id')();
  DateTimeColumn get actionAt => dateTime().named('action_at')();
  TextColumn get actionBy => text().named('action_by').nullable()();
  TextColumn get actionType => text().named('action_type')(); // create, update, delete, add_item, etc.
  TextColumn get entity => text().named('entity').nullable()(); // station, item, expense, etc.
  TextColumn get entityId => text().named('entity_id').nullable()();
  TextColumn get fieldName => text().named('field_name').nullable()();
  TextColumn get oldValue => text().named('old_value').nullable()();
  TextColumn get newValue => text().named('new_value').nullable()();
  TextColumn get description => text().named('description').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
