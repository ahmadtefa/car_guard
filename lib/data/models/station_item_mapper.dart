// lib/data/models/station_item_mapper.dart

import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../domain/entities/station_item.dart';
import '../../core/utils/money.dart';

extension StationItemRowMapper on StationItemRow {
  StationItem toDomain() {
    return StationItem(
      id: id,
      stationId: stationId,
      itemId: itemId,
      description: description,
      brand: brand,
      model: model,
      unit: unit,
      quantityMilliunits: quantityMilliunits,
      unitPriceSnapshot: Money.fromMillimes(unitPriceSnapshotMillimes),
      discountPercentageCents: discountPercentageCents,
      taxPercentageCents: taxPercentageCents,
      notes: notes,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
      addedBy: addedBy,
    );
  }
}

extension StationItemMapper on StationItem {
  StationItemsTableCompanion toCompanion() {
    return StationItemsTableCompanion(
      id: Value(id),
      stationId: Value(stationId),
      itemId: Value(itemId),
      description: Value(description),
      brand: Value(brand),
      model: Value(model),
      unit: Value(unit),
      quantityMilliunits: Value(quantityMilliunits),
      unitPriceSnapshotMillimes: Value(unitPriceSnapshot.millimes),
      discountPercentageCents: Value(discountPercentageCents),
      taxPercentageCents: Value(taxPercentageCents),
      notes: Value(notes),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      addedBy: Value(addedBy),
    );
  }
}
