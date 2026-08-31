// lib/data/repositories/customer_repository_impl.dart

import 'package:drift/drift.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../database/app_database.dart';
import '../models/customer_mapper.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final AppDatabase _db;

  CustomerRepositoryImpl(this._db);

  @override
  Future<Result<List<Customer>>> getAllCustomers() async {
    try {
      final rows = await (_db.select(_db.customersTable)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get customers: $e'));
    }
  }

  @override
  Future<Result<Customer>> getCustomerById(String id) async {
    try {
      final row = await (_db.select(_db.customersTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        return Result.failure(const NotFoundFailure('Customer not found'));
      }
      return Result.success(row.toDomain());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get customer: $e'));
    }
  }

  @override
  Future<Result<Customer>> createCustomer(Customer customer) async {
    try {
      final now = DateTime.now();
      final newCustomer = customer.copyWith(
        id: customer.id.isEmpty ? IdGenerator.generate() : customer.id,
        createdAt: now,
        lastModifiedAt: now,
        revisionNumber: 1,
      );
      await _db.into(_db.customersTable).insert(newCustomer.toCompanion());
      return Result.success(newCustomer);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to create customer: $e'));
    }
  }

  @override
  Future<Result<Customer>> updateCustomer(Customer customer) async {
    try {
      final now = DateTime.now();
      final updated = customer.copyWith(
        updatedAt: now,
        lastModifiedAt: now,
        revisionNumber: customer.revisionNumber + 1,
      );
      await (_db.update(_db.customersTable)
            ..where((t) => t.id.equals(customer.id)))
          .write(updated.toCompanion());
      return Result.success(updated);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update customer: $e'));
    }
  }

  @override
  Future<Result<void>> deleteCustomer(String id) async {
    try {
      // Soft delete
      await (_db.update(_db.customersTable)..where((t) => t.id.equals(id)))
          .write(const CustomersTableCompanion(isDeleted: Value(true)));
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete customer: $e'));
    }
  }

  @override
  Future<Result<List<Customer>>> searchCustomers(String query) async {
    try {
      final q = '%${query.toLowerCase()}%';
      final rows = await (_db.select(_db.customersTable)
            ..where((t) =>
                t.isDeleted.equals(false) &
                (t.name.lower().like(q) |
                    t.phone.lower().like(q) |
                    t.email.lower().like(q) |
                    t.address.lower().like(q)))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to search customers: $e'));
    }
  }
}
