// lib/data/models/expense_mapper.dart

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../core/utils/money.dart';

extension ExpenseRowMapper on ExpenseRow {
  Expense toDomain() {
    return Expense(
      id: id,
      stationId: stationId,
      expenseDate: expenseDate,
      categoryId: categoryId,
      description: description,
      quantityMilliunits: quantityMilliunits,
      unit: unit,
      unitPrice: Money.fromMillimes(unitPriceMillimes),
      addedBy: addedBy,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension ExpenseMapper on Expense {
  ExpensesTableCompanion toCompanion() {
    return ExpensesTableCompanion(
      id: Value(id),
      stationId: Value(stationId),
      expenseDate: Value(expenseDate),
      categoryId: Value(categoryId),
      description: Value(description),
      quantityMilliunits: Value(quantityMilliunits),
      unit: Value(unit),
      unitPriceMillimes: Value(unitPrice.millimes),
      addedBy: Value(addedBy),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

extension ExpenseCategoryRowMapper on ExpenseCategoryRow {
  ExpenseCategory toDomain() {
    return ExpenseCategory(
      id: id,
      nameAr: nameAr,
      nameEn: nameEn,
      description: description,
      sortOrder: sortOrder,
      isDefault: isDefault,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}

extension ExpenseCategoryMapper on ExpenseCategory {
  ExpenseCategoriesTableCompanion toCompanion() {
    return ExpenseCategoriesTableCompanion(
      id: Value(id),
      nameAr: Value(nameAr),
      nameEn: Value(nameEn),
      description: Value(description),
      sortOrder: Value(sortOrder),
      isDefault: Value(isDefault),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }
}
