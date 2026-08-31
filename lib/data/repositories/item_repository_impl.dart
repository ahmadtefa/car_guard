// lib/data/repositories/item_repository_impl.dart

import 'package:drift/drift.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/item_category.dart';
import '../../domain/repositories/item_repository.dart';
import '../database/app_database.dart';
import '../models/item_mapper.dart';

class ItemRepositoryImpl implements ItemRepository {
  final AppDatabase _db;

  ItemRepositoryImpl(this._db);

  // ========== ITEMS ==========

  @override
  Future<Result<List<CatalogItem>>> getAllItems(
      {bool activeOnly = true}) async {
    try {
      final stmt = _db.select(_db.itemCatalogTable);
      if (activeOnly) {
        stmt.where((t) => t.isActive.equals(true));
      }
      stmt.orderBy([(t) => OrderingTerm.asc(t.name)]);
      final rows = await stmt.get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get items: $e'));
    }
  }

  @override
  Future<Result<CatalogItem>> getItemById(String id) async {
    try {
      final row = await (_db.select(_db.itemCatalogTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        return Result.failure(const NotFoundFailure('Item not found'));
      }
      return Result.success(row.toDomain());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get item: $e'));
    }
  }

  @override
  Future<Result<List<CatalogItem>>> getItemsByCategory(
      String categoryId) async {
    try {
      final rows = await (_db.select(_db.itemCatalogTable)
            ..where((t) =>
                t.categoryId.equals(categoryId) & t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to get items by category: $e'));
    }
  }

  @override
  Future<Result<CatalogItem>> createItem(CatalogItem item) async {
    try {
      final now = DateTime.now();
      final newItem = item.copyWith(
        id: item.id.isEmpty ? IdGenerator.generate() : item.id,
        createdAt: now,
      );
      await _db.into(_db.itemCatalogTable).insert(newItem.toCompanion());
      return Result.success(newItem);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to create item: $e'));
    }
  }

  @override
  Future<Result<CatalogItem>> updateItem(CatalogItem item) async {
    try {
      final now = DateTime.now();
      // Record price history if price changed
      final existing = await getItemById(item.id);
      if (existing.isSuccess &&
          existing.value.unitPrice.millimes != item.unitPrice.millimes) {
        await _db.into(_db.priceHistoryTable).insert(
              PriceHistoryTableCompanion.insert(
                id: IdGenerator.generate(),
                itemId: item.id,
                oldPriceMillimes: existing.value.unitPrice.millimes,
                newPriceMillimes: item.unitPrice.millimes,
                changedAt: Value(now),
                changedBy: Value(item.createdBy),
              ),
            );
      }

      final updated = item.copyWith(updatedAt: now);
      await (_db.update(_db.itemCatalogTable)
            ..where((t) => t.id.equals(item.id)))
          .write(updated.toCompanion());
      return Result.success(updated);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update item: $e'));
    }
  }

  @override
  Future<Result<void>> deleteItem(String id) async {
    try {
      await (_db.update(_db.itemCatalogTable)
            ..where((t) => t.id.equals(id)))
          .write(const ItemCatalogTableCompanion(isActive: Value(false)));
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete item: $e'));
    }
  }

  @override
  Future<Result<List<CatalogItem>>> searchItems(String query) async {
    try {
      final q = '%${query.toLowerCase()}%';
      final rows = await (_db.select(_db.itemCatalogTable)
            ..where((t) =>
                t.isActive.equals(true) &
                (t.name.lower().like(q) |
                    t.brand.lower().like(q) |
                    t.model.lower().like(q) |
                    t.description.lower().like(q)))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to search items: $e'));
    }
  }

  // ========== CATEGORIES ==========

  @override
  Future<Result<List<ItemCategory>>> getAllCategories(
      {bool activeOnly = true}) async {
    try {
      final stmt = _db.select(_db.itemCategoriesTable);
      if (activeOnly) {
        stmt.where((t) => t.isActive.equals(true));
      }
      stmt.orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
      final rows = await stmt.get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get categories: $e'));
    }
  }

  @override
  Future<Result<ItemCategory>> getCategoryById(String id) async {
    try {
      final row = await (_db.select(_db.itemCategoriesTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        return Result.failure(const NotFoundFailure('Category not found'));
      }
      return Result.success(row.toDomain());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get category: $e'));
    }
  }

  @override
  Future<Result<ItemCategory>> createCategory(ItemCategory category) async {
    try {
      final now = DateTime.now();
      final newCat = category.copyWith(
        id: category.id.isEmpty ? IdGenerator.generate() : category.id,
        createdAt: now,
      );
      await _db.into(_db.itemCategoriesTable).insert(newCat.toCompanion());
      return Result.success(newCat);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to create category: $e'));
    }
  }

  @override
  Future<Result<ItemCategory>> updateCategory(ItemCategory category) async {
    try {
      await (_db.update(_db.itemCategoriesTable)
            ..where((t) => t.id.equals(category.id)))
          .write(category.toCompanion());
      return Result.success(category);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update category: $e'));
    }
  }

  @override
  Future<Result<void>> deleteCategory(String id) async {
    try {
      await (_db.update(_db.itemCategoriesTable)
            ..where((t) => t.id.equals(id)))
          .write(const ItemCategoriesTableCompanion(isActive: Value(false)));
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete category: $e'));
    }
  }
}
