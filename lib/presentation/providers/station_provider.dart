// lib/presentation/providers/station_provider.dart
import '../../core/constants/enums.dart';

import 'package:flutter/foundation.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/financial_summary.dart';
import '../../domain/entities/station.dart';
import '../../domain/entities/station_item.dart';
import '../../domain/repositories/station_repository.dart';

// LoadState is imported from core/constants/enums.dart

class StationProvider extends ChangeNotifier {
  final StationRepository _repo;

  StationProvider(this._repo);

  // ---- Stations list ----
  List<Station> _stations = [];
  LoadState _stationsState = LoadState.idle;
  String? _stationsError;

  List<Station> get stations => _stations;
  LoadState get stationsState => _stationsState;
  String? get stationsError => _stationsError;

  // ---- Station Detail ----
  Station? _currentStation;
  List<StationItem> _currentItems = [];
  List<Expense> _currentExpenses = [];
  FinancialSummary? _financialSummary;
  LoadState _detailState = LoadState.idle;
  String? _detailError;

  Station? get currentStation => _currentStation;
  List<StationItem> get currentItems => _currentItems;
  List<Expense> get currentExpenses => _currentExpenses;
  FinancialSummary? get financialSummary => _financialSummary;
  LoadState get detailState => _detailState;
  String? get detailError => _detailError;

  // ---- Stats ----
  StationStats? _stats;
  StationStats? get stats => _stats;

  // ========== STATION LIST ==========

  Future<void> loadStations({String? query, String? status}) async {
    _stationsState = LoadState.loading;
    _stationsError = null;
    notifyListeners();

    final result = await _repo.searchStations(query: query, status: status);
    result.fold(
      onSuccess: (list) {
        _stations = list;
        _stationsState = LoadState.loaded;
      },
      onFailure: (f) {
        _stationsError = f.message;
        _stationsState = LoadState.error;
      },
    );
    notifyListeners();
  }

  Future<void> loadStats() async {
    final result = await _repo.getStationStats();
    result.fold(
      onSuccess: (s) => _stats = s,
      onFailure: (_) {},
    );
    notifyListeners();
  }

  // ========== STATION DETAIL ==========

  Future<void> loadStationDetail(String stationId) async {
    _detailState = LoadState.loading;
    _detailError = null;
    notifyListeners();

    final stationResult = await _repo.getStationById(stationId);
    if (stationResult.isFailure) {
      _detailError = stationResult.failure.message;
      _detailState = LoadState.error;
      notifyListeners();
      return;
    }

    _currentStation = stationResult.value;

    final itemsResult = await _repo.getStationItems(stationId);
    _currentItems =
        itemsResult.isSuccess ? itemsResult.value : [];

    final expensesResult = await _repo.getStationExpenses(stationId);
    _currentExpenses =
        expensesResult.isSuccess ? expensesResult.value : [];

    await _reloadFinancialSummary(stationId);

    _detailState = LoadState.loaded;
    notifyListeners();
  }

  Future<void> _reloadFinancialSummary(String stationId) async {
    final result = await _repo.getFinancialSummary(stationId);
    if (result.isSuccess) {
      _financialSummary = result.value;
    }
  }

  // ========== CRUD ==========

  Future<bool> createStation(Station station) async {
    final result = await _repo.createStation(station);
    if (result.isSuccess) {
      await loadStations();
      await loadStats();
      return true;
    }
    _stationsError = result.failure.message;
    notifyListeners();
    return false;
  }

  Future<bool> updateStation(Station station) async {
    final result = await _repo.updateStation(station);
    if (result.isSuccess) {
      _currentStation = result.value;
      // Update in list
      final idx = _stations.indexWhere((s) => s.id == station.id);
      if (idx >= 0) _stations[idx] = result.value;
      await _reloadFinancialSummary(station.id);
      notifyListeners();
      return true;
    }
    _detailError = result.failure.message;
    notifyListeners();
    return false;
  }

  Future<bool> deleteStation(String id) async {
    final result = await _repo.deleteStation(id);
    if (result.isSuccess) {
      _stations.removeWhere((s) => s.id == id);
      if (_currentStation?.id == id) _currentStation = null;
      await loadStats();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<String> generateStationNumber() async {
    final result = await _repo.generateNextStationNumber();
    return result.isSuccess ? result.value : 'ST-0001';
  }

  // ========== ITEMS ==========

  Future<bool> addStationItem(StationItem item) async {
    final result = await _repo.addStationItem(item);
    if (result.isSuccess) {
      _currentItems.add(result.value);
      await _reloadFinancialSummary(item.stationId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateStationItem(StationItem item) async {
    final result = await _repo.updateStationItem(item);
    if (result.isSuccess) {
      final idx = _currentItems.indexWhere((i) => i.id == item.id);
      if (idx >= 0) _currentItems[idx] = result.value;
      await _reloadFinancialSummary(item.stationId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteStationItem(String itemId, String stationId) async {
    final result = await _repo.deleteStationItem(itemId);
    if (result.isSuccess) {
      _currentItems.removeWhere((i) => i.id == itemId);
      await _reloadFinancialSummary(stationId);
      notifyListeners();
      return true;
    }
    return false;
  }

  // ========== EXPENSES ==========

  Future<bool> addExpense(Expense expense) async {
    final result = await _repo.addExpense(expense);
    if (result.isSuccess) {
      _currentExpenses.add(result.value);
      await _reloadFinancialSummary(expense.stationId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateExpense(Expense expense) async {
    final result = await _repo.updateExpense(expense);
    if (result.isSuccess) {
      final idx = _currentExpenses.indexWhere((e) => e.id == expense.id);
      if (idx >= 0) _currentExpenses[idx] = result.value;
      await _reloadFinancialSummary(expense.stationId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteExpense(String expenseId, String stationId) async {
    final result = await _repo.deleteExpense(expenseId);
    if (result.isSuccess) {
      _currentExpenses.removeWhere((e) => e.id == expenseId);
      await _reloadFinancialSummary(stationId);
      notifyListeners();
      return true;
    }
    return false;
  }
}
