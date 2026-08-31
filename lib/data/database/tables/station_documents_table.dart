// lib/data/database/tables/station_documents_table.dart

import 'package:drift/drift.dart';

@DataClassName('StationDocumentRow')
class StationDocumentsTable extends Table {
  @override
  String get tableName => 'station_documents';

  TextColumn get id => text().named('id')();
  TextColumn get stationId => text().named('station_id')();
  TextColumn get filePath => text().named('file_path')();
  TextColumn get fileName => text().named('file_name')();
  TextColumn get fileType => text().named('file_type').nullable()(); // pdf, doc, xls, etc.
  TextColumn get category => text().named('category').nullable()(); // invoice, contract, etc.
  TextColumn get description => text().named('description').nullable()();
  IntColumn get fileSizeBytes => integer().named('file_size_bytes').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get addedBy => text().named('added_by').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
