// lib/data/models/item_mapper.dart

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/item_category.dart';
import '../../core/utils/money.dart';

extension ItemRowMapper on ItemRow {
  CatalogItem toDomain() {
    return CatalogItem(
      id: id,
      name: name,
      categoryId: categoryId,
      unit: unit,
      brand: brand,
      model: model,
      description: description,
      unitPrice: Money.fromMillimes(unitPriceMillimes),
      supplier: supplier,
      notes: notes,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
    );
  }
}

extension CatalogItemMapper on CatalogItem {
  ItemCatalogTableCompanion toCompanion() {
    return ItemCatalogTableCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: Value(categoryId),
      unit: Value(unit),
      brand: Value(brand),
      model: Value(model),
      description: Value(description),
      unitPriceMillimes: Value(unitPrice.millimes),
      supplier: Value(supplier),
      notes: Value(notes),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: Value(createdBy),
    );
  }
}

extension ItemCategoryRowMapper on ItemCategoryRow {
  ItemCategory toDomain() {
    return ItemCategory(
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

extension ItemCategoryMapper on ItemCategory {
  ItemCategoriesTableCompanion toCompanion() {
    return ItemCategoriesTableCompanion(
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
