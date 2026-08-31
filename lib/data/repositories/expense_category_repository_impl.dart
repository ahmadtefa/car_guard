// lib/data/repositories/expense_category_repository_impl.dart

import 'package:drift/drift.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../database/app_database.dart';
import '../models/expense_mapper.dart';

class ExpenseCategoryRepositoryImpl implements ExpenseCategoryRepository {
  final AppDatabase _db;

  ExpenseCategoryRepositoryImpl(this._db);

  @override
  Future<Result<List<ExpenseCategory>>> getAllCategories(
      {bool activeOnly = true}) async {
    try {
      final stmt = _db.select(_db.expenseCategoriesTable);
      if (activeOnly) {
        stmt.where((t) => t.isActive.equals(true));
      }
      stmt.orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
      final rows = await stmt.get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to get expense categories: $e'));
    }
  }

  @override
  Future<Result<ExpenseCategory>> getCategoryById(String id) async {
    try {
      final row = await (_db.select(_db.expenseCategoriesTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        return Result.failure(
            const NotFoundFailure('Expense category not found'));
      }
      return Result.success(row.toDomain());
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to get expense category: $e'));
    }
  }

  @override
  Future<Result<ExpenseCategory>> createCategory(
      ExpenseCategory category) async {
    try {
      final now = DateTime.now();
      final newCat = category.copyWith(
        id: category.id.isEmpty ? IdGenerator.generate() : category.id,
        createdAt: now,
      );
      await _db.into(_db.expenseCategoriesTable).insert(newCat.toCompanion());
      return Result.success(newCat);
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to create expense category: $e'));
    }
  }

  @override
  Future<Result<ExpenseCategory>> updateCategory(
      ExpenseCategory category) async {
    try {
      await (_db.update(_db.expenseCategoriesTable)
            ..where((t) => t.id.equals(category.id)))
          .write(category.toCompanion());
      return Result.success(category);
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to update expense category: $e'));
    }
  }

  @override
  Future<Result<void>> deleteCategory(String id) async {
    try {
      await (_db.update(_db.expenseCategoriesTable)
            ..where((t) => t.id.equals(id)))
          .write(
              const ExpenseCategoriesTableCompanion(isActive: Value(false)));
      return Result.success(null);
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to delete expense category: $e'));
    }
  }
}
