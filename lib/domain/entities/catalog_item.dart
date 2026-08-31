// lib/domain/entities/catalog_item.dart

import 'package:equatable/equatable.dart';
import '../../core/utils/money.dart';

class CatalogItem extends Equatable {
  final String id;
  final String name;
  final String categoryId;
  final String? unit;
  final String? brand;
  final String? model;
  final String? description;
  final Money unitPrice;
  final String? supplier;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  CatalogItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.unit,
    this.brand,
    this.model,
    this.description,
    Money? unitPrice,
    this.supplier,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  }) : unitPrice = unitPrice ?? Money.fromMillimes(0);

  CatalogItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? unit,
    String? brand,
    String? model,
    String? description,
    Money? unitPrice,
    String? supplier,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      unit: unit ?? this.unit,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  List<Object?> get props => [id, name, categoryId, unitPrice, isActive];
}
