// lib/data/repositories/station_repository_impl.dart

import 'package:drift/drift.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/financial_summary.dart';
import '../../domain/entities/station.dart';
import '../../domain/entities/station_item.dart';
import '../../domain/repositories/station_repository.dart';
import '../database/app_database.dart';
import '../models/expense_mapper.dart';
import '../models/station_item_mapper.dart';
import '../models/station_mapper.dart';

class StationRepositoryImpl implements StationRepository {
  final AppDatabase _db;

  StationRepositoryImpl(this._db);

  // ========== STATION CRUD ==========

  @override
  Future<Result<List<Station>>> getAllStations() async {
    try {
      final rows = await (_db.select(_db.stationsTable)
            ..where((t) => t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get stations: $e'));
    }
  }

  @override
  Future<Result<Station>> getStationById(String id) async {
    try {
      final row = await (_db.select(_db.stationsTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        return Result.failure(const NotFoundFailure('Station not found'));
      }
      return Result.success(row.toDomain());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get station: $e'));
    }
  }

  @override
  Future<Result<Station>> createStation(Station station) async {
    try {
      final now = DateTime.now();
      final newStation = station.copyWith(
        id: station.id.isEmpty ? IdGenerator.generate() : station.id,
        createdAt: now,
        lastModifiedAt: now,
        revisionNumber: 1,
      );
      await _db.into(_db.stationsTable).insert(newStation.toCompanion());
      return Result.success(newStation);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to create station: $e'));
    }
  }

  @override
  Future<Result<Station>> updateStation(Station station) async {
    try {
      final now = DateTime.now();
      final updated = station.copyWith(
        updatedAt: now,
        lastModifiedAt: now,
        revisionNumber: station.revisionNumber + 1,
      );
      await (_db.update(_db.stationsTable)
            ..where((t) => t.id.equals(station.id)))
          .write(updated.toCompanion());
      return Result.success(updated);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update station: $e'));
    }
  }

  @override
  Future<Result<void>> deleteStation(String id) async {
    try {
      await (_db.update(_db.stationsTable)..where((t) => t.id.equals(id)))
          .write(const StationsTableCompanion(isDeleted: Value(true)));
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete station: $e'));
    }
  }

  @override
  Future<Result<List<Station>>> searchStations({
    String? query,
    String? status,
    String? customerId,
  }) async {
    try {
      final stmt = _db.select(_db.stationsTable)
        ..where((t) => t.isDeleted.equals(false));

      if (status != null && status.isNotEmpty) {
        stmt.where((t) => t.status.equals(status));
      }
      if (customerId != null && customerId.isNotEmpty) {
        stmt.where((t) => t.customerId.equals(customerId));
      }

      stmt.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      var rows = await stmt.get();

      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        rows = rows
            .where((r) =>
                r.name.toLowerCase().contains(q) ||
                r.stationNumber.toLowerCase().contains(q) ||
                (r.address?.toLowerCase().contains(q) ?? false))
            .toList();
      }

      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to search stations: $e'));
    }
  }

  // ========== STATION ITEMS ==========

  @override
  Future<Result<List<StationItem>>> getStationItems(String stationId) async {
    try {
      final rows = await (_db.select(_db.stationItemsTable)
            ..where((t) => t.stationId.equals(stationId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get station items: $e'));
    }
  }

  @override
  Future<Result<StationItem>> addStationItem(StationItem item) async {
    try {
      final now = DateTime.now();
      final newItem = item.copyWith(
        id: item.id.isEmpty ? IdGenerator.generate() : item.id,
        createdAt: now,
      );
      await _db.into(_db.stationItemsTable).insert(newItem.toCompanion());
      return Result.success(newItem);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to add station item: $e'));
    }
  }

  @override
  Future<Result<StationItem>> updateStationItem(StationItem item) async {
    try {
      final now = DateTime.now();
      final updated = item.copyWith(updatedAt: now);
      await (_db.update(_db.stationItemsTable)
            ..where((t) => t.id.equals(item.id)))
          .write(updated.toCompanion());
      return Result.success(updated);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update station item: $e'));
    }
  }

  @override
  Future<Result<void>> deleteStationItem(String itemId) async {
    try {
      await (_db.delete(_db.stationItemsTable)
            ..where((t) => t.id.equals(itemId)))
          .go();
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete station item: $e'));
    }
  }

  // ========== EXPENSES ==========

  @override
  Future<Result<List<Expense>>> getStationExpenses(String stationId) async {
    try {
      final rows = await (_db.select(_db.expensesTable)
            ..where((t) => t.stationId.equals(stationId))
            ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
          .get();
      return Result.success(rows.map((r) => r.toDomain()).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get expenses: $e'));
    }
  }

  @override
  Future<Result<Expense>> addExpense(Expense expense) async {
    try {
      final now = DateTime.now();
      final newExpense = expense.copyWith(
        id: expense.id.isEmpty ? IdGenerator.generate() : expense.id,
        createdAt: now,
      );
      await _db.into(_db.expensesTable).insert(newExpense.toCompanion());
      return Result.success(newExpense);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to add expense: $e'));
    }
  }

  @override
  Future<Result<Expense>> updateExpense(Expense expense) async {
    try {
      final now = DateTime.now();
      final updated = expense.copyWith(updatedAt: now);
      await (_db.update(_db.expensesTable)
            ..where((t) => t.id.equals(expense.id)))
          .write(updated.toCompanion());
      return Result.success(updated);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update expense: $e'));
    }
  }

  @override
  Future<Result<void>> deleteExpense(String expenseId) async {
    try {
      await (_db.delete(_db.expensesTable)
            ..where((t) => t.id.equals(expenseId)))
          .go();
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete expense: $e'));
    }
  }

  // ========== FINANCIAL SUMMARY ==========

  @override
  Future<Result<FinancialSummary>> getFinancialSummary(String stationId) async {
    try {
      // Get station
      final stationResult = await getStationById(stationId);
      if (stationResult.isFailure) {
        return Result.failure(stationResult.failure);
      }
      final station = stationResult.value;

      // Get all station items
      final itemsResult = await getStationItems(stationId);
      if (itemsResult.isFailure) {
        return Result.failure(itemsResult.failure);
      }
      final items = itemsResult.value;

      // Get all expenses
      final expensesResult = await getStationExpenses(stationId);
      if (expensesResult.isFailure) {
        return Result.failure(expensesResult.failure);
      }
      final expenses = expensesResult.value;

      // Calculate material cost from items
      Money materialCost = Money.fromMillimes(0);
      for (final item in items) {
        materialCost = materialCost + item.total;
      }

      // Separate expenses by category
      Money laborCost = Money.fromMillimes(0);
      Money transportationCost = Money.fromMillimes(0);
      Money otherExpenses = Money.fromMillimes(0);

      for (final expense in expenses) {
        final total = expense.total;
        if (expense.categoryId == 'labor') {
          laborCost = laborCost + total;
        } else if (expense.categoryId == 'transportation') {
          transportationCost = transportationCost + total;
        } else {
          otherExpenses = otherExpenses + total;
        }
      }

      final summary = FinancialSummary(
        stationId: stationId,
        materialCost: materialCost,
        laborCost: laborCost,
        transportationCost: transportationCost,
        otherExpenses: otherExpenses,
        sellingPrice: station.sellingPrice,
        discount: station.discount,
        taxPercentage: station.taxPercentage,
      );

      return Result.success(summary);
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to calculate financial summary: $e'));
    }
  }

  // ========== STATION NUMBER ==========

  @override
  Future<Result<String>> generateNextStationNumber() async {
    try {
      final count = await _db.customSelect(
        'SELECT COUNT(*) as cnt FROM stations',
      ).getSingle();
      final nextSeq = (count.read<int>('cnt')) + 1;
      return Result.success(IdGenerator.generateStationNumber(nextSeq));
    } catch (e) {
      return Result.failure(
          DatabaseFailure('Failed to generate station number: $e'));
    }
  }

  // ========== STATS ==========

  @override
  Future<Result<StationStats>> getStationStats() async {
    try {
      final stations = await (_db.select(_db.stationsTable)
            ..where((t) => t.isDeleted.equals(false)))
          .get();

      int study = 0;
      int underExecution = 0;
      int completed = 0;
      int suspended = 0;
      int cancelled = 0;
      double totalKwp = 0;

      for (final s in stations) {
        switch (s.status) {
          case 'study':
          case 'inspection':
          case 'pricing':
          case 'quotation':
          case 'contracted':
            study++;
            break;
          case 'under_execution':
            underExecution++;
            break;
          case 'completed':
            completed++;
            break;
          case 'suspended':
            suspended++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
        totalKwp += s.totalPanelsCapacityKwp ?? s.requiredCapacityKwp ?? 0;
      }

      return Result.success(StationStats(
        totalStations: stations.length,
        studyCount: study,
        underExecutionCount: underExecution,
        completedCount: completed,
        suspendedCount: suspended,
        cancelledCount: cancelled,
        totalCapacityKwp: totalKwp,
        totalProjectsCostMillimes: 0, // computed separately
        totalSellingPriceMillimes: stations.fold(
            0, (sum, s) => sum + s.sellingPriceMillimes),
        totalProfitMillimes: 0, // computed separately
      ));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get stats: $e'));
    }
  }
}
