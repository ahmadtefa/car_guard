// lib/domain/entities/station.dart

import 'package:equatable/equatable.dart';
import '../../core/utils/money.dart';

class Station extends Equatable {
  final String id;
  final String stationNumber;
  final String name;
  final String? customerId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? landArea;
  final double? roofArea;
  final double? availableArea;
  final String? projectType;
  final double? requiredCapacityKwp;
  final double? totalPanelsCapacityKwp;
  final String status;
  final String? responsiblePerson;
  final String? notes;
  final Money sellingPrice;
  final Money discount;
  final int taxPercentage; // 0-100
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final int revisionNumber;
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;

  Station({
    required this.id,
    required this.stationNumber,
    required this.name,
    this.customerId,
    this.address,
    this.latitude,
    this.longitude,
    this.landArea,
    this.roofArea,
    this.availableArea,
    this.projectType,
    this.requiredCapacityKwp,
    this.totalPanelsCapacityKwp,
    this.status = 'study',
    this.responsiblePerson,
    this.notes,
    Money? sellingPrice,
    Money? discount,
    this.taxPercentage = 0,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.revisionNumber = 1,
    this.lastModifiedAt,
    this.lastModifiedBy,
  })  : sellingPrice = sellingPrice ?? Money.fromMillimes(0),
        discount = discount ?? Money.fromMillimes(0);

  String? get googleMapsUrl {
    if (latitude == null || longitude == null) return null;
    return 'https://www.google.com/maps?q=$latitude,$longitude';
  }

  Station copyWith({
    String? id,
    String? stationNumber,
    String? name,
    String? customerId,
    String? address,
    double? latitude,
    double? longitude,
    double? landArea,
    double? roofArea,
    double? availableArea,
    String? projectType,
    double? requiredCapacityKwp,
    double? totalPanelsCapacityKwp,
    String? status,
    String? responsiblePerson,
    String? notes,
    Money? sellingPrice,
    Money? discount,
    int? taxPercentage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? revisionNumber,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return Station(
      id: id ?? this.id,
      stationNumber: stationNumber ?? this.stationNumber,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      landArea: landArea ?? this.landArea,
      roofArea: roofArea ?? this.roofArea,
      availableArea: availableArea ?? this.availableArea,
      projectType: projectType ?? this.projectType,
      requiredCapacityKwp: requiredCapacityKwp ?? this.requiredCapacityKwp,
      totalPanelsCapacityKwp:
          totalPanelsCapacityKwp ?? this.totalPanelsCapacityKwp,
      status: status ?? this.status,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      notes: notes ?? this.notes,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      discount: discount ?? this.discount,
      taxPercentage: taxPercentage ?? this.taxPercentage,
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
        stationNumber,
        name,
        customerId,
        status,
        latitude,
        longitude,
        revisionNumber,
      ];
}
