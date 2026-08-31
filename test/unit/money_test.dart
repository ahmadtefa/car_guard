// test/unit/money_test.dart
// Tests for financial calculations - Money class

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_manager/core/utils/money.dart';

void main() {
  group('Money - Basic Operations', () {
    test('fromMillimes creates correct value', () {
      final m = Money.fromMillimes(1000);
      expect(m.millimes, 1000);
      expect(m.toDouble, 1.0);
    });

    test('fromInt creates correct value', () {
      final m = Money.fromInt(100);
      expect(m.millimes, 100000);
      expect(m.toDouble, 100.0);
    });

    test('fromDouble creates correct value', () {
      final m = Money.fromDouble(1850.5);
      expect(m.millimes, 1850500);
    });

    test('fromDecimal creates correct value', () {
      final m = Money.fromDecimal(Decimal.parse('9200'));
      expect(m.millimes, 9200000);
      expect(m.toDouble, 9200.0);
    });

    test('addition works correctly', () {
      final a = Money.fromInt(1000);
      final b = Money.fromInt(250);
      final result = a + b;
      expect(result.millimes, 1250000);
      expect(result.toDouble, 1250.0);
    });

    test('subtraction works correctly', () {
      final a = Money.fromInt(1000);
      final b = Money.fromInt(250);
      final result = a - b;
      expect(result.millimes, 750000);
    });

    test('negation works correctly', () {
      final m = Money.fromInt(100);
      final neg = -m;
      expect(neg.millimes, -100000);
      expect(neg.isNegative, true);
    });

    test('equality works', () {
      final a = Money.fromInt(500);
      final b = Money.fromMillimes(500000);
      expect(a, equals(b));
    });

    test('zero is zero', () {
      final m = Money.fromMillimes(0);
      expect(m.isZero, true);
      expect(m.isPositive, false);
      expect(m.isNegative, false);
    });
  });

  group('Money - Multiplication', () {
    test('multiplyByInt works', () {
      final price = Money.fromInt(100); // 100 EGP
      final result = price.multiplyByInt(10); // 10 units
      expect(result.toDouble, 1000.0);
    });

    test('multiplyByDecimal works for quantity', () {
      final price = Money.fromInt(100); // 100 EGP per unit
      final qty = Decimal.parse('2.5'); // 2.5 units
      final result = price.multiplyByDecimal(qty);
      expect(result.toDouble, 250.0);
    });

    test('percentage calculation', () {
      final amount = Money.fromInt(1000);
      final tenPercent = amount.percentage(Decimal.fromInt(10));
      expect(tenPercent.toDouble, 100.0);
    });

    test('percentage with decimal', () {
      final amount = Money.fromInt(1000);
      final result = amount.percentage(Decimal.parse('14.0'));
      expect(result.toDouble, 140.0);
    });
  });

  group('Money - Formatting', () {
    test('format with symbol', () {
      final m = Money.fromInt(1500);
      final formatted = m.format();
      expect(formatted.contains('1,500'), true);
      expect(formatted.contains('ج.م'), true);
    });

    test('format without symbol returns bare number', () {
      expect(Money.fromInt(1500).format(showSymbol: false), '1,500');
    });

    test('format keeps millime precision (up to 3 decimals)', () {
      expect(Money.fromMillimes(1500500).format(showSymbol: false), '1,500.5');
      expect(Money.fromMillimes(500).format(showSymbol: false), '0.5');
    });

    test('formatWhole rounds correctly', () {
      final m = Money.fromMillimes(1500500); // 1500.5 EGP
      final formatted = m.formatWhole(showSymbol: false);
      expect(formatted, '1,501'); // rounds up
    });
  });

  group('Money - Parsing', () {
    test('parse handles plain amounts', () {
      expect(Money.parse('8500').millimes, 8500000);
    });

    test('parse handles comma separators', () {
      expect(Money.parse('1,850,000.50').millimes, 1850000500);
    });

    test('parse handles surrounding whitespace', () {
      expect(Money.parse(' 125.25 ').millimes, 125250);
    });

    test('parse throws FormatException on invalid input', () {
      expect(() => Money.parse('abc'), throwsFormatException);
    });

    test('parse throws FormatException on empty input', () {
      expect(() => Money.parse('   '), throwsFormatException);
    });

    test('tryParse returns null on invalid input', () {
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('12.3.4'), isNull);
    });

    test('tryParse parses valid values', () {
      expect(Money.tryParse('8500')!.millimes, 8500000);
      expect(Money.tryParse('1,234.5')!.millimes, 1234500);
    });
  });

  group('StationItem - Financial Calculations', () {
    test('total = qty × price', () {
      // 10 panels × 8500 EGP = 85,000 EGP
      final qty = 10;
      final pricePerUnit = Money.fromInt(8500);
      final qtyMilliunits = qty * 1000;
      final qtyDecimal =
          (Decimal.fromInt(qtyMilliunits) / Decimal.fromInt(1000)).toDecimal();
      final total = pricePerUnit.multiplyByDecimal(qtyDecimal);
      expect(total.toDouble, 85000.0);
    });

    test('total with discount', () {
      // 10 panels × 8500 EGP × 10% discount = 85000 - 8500 = 76500
      final qty = Decimal.fromInt(10);
      final price = Money.fromInt(8500);
      final subtotal = price.multiplyByDecimal(qty);
      expect(subtotal.toDouble, 85000.0);

      final discountPct = Decimal.parse('10');
      final discountAmt = subtotal.percentage(discountPct);
      expect(discountAmt.toDouble, 8500.0);

      final afterDiscount = subtotal - discountAmt;
      expect(afterDiscount.toDouble, 76500.0);
    });

    test('total with tax', () {
      // 85000 EGP × 14% tax = 85000 + 11900 = 96900
      final amount = Money.fromInt(85000);
      final taxPct = Decimal.parse('14');
      final taxAmt = amount.percentage(taxPct);
      expect(taxAmt.toDouble, closeTo(11900.0, 0.01));

      final total = amount + taxAmt;
      expect(total.toDouble, closeTo(96900.0, 0.01));
    });

    test('price history: old price preserved', () {
      // When catalog price changes from 8500 to 9200,
      // the snapshot in the station item should remain 8500
      final snapshotPrice = Money.fromInt(8500); // captured at time of add
      final newCatalogPrice = Money.fromInt(9200);

      // Snapshot should NOT equal new price
      expect(snapshotPrice, isNot(equals(newCatalogPrice)));
      // Snapshot remains unchanged
      expect(snapshotPrice.toDouble, 8500.0);
    });
  });

  group('FinancialSummary - Calculations', () {
    test('profit = netSelling - totalCost', () {
      final materialCost = Money.fromInt(1250000);
      final laborCost = Money.fromInt(120000);
      final transportationCost = Money.fromInt(35000);
      final otherExpenses = Money.fromInt(45000);
      final sellingPrice = Money.fromInt(1850000);
      final discount = Money.fromMillimes(0);
      const taxPercentage = 0;

      final totalCost = materialCost + laborCost + transportationCost + otherExpenses;
      expect(totalCost.toDouble, 1450000.0);

      final netSelling = sellingPrice - discount;
      final profit = netSelling - totalCost;
      expect(profit.toDouble, 400000.0);
    });

    test('profit margin calculation', () {
      final cost = Money.fromInt(1450000);
      final sellingPrice = Money.fromInt(1850000);

      final margin = profitMargin(cost: cost, sellingPrice: sellingPrice);
      // (1850000 - 1450000) / 1850000 × 100 = 21.62%
      expect(margin.toDouble, closeTo(21.62, 0.01));
    });

    test('profit margin is 0 when selling price is 0', () {
      final cost = Money.fromInt(100);
      final sellingPrice = Money.fromMillimes(0);
      final margin = profitMargin(cost: cost, sellingPrice: sellingPrice);
      expect(margin, equals(Decimal.zero));
    });

    test('negative profit when cost > selling', () {
      final cost = Money.fromInt(1000);
      final selling = Money.fromInt(800);
      final profit = selling - cost;
      expect(profit.isNegative, true);
      expect(profit.toDouble, -200.0);
    });

    test('total cost sums all components', () {
      final m = Money.fromInt(500000);
      final l = Money.fromInt(50000);
      final t = Money.fromInt(20000);
      final o = Money.fromInt(30000);
      final total = m + l + t + o;
      expect(total.toDouble, 600000.0);
    });
  });

  group('Money - Edge Cases', () {
    test('large amounts work correctly', () {
      // 10 million EGP
      final m = Money.fromInt(10000000);
      expect(m.millimes, 10000000000);
      expect(m.toDouble, 10000000.0);
    });

    test('very small quantities work', () {
      // 0.5 units × 1000 EGP = 500 EGP
      final price = Money.fromInt(1000);
      final qty = Decimal.parse('0.5');
      final total = price.multiplyByDecimal(qty);
      expect(total.toDouble, 500.0);
    });

    test('comparison operators', () {
      final a = Money.fromInt(100);
      final b = Money.fromInt(200);
      expect(a < b, true);
      expect(b > a, true);
      expect(a <= a, true);
      expect(a >= a, true);
    });

    test('fromDouble rounds to the nearest millime', () {
      // 2.675 cannot be represented exactly as a double
      expect(Money.fromDouble(2.675).millimes, 2675);
    });
  });

  group('profitMargin - Rounding', () {
    test('profitMargin rounds to 2 decimals', () {
      final margin = profitMargin(
        cost: Money.fromInt(100),
        sellingPrice: Money.fromInt(300),
      );
      // (300 - 100) / 300 × 100 = 66.666...% → 66.67
      expect(margin.toString(), '66.67');
    });

    test('profitMargin handles non-terminating division', () {
      final margin = profitMargin(
        cost: Money.fromInt(1),
        sellingPrice: Money.fromInt(3),
      );
      // (3 - 1) / 3 × 100 = 66.666...% → 66.67
      expect(margin.toDouble, closeTo(66.67, 0.01));
    });
  });
}
