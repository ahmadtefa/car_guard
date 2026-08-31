// test/unit/financial_summary_test.dart
// Tests for FinancialSummary entity

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_manager/core/utils/money.dart';
import 'package:solar_manager/domain/entities/financial_summary.dart';

void main() {
  FinancialSummary makeSummary({
    Money? materialCost,
    Money? laborCost,
    Money? transportationCost,
    Money? otherExpenses,
    Money? sellingPrice,
    Money? discount,
    int taxPercentage = 0,
  }) {
    return FinancialSummary(
      stationId: 'test-station',
      materialCost: materialCost ?? Money.fromInt(1250000),
      laborCost: laborCost ?? Money.fromInt(120000),
      transportationCost: transportationCost ?? Money.fromInt(35000),
      otherExpenses: otherExpenses ?? Money.fromInt(45000),
      sellingPrice: sellingPrice ?? Money.fromInt(1850000),
      discount: discount ?? Money.fromMillimes(0),
      taxPercentage: taxPercentage,
    );
  }

  group('FinancialSummary - Total Cost', () {
    test('total actual cost = material + labor + transport + other', () {
      final summary = makeSummary();
      // 1,250,000 + 120,000 + 35,000 + 45,000 = 1,450,000
      expect(summary.totalActualCost.toDouble, 1450000.0);
    });

    test('total expenses = labor + transportation + other', () {
      final summary = makeSummary();
      // 120,000 + 35,000 + 45,000 = 200,000
      expect(summary.totalExpenses.toDouble, 200000.0);
    });

    test('with zero labor', () {
      final summary = makeSummary(laborCost: Money.fromMillimes(0));
      expect(summary.laborCost.isZero, true);
    });
  });

  group('FinancialSummary - Selling Price', () {
    test('selling price after zero discount', () {
      final summary = makeSummary(
        sellingPrice: Money.fromInt(1850000),
        discount: Money.fromMillimes(0),
      );
      expect(summary.sellingPriceAfterDiscount.toDouble, 1850000.0);
    });

    test('selling price after discount', () {
      final summary = makeSummary(
        sellingPrice: Money.fromInt(1850000),
        discount: Money.fromInt(50000),
      );
      expect(summary.sellingPriceAfterDiscount.toDouble, 1800000.0);
    });

    test('zero tax gives no tax amount', () {
      final summary = makeSummary(taxPercentage: 0);
      expect(summary.taxAmount.isZero, true);
    });

    test('14% tax calculation', () {
      final summary = makeSummary(
        sellingPrice: Money.fromInt(1000000),
        discount: Money.fromMillimes(0),
        taxPercentage: 14,
      );
      // 1,000,000 × 14% = 140,000
      expect(summary.taxAmount.toDouble, closeTo(140000.0, 1.0));
    });

    test('net selling value with tax', () {
      final summary = makeSummary(
        sellingPrice: Money.fromInt(1000000),
        discount: Money.fromMillimes(0),
        taxPercentage: 14,
      );
      // 1,000,000 + 140,000 = 1,140,000
      expect(summary.netSellingValue.toDouble, closeTo(1140000.0, 1.0));
    });
  });

  group('FinancialSummary - Profit', () {
    test('profit = netSelling - totalCost', () {
      final summary = makeSummary(
        materialCost: Money.fromInt(1250000),
        laborCost: Money.fromInt(120000),
        transportationCost: Money.fromInt(35000),
        otherExpenses: Money.fromInt(45000),
        sellingPrice: Money.fromInt(1850000),
        discount: Money.fromMillimes(0),
        taxPercentage: 0,
      );
      // netSelling = 1,850,000, totalCost = 1,450,000
      // profit = 400,000
      expect(summary.profit.toDouble, 400000.0);
    });

    test('is profitable when profit > 0', () {
      final summary = makeSummary();
      expect(summary.isProfitable, true);
    });

    test('is not profitable when cost > selling', () {
      final summary = makeSummary(
        sellingPrice: Money.fromInt(1000000),
        materialCost: Money.fromInt(1200000),
        laborCost: Money.fromMillimes(0),
        transportationCost: Money.fromMillimes(0),
        otherExpenses: Money.fromMillimes(0),
      );
      expect(summary.isProfitable, false);
    });

    test('profit margin calculation - example from spec', () {
      // From spec: Material 1,250,000 + Labor 120,000 + Transport 35,000 + Other 45,000
      // Total Cost = 1,450,000
      // Selling = 1,850,000
      // Profit = 400,000
      // Margin = 400,000 / 1,850,000 × 100 = 21.62%
      final summary = makeSummary(
        materialCost: Money.fromInt(1250000),
        laborCost: Money.fromInt(120000),
        transportationCost: Money.fromInt(35000),
        otherExpenses: Money.fromInt(45000),
        sellingPrice: Money.fromInt(1850000),
        discount: Money.fromMillimes(0),
        taxPercentage: 0,
      );
      expect(summary.profitMarginPercent.toDouble, closeTo(21.62, 0.01));
    });

    test('zero selling price gives zero margin', () {
      final summary = makeSummary(
        sellingPrice: Money.fromMillimes(0),
        discount: Money.fromMillimes(0),
        taxPercentage: 0,
      );
      expect(summary.profitMarginPercent, equals(Decimal.zero));
    });
  });

  group('FinancialSummary - Edge Cases', () {
    test('all zeros', () {
      final summary = makeSummary(
        materialCost: Money.fromMillimes(0),
        laborCost: Money.fromMillimes(0),
        transportationCost: Money.fromMillimes(0),
        otherExpenses: Money.fromMillimes(0),
        sellingPrice: Money.fromMillimes(0),
        discount: Money.fromMillimes(0),
        taxPercentage: 0,
      );
      expect(summary.totalActualCost.isZero, true);
      expect(summary.profit.isZero, true);
      expect(summary.profitMarginPercent, equals(Decimal.zero));
    });

    test('large amounts do not overflow', () {
      // 100 million EGP
      final summary = makeSummary(
        materialCost: Money.fromInt(100000000),
        sellingPrice: Money.fromInt(120000000),
        laborCost: Money.fromMillimes(0),
        transportationCost: Money.fromMillimes(0),
        otherExpenses: Money.fromMillimes(0),
      );
      expect(summary.profit.toDouble, 20000000.0);
    });
  });
}
