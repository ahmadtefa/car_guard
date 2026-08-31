// test/unit/station_item_test.dart
// Tests for StationItem entity calculations

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_manager/core/utils/money.dart';
import 'package:solar_manager/domain/entities/station_item.dart';

void main() {
  StationItem makeItem({
    int quantityMilliunits = 1000, // 1 unit
    int priceMillimes = 8500000, // 8500 EGP
    int discountCents = 0, // 0%
    int taxCents = 0, // 0%
  }) {
    return StationItem(
      id: 'test-id',
      stationId: 'station-1',
      description: 'Test Item',
      quantityMilliunits: quantityMilliunits,
      unitPriceSnapshot: Money.fromMillimes(priceMillimes),
      discountPercentageCents: discountCents,
      taxPercentageCents: taxCents,
      createdAt: DateTime.now(),
    );
  }

  group('StationItem - Basic Calculations', () {
    test('subtotal = qty × price (1 unit)', () {
      final item = makeItem(quantityMilliunits: 1000, priceMillimes: 8500000);
      expect(item.subtotal.toDouble, 8500.0);
    });

    test('subtotal = qty × price (10 units)', () {
      final item = makeItem(quantityMilliunits: 10000, priceMillimes: 8500000);
      expect(item.subtotal.toDouble, 85000.0);
    });

    test('subtotal with decimal quantity', () {
      // 2.5 units × 1000 EGP = 2500 EGP
      final item = makeItem(quantityMilliunits: 2500, priceMillimes: 1000000);
      expect(item.subtotal.toDouble, 2500.0);
    });

    test('total without discount or tax = subtotal', () {
      final item = makeItem(quantityMilliunits: 5000, priceMillimes: 1000000);
      expect(item.total.toDouble, item.subtotal.toDouble);
    });
  });

  group('StationItem - Discount', () {
    test('10% discount on 85000 = 76500', () {
      final item = makeItem(
        quantityMilliunits: 10000, // 10 units
        priceMillimes: 8500000, // 8500 EGP each
        discountCents: 1000, // 10.00%
      );
      expect(item.subtotal.toDouble, 85000.0);
      expect(item.discountAmount.toDouble, 8500.0);
      expect(item.afterDiscount.toDouble, 76500.0);
      expect(item.total.toDouble, 76500.0);
    });

    test('0% discount changes nothing', () {
      final item = makeItem(discountCents: 0);
      expect(item.discountAmount.isZero, true);
      expect(item.total, equals(item.subtotal));
    });

    test('50% discount halves the price', () {
      final item = makeItem(
        quantityMilliunits: 1000,
        priceMillimes: 1000000, // 1000 EGP
        discountCents: 5000, // 50%
      );
      expect(item.afterDiscount.toDouble, 500.0);
    });
  });

  group('StationItem - Tax', () {
    test('14% tax on 85000', () {
      final item = makeItem(
        quantityMilliunits: 10000,
        priceMillimes: 8500000,
        taxCents: 1400, // 14.00%
      );
      expect(item.subtotal.toDouble, 85000.0);
      expect(item.taxAmount.toDouble, closeTo(11900.0, 0.01));
      expect(item.total.toDouble, closeTo(96900.0, 0.01));
    });

    test('0% tax adds nothing', () {
      final item = makeItem(taxCents: 0);
      expect(item.taxAmount.isZero, true);
    });
  });

  group('StationItem - Discount + Tax combined', () {
    test('10% discount then 14% tax', () {
      // 85000 - 8500 (10%) = 76500
      // 76500 × 14% = 10710
      // Total = 76500 + 10710 = 87210
      final item = makeItem(
        quantityMilliunits: 10000,
        priceMillimes: 8500000,
        discountCents: 1000, // 10%
        taxCents: 1400, // 14%
      );
      expect(item.afterDiscount.toDouble, 76500.0);
      expect(item.taxAmount.toDouble, closeTo(10710.0, 0.1));
      expect(item.total.toDouble, closeTo(87210.0, 0.1));
    });
  });

  group('StationItem - Price Snapshot Immutability', () {
    test('snapshot price is independent of catalog changes', () {
      // Simulate: item added at 8500, catalog updated to 9200
      final snapshotPrice = Money.fromInt(8500);
      final updatedCatalogPrice = Money.fromInt(9200);

      final item = StationItem(
        id: 'id',
        stationId: 'st-1',
        description: 'Panel',
        quantityMilliunits: 10000, // 10 units
        unitPriceSnapshot: snapshotPrice, // locked at 8500
        createdAt: DateTime.now(),
      );

      // Even though catalog changed, snapshot is preserved
      expect(item.unitPriceSnapshot.toDouble, 8500.0);
      expect(item.unitPriceSnapshot, isNot(equals(updatedCatalogPrice)));
      expect(item.total.toDouble, 85000.0); // 10 × 8500
    });
  });
}
