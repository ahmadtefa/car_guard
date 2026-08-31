// lib/domain/repositories/expense_repository.dart

import '../entities/expense_category.dart';
import '../../core/utils/result.dart';

abstract class ExpenseCategoryRepository {
  Future<Result<List<ExpenseCategory>>> getAllCategories({bool activeOnly = true});
  Future<Result<ExpenseCategory>> getCategoryById(String id);
  Future<Result<ExpenseCategory>> createCategory(ExpenseCategory category);
  Future<Result<ExpenseCategory>> updateCategory(ExpenseCategory category);
  Future<Result<void>> deleteCategory(String id);
}
