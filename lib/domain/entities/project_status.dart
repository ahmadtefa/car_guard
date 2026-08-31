// lib/domain/entities/project_status.dart

import 'package:equatable/equatable.dart';

class ProjectStatus extends Equatable {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? colorHex;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;

  const ProjectStatus({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.colorHex,
    this.sortOrder = 0,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
  });

  String get displayName => nameAr;

  ProjectStatus copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? colorHex,
    int? sortOrder,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ProjectStatus(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, nameAr, nameEn, isActive];
}
