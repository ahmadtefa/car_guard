// lib/domain/entities/station_item.dart

import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/money.dart';

class StationItem extends Equatable {
  final String id;
  final String stationId;
  final String? itemId; // Reference to catalog - nullable for custom items
  final String description;
  final String? brand;
  final String? model;
  final String? unit;

  /// Quantity stored with 3 decimal precision (as milliunits)
  final int quantityMilliunits;

  /// PRICE SNAPSHOT - locked when item was added to station
  final Money unitPriceSnapshot;

  /// Discount percentage (0-100) with 2 decimal precision stored as cents
  final int discountPercentageCents;

  /// Tax percentage (0-100) with 2 decimal precision stored as cents
  final int taxPercentageCents;

  final String? notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? addedBy;

  const StationItem({
    required this.id,
    required this.stationId,
    this.itemId,
    required this.description,
    this.brand,
    this.model,
    this.unit,
    required this.quantityMilliunits,
    required this.unitPriceSnapshot,
    this.discountPercentageCents = 0,
    this.taxPercentageCents = 0,
    this.notes,
    this.sortOrder = 0,
    required this.createdAt,
    this.updatedAt,
    this.addedBy,
  });

  /// Quantity as decimal
  Decimal get quantity =>
      (Decimal.fromInt(quantityMilliunits) / Decimal.fromInt(1000))
          .toDecimal();

  /// Discount percentage as decimal
  Decimal get discountPercent =>
      (Decimal.fromInt(discountPercentageCents) / Decimal.fromInt(100))
          .toDecimal();

  /// Tax percentage as decimal
  Decimal get taxPercent =>
      (Decimal.fromInt(taxPercentageCents) / Decimal.fromInt(100))
          .toDecimal();

  /// Subtotal before discount and tax
  Money get subtotal {
    return unitPriceSnapshot.multiplyByDecimal(quantity);
  }

  /// Discount amount
  Money get discountAmount {
    if (discountPercentageCents == 0) return Money.fromMillimes(0);
    return subtotal.percentage(discountPercent);
  }

  /// After discount
  Money get afterDiscount => subtotal - discountAmount;

  /// Tax amount
  Money get taxAmount {
    if (taxPercentageCents == 0) return Money.fromMillimes(0);
    return afterDiscount.percentage(taxPercent);
  }

  /// Total = (Quantity × UnitPrice) - Discount + Tax
  Money get total => afterDiscount + taxAmount;

  /// Sentinel that lets [copyWith] distinguish "argument not provided"
  /// from "argument explicitly set to null" for nullable fields.
  static const _unset = Object();

  StationItem copyWith({
    String? id,
    String? stationId,
    Object? itemId = _unset,
    String? description,
    Object? brand = _unset,
    Object? model = _unset,
    Object? unit = _unset,
    int? quantityMilliunits,
    Money? unitPriceSnapshot,
    int? discountPercentageCents,
    int? taxPercentageCents,
    Object? notes = _unset,
    int? sortOrder,
    DateTime? createdAt,
    Object? updatedAt = _unset,
    Object? addedBy = _unset,
  }) {
    return StationItem(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      itemId: itemId == _unset ? this.itemId : itemId as String?,
      description: description ?? this.description,
      brand: brand == _unset ? this.brand : brand as String?,
      model: model == _unset ? this.model : model as String?,
      unit: unit == _unset ? this.unit : unit as String?,
      quantityMilliunits: quantityMilliunits ?? this.quantityMilliunits,
      unitPriceSnapshot: unitPriceSnapshot ?? this.unitPriceSnapshot,
      discountPercentageCents:
          discountPercentageCents ?? this.discountPercentageCents,
      taxPercentageCents: taxPercentageCents ?? this.taxPercentageCents,
      notes: notes == _unset ? this.notes : notes as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt:
          updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      addedBy: addedBy == _unset ? this.addedBy : addedBy as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        stationId,
        itemId,
        description,
        brand,
        model,
        unit,
        quantityMilliunits,
        unitPriceSnapshot,
        discountPercentageCents,
        taxPercentageCents,
        notes,
        sortOrder,
        createdAt,
        updatedAt,
        addedBy,
      ];
}
