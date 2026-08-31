// lib/domain/repositories/item_repository.dart

import '../entities/catalog_item.dart';
import '../entities/item_category.dart';
import '../../core/utils/result.dart';

abstract class ItemRepository {
  // Items
  Future<Result<List<CatalogItem>>> getAllItems({bool activeOnly = true});
  Future<Result<CatalogItem>> getItemById(String id);
  Future<Result<List<CatalogItem>>> getItemsByCategory(String categoryId);
  Future<Result<CatalogItem>> createItem(CatalogItem item);
  Future<Result<CatalogItem>> updateItem(CatalogItem item);
  Future<Result<void>> deleteItem(String id);
  Future<Result<List<CatalogItem>>> searchItems(String query);

  // Categories
  Future<Result<List<ItemCategory>>> getAllCategories({bool activeOnly = true});
  Future<Result<ItemCategory>> getCategoryById(String id);
  Future<Result<ItemCategory>> createCategory(ItemCategory category);
  Future<Result<ItemCategory>> updateCategory(ItemCategory category);
  Future<Result<void>> deleteCategory(String id);
}
