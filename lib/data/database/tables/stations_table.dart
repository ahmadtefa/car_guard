// lib/data/database/tables/stations_table.dart

import 'package:drift/drift.dart';

@DataClassName('StationRow')
class StationsTable extends Table {
  @override
  String get tableName => 'stations';

  TextColumn get id => text().named('id')();
  TextColumn get stationNumber => text().named('station_number').unique()();
  TextColumn get name => text().named('name').withLength(max: 200)();
  TextColumn get customerId => text().named('customer_id').nullable()();

  // Location
  TextColumn get address => text().named('address').nullable()();
  RealColumn get latitude => real().named('latitude').nullable()();
  RealColumn get longitude => real().named('longitude').nullable()();

  // Area (in square meters * 100 to store 2 decimal precision as int)
  RealColumn get landArea => real().named('land_area').nullable()();
  RealColumn get roofArea => real().named('roof_area').nullable()();
  RealColumn get availableArea => real().named('available_area').nullable()();

  // Project type
  TextColumn get projectType => text().named('project_type').nullable()();

  // Capacity (in kWp * 100 for precision)
  RealColumn get requiredCapacityKwp => real().named('required_capacity_kwp').nullable()();
  RealColumn get totalPanelsCapacityKwp => real().named('total_panels_capacity_kwp').nullable()();

  // Status
  TextColumn get status => text().named('status').withDefault(const Constant('study'))();

  // Responsible
  TextColumn get responsiblePerson => text().named('responsible_person').nullable()();

  // Notes
  TextColumn get notes => text().named('notes').nullable()();

  // Financial (stored as millimes - integer to avoid floating point)
  IntColumn get sellingPriceMillimes => integer().named('selling_price_millimes').withDefault(const Constant(0))();
  IntColumn get discountMillimes => integer().named('discount_millimes').withDefault(const Constant(0))();
  IntColumn get taxPercentage => integer().named('tax_percentage').withDefault(const Constant(0))(); // 0-100

  // Timestamps
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  TextColumn get createdBy => text().named('created_by').nullable()();

  // Sync fields
  IntColumn get revisionNumber => integer().named('revision_number').withDefault(const Constant(1))();
  DateTimeColumn get lastModifiedAt => dateTime().named('last_modified_at').nullable()();
  TextColumn get lastModifiedBy => text().named('last_modified_by').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
