// lib/data/database/tables/users_table.dart

import 'package:drift/drift.dart';

/// Users table - prepared for multi-user support in the future
@DataClassName('UserRow')
class UsersTable extends Table {
  @override
  String get tableName => 'users';

  TextColumn get id => text().named('id')();
  TextColumn get name => text().named('name').withLength(max: 200)();
  TextColumn get email => text().named('email').nullable()();
  TextColumn get role => text().named('role').withDefault(const Constant('engineer'))();
  // Roles: admin, manager, engineer, sales, accountant, viewer
  BoolColumn get isActive => boolean().named('is_active').withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
