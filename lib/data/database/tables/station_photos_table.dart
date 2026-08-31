// lib/data/database/tables/station_photos_table.dart

import 'package:drift/drift.dart';

@DataClassName('StationPhotoRow')
class StationPhotosTable extends Table {
  @override
  String get tableName => 'station_photos';

  TextColumn get id => text().named('id')();
  TextColumn get stationId => text().named('station_id')();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get fileName => text().named('file_name')();
  TextColumn get category => text().named('category').nullable()(); // site, inspection, panels, etc.
  TextColumn get caption => text().named('caption').nullable()();
  IntColumn get fileSizeBytes => integer().named('file_size_bytes').nullable()();
  DateTimeColumn get capturedAt => dateTime().named('captured_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get addedBy => text().named('added_by').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
