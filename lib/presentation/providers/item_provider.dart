// lib/presentation/providers/item_provider.dart
import '../../core/constants/enums.dart';

import 'package:flutter/foundation.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/item_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/repositories/item_repository.dart';

// LoadState is imported from core/constants/enums.dart

class ItemProvider extends ChangeNotifier {
  final ItemRepository _itemRepo;
  final ExpenseCategoryRepository _expenseCatRepo;

  ItemProvider(this._itemRepo, this._expenseCatRepo);

  // Items
  List<CatalogItem> _items = [];
  List<ItemCategory> _itemCategories = [];
  List<ExpenseCategory> _expenseCategories = [];
  LoadState _state = LoadState.idle;
  String? _error;

  List<CatalogItem> get items => _items;
  List<ItemCategory> get itemCategories => _itemCategories;
  List<ExpenseCategory> get expenseCategories => _expenseCategories;
  LoadState get state => _state;
  String? get error => _error;

  Future<void> loadAll() async {
    _state = LoadState.loading;
    notifyListeners();

    final itemsResult = await _itemRepo.getAllItems();
    final catResult = await _itemRepo.getAllCategories();
    final expCatResult = await _expenseCatRepo.getAllCategories();

    if (itemsResult.isSuccess) _items = itemsResult.value;
    if (catResult.isSuccess) _itemCategories = catResult.value;
    if (expCatResult.isSuccess) _expenseCategories = expCatResult.value;

    _state = LoadState.loaded;
    notifyListeners();
  }

  Future<void> searchItems(String query) async {
    if (query.isEmpty) {
      final result = await _itemRepo.getAllItems();
      if (result.isSuccess) {
        _items = result.value;
        notifyListeners();
      }
      return;
    }
    final result = await _itemRepo.searchItems(query);
    if (result.isSuccess) {
      _items = result.value;
      notifyListeners();
    }
  }

  List<CatalogItem> getItemsByCategory(String categoryId) {
    return _items.where((i) => i.categoryId == categoryId).toList();
  }

  Future<bool> createItem(CatalogItem item) async {
    final result = await _itemRepo.createItem(item);
    if (result.isSuccess) {
      _items.add(result.value);
      notifyListeners();
      return true;
    }
    _error = result.failure.message;
    notifyListeners();
    return false;
  }

  Future<bool> updateItem(CatalogItem item) async {
    final result = await _itemRepo.updateItem(item);
    if (result.isSuccess) {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) _items[idx] = result.value;
      notifyListeners();
      return true;
    }
    _error = result.failure.message;
    notifyListeners();
    return false;
  }

  Future<bool> deleteItem(String id) async {
    final result = await _itemRepo.deleteItem(id);
    if (result.isSuccess) {
      _items.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    }
    return false;
  }

  // Categories
  Future<bool> createItemCategory(ItemCategory category) async {
    final result = await _itemRepo.createCategory(category);
    if (result.isSuccess) {
      _itemCategories.add(result.value);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> createExpenseCategory(ExpenseCategory category) async {
    final result = await _expenseCatRepo.createCategory(category);
    if (result.isSuccess) {
      _expenseCategories.add(result.value);
      notifyListeners();
      return true;
    }
    return false;
  }

  ItemCategory? getCategoryById(String id) {
    try {
      return _itemCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  ExpenseCategory? getExpenseCategoryById(String id) {
    try {
      return _expenseCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
