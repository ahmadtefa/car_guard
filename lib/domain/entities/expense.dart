// lib/domain/entities/expense.dart

import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/money.dart';

class Expense extends Equatable {
  final String id;
  final String stationId;
  final DateTime expenseDate;
  final String categoryId;
  final String description;

  /// Quantity with 3 decimal places (stored as milliunits)
  final int quantityMilliunits;

  final String? unit;
  final Money unitPrice;
  final String? addedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.stationId,
    required this.expenseDate,
    required this.categoryId,
    required this.description,
    required this.quantityMilliunits,
    this.unit,
    required this.unitPrice,
    this.addedBy,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  Decimal get quantity =>
      Decimal.fromInt(quantityMilliunits) / Decimal.fromInt(1000);

  /// Total = Quantity × UnitPrice
  Money get total => unitPrice.multiplyByDecimal(quantity);

  Expense copyWith({
    String? id,
    String? stationId,
    DateTime? expenseDate,
    String? categoryId,
    String? description,
    int? quantityMilliunits,
    String? unit,
    Money? unitPrice,
    String? addedBy,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      expenseDate: expenseDate ?? this.expenseDate,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      quantityMilliunits: quantityMilliunits ?? this.quantityMilliunits,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      addedBy: addedBy ?? this.addedBy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, stationId, categoryId, description, quantityMilliunits, unitPrice];
}
