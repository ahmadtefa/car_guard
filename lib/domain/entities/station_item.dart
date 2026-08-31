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
      Decimal.fromInt(quantityMilliunits) / Decimal.fromInt(1000);

  /// Discount percentage as decimal
  Decimal get discountPercent =>
      Decimal.fromInt(discountPercentageCents) / Decimal.fromInt(100);

  /// Tax percentage as decimal
  Decimal get taxPercent =>
      Decimal.fromInt(taxPercentageCents) / Decimal.fromInt(100);

  /// Subtotal before discount and tax
  Money get subtotal {
    return unitPriceSnapshot.multiplyByDecimal(quantity);
  }

  /// Discount amount
  Money get discountAmount {
    if (discountPercentageCents == 0) return Money.fromMillimes(0);
    return subtotal.multiplyByDecimal(discountPercent / Decimal.fromInt(100));
  }

  /// After discount
  Money get afterDiscount => subtotal - discountAmount;

  /// Tax amount
  Money get taxAmount {
    if (taxPercentageCents == 0) return Money.fromMillimes(0);
    return afterDiscount.multiplyByDecimal(taxPercent / Decimal.fromInt(100));
  }

  /// Total = (Quantity × UnitPrice) - Discount + Tax
  Money get total => afterDiscount + taxAmount;

  StationItem copyWith({
    String? id,
    String? stationId,
    String? itemId,
    String? description,
    String? brand,
    String? model,
    String? unit,
    int? quantityMilliunits,
    Money? unitPriceSnapshot,
    int? discountPercentageCents,
    int? taxPercentageCents,
    String? notes,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? addedBy,
  }) {
    return StationItem(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      itemId: itemId ?? this.itemId,
      description: description ?? this.description,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      unit: unit ?? this.unit,
      quantityMilliunits: quantityMilliunits ?? this.quantityMilliunits,
      unitPriceSnapshot: unitPriceSnapshot ?? this.unitPriceSnapshot,
      discountPercentageCents:
          discountPercentageCents ?? this.discountPercentageCents,
      taxPercentageCents: taxPercentageCents ?? this.taxPercentageCents,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedBy: addedBy ?? this.addedBy,
    );
  }

  @override
  List<Object?> get props => [id, stationId, itemId, description, quantityMilliunits, unitPriceSnapshot];
}
