// lib/domain/entities/expense_category.dart

import 'package:equatable/equatable.dart';

class ExpenseCategory extends Equatable {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? description;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;

  const ExpenseCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.description,
    this.sortOrder = 0,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
  });

  String get displayName => nameAr;

  ExpenseCategory copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? description,
    int? sortOrder,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, nameAr, nameEn, isActive];
}
