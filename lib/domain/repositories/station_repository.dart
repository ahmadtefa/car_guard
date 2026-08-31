// lib/domain/repositories/station_repository.dart

import '../entities/station.dart';
import '../entities/station_item.dart';
import '../entities/expense.dart';
import '../entities/financial_summary.dart';
import '../../core/utils/result.dart';

abstract class StationRepository {
  // Station CRUD
  Future<Result<List<Station>>> getAllStations();
  Future<Result<Station>> getStationById(String id);
  Future<Result<Station>> createStation(Station station);
  Future<Result<Station>> updateStation(Station station);
  Future<Result<void>> deleteStation(String id);

  // Search
  Future<Result<List<Station>>> searchStations({
    String? query,
    String? status,
    String? customerId,
  });

  // Station Items
  Future<Result<List<StationItem>>> getStationItems(String stationId);
  Future<Result<StationItem>> addStationItem(StationItem item);
  Future<Result<StationItem>> updateStationItem(StationItem item);
  Future<Result<void>> deleteStationItem(String itemId);

  // Expenses
  Future<Result<List<Expense>>> getStationExpenses(String stationId);
  Future<Result<Expense>> addExpense(Expense expense);
  Future<Result<Expense>> updateExpense(Expense expense);
  Future<Result<void>> deleteExpense(String expenseId);

  // Financial Summary (computed)
  Future<Result<FinancialSummary>> getFinancialSummary(String stationId);

  // Station number sequence
  Future<Result<String>> generateNextStationNumber();

  // Dashboard stats
  Future<Result<StationStats>> getStationStats();
}

class StationStats {
  final int totalStations;
  final int studyCount;
  final int underExecutionCount;
  final int completedCount;
  final int suspendedCount;
  final int cancelledCount;
  final double totalCapacityKwp;
  final int totalProjectsCostMillimes;
  final int totalSellingPriceMillimes;
  final int totalProfitMillimes;

  const StationStats({
    required this.totalStations,
    required this.studyCount,
    required this.underExecutionCount,
    required this.completedCount,
    required this.suspendedCount,
    required this.cancelledCount,
    required this.totalCapacityKwp,
    required this.totalProjectsCostMillimes,
    required this.totalSellingPriceMillimes,
    required this.totalProfitMillimes,
  });
}
