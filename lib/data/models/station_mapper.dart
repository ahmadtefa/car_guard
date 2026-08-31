// lib/data/models/station_mapper.dart

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../domain/entities/station.dart';
import '../../core/utils/money.dart';

extension StationRowMapper on StationRow {
  Station toDomain() {
    return Station(
      id: id,
      stationNumber: stationNumber,
      name: name,
      customerId: customerId,
      address: address,
      latitude: latitude,
      longitude: longitude,
      landArea: landArea,
      roofArea: roofArea,
      availableArea: availableArea,
      projectType: projectType,
      requiredCapacityKwp: requiredCapacityKwp,
      totalPanelsCapacityKwp: totalPanelsCapacityKwp,
      status: status,
      responsiblePerson: responsiblePerson,
      notes: notes,
      sellingPrice: Money.fromMillimes(sellingPriceMillimes),
      discount: Money.fromMillimes(discountMillimes),
      taxPercentage: taxPercentage,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      revisionNumber: revisionNumber,
      lastModifiedAt: lastModifiedAt,
      lastModifiedBy: lastModifiedBy,
    );
  }
}

extension StationMapper on Station {
  StationsTableCompanion toCompanion() {
    return StationsTableCompanion(
      id: Value(id),
      stationNumber: Value(stationNumber),
      name: Value(name),
      customerId: Value(customerId),
      address: Value(address),
      latitude: Value(latitude),
      longitude: Value(longitude),
      landArea: Value(landArea),
      roofArea: Value(roofArea),
      availableArea: Value(availableArea),
      projectType: Value(projectType),
      requiredCapacityKwp: Value(requiredCapacityKwp),
      totalPanelsCapacityKwp: Value(totalPanelsCapacityKwp),
      status: Value(status),
      responsiblePerson: Value(responsiblePerson),
      notes: Value(notes),
      sellingPriceMillimes: Value(sellingPrice.millimes),
      discountMillimes: Value(discount.millimes),
      taxPercentage: Value(taxPercentage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: Value(createdBy),
      revisionNumber: Value(revisionNumber),
      lastModifiedAt: Value(lastModifiedAt),
      lastModifiedBy: Value(lastModifiedBy),
    );
  }
}
