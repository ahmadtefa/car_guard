// lib/domain/entities/expense.dart

import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/money.dart';

class Expense extends Equatable {
  /// Sentinel that lets [copyWith] distinguish "argument not provided"
  /// from "argument explicitly set to null" for nullable fields.
  static const _unset = Object();

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

  const Expense({
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
      (Decimal.fromInt(quantityMilliunits) / Decimal.fromInt(1000))
          .toDecimal();

  /// Total = Quantity × UnitPrice
  Money get total => unitPrice.multiplyByDecimal(quantity);

  Expense copyWith({
    String? id,
    String? stationId,
    DateTime? expenseDate,
    String? categoryId,
    String? description,
    int? quantityMilliunits,
    Object? unit = _unset,
    Money? unitPrice,
    Object? addedBy = _unset,
    Object? notes = _unset,
    DateTime? createdAt,
    Object? updatedAt = _unset,
  }) {
    return Expense(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      expenseDate: expenseDate ?? this.expenseDate,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      quantityMilliunits: quantityMilliunits ?? this.quantityMilliunits,
      unit: unit == _unset ? this.unit : unit as String?,
      unitPrice: unitPrice ?? this.unitPrice,
      addedBy: addedBy == _unset ? this.addedBy : addedBy as String?,
      notes: notes == _unset ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt:
          updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        stationId,
        expenseDate,
        categoryId,
        description,
        quantityMilliunits,
        unit,
        unitPrice,
        addedBy,
        notes,
        createdAt,
        updatedAt,
      ];
}
