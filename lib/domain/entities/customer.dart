// lib/domain/entities/customer.dart

import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final String? phoneAlt;
  final String? email;
  final String? address;
  final String? governorate;
  final String? city;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final int revisionNumber;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.phoneAlt,
    this.email,
    this.address,
    this.governorate,
    this.city,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.revisionNumber = 1,
    this.lastModifiedAt,
    this.lastModifiedBy,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? phoneAlt,
    String? email,
    String? address,
    String? governorate,
    String? city,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? revisionNumber,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phoneAlt: phoneAlt ?? this.phoneAlt,
      email: email ?? this.email,
      address: address ?? this.address,
      governorate: governorate ?? this.governorate,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        phoneAlt,
        email,
        address,
        governorate,
        city,
        notes,
        createdAt,
        updatedAt,
        revisionNumber,
      ];
}
