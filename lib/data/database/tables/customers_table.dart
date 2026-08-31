// lib/data/database/tables/customers_table.dart

import 'package:drift/drift.dart';

@DataClassName('CustomerRow')
class CustomersTable extends Table {
  @override
  String get tableName => 'customers';

  TextColumn get id => text().named('id')();
  TextColumn get name => text().named('name').withLength(max: 200)();
  TextColumn get phone => text().named('phone').nullable()();
  TextColumn get phoneAlt => text().named('phone_alt').nullable()();
  TextColumn get email => text().named('email').nullable()();
  TextColumn get address => text().named('address').nullable()();
  TextColumn get governorate => text().named('governorate').nullable()();
  TextColumn get city => text().named('city').nullable()();
  TextColumn get notes => text().named('notes').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  TextColumn get createdBy => text().named('created_by').nullable()();

  // Sync fields (for future cloud sync)
  IntColumn get revisionNumber => integer().named('revision_number').withDefault(const Constant(1))();
  DateTimeColumn get lastModifiedAt => dateTime().named('last_modified_at').nullable()();
  TextColumn get lastModifiedBy => text().named('last_modified_by').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
