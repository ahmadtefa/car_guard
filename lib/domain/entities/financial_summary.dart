// lib/domain/entities/financial_summary.dart

import 'package:decimal/decimal.dart';
import '../../core/utils/money.dart';

/// Computed financial summary for a station.
/// All values are calculated from station items and expenses.
class FinancialSummary {
  final String stationId;

  /// Sum of all station items totals
  final Money materialCost;

  /// Sum of expenses in 'labor' category
  final Money laborCost;

  /// Sum of expenses in 'transportation' category
  final Money transportationCost;

  /// Sum of all other expenses
  final Money otherExpenses;

  /// materialCost + laborCost + transportationCost + otherExpenses
  final Money totalActualCost;

  /// Entered by user in station form
  final Money sellingPrice;

  /// Discount on selling price
  final Money discount;

  /// Tax percentage (0-100)
  final int taxPercentage;

  FinancialSummary({
    required this.stationId,
    required this.materialCost,
    required this.laborCost,
    required this.transportationCost,
    required this.otherExpenses,
    required this.sellingPrice,
    required this.discount,
    required this.taxPercentage,
  })  : totalActualCost = materialCost + laborCost + transportationCost + otherExpenses;

  /// Total expenses = labor + transportation + other
  Money get totalExpenses => laborCost + transportationCost + otherExpenses;

  /// Selling price after discount
  Money get sellingPriceAfterDiscount => sellingPrice - discount;

  /// Tax amount
  Money get taxAmount {
    if (taxPercentage == 0) return Money.fromMillimes(0);
    return sellingPriceAfterDiscount.multiplyByDecimal(
      Decimal.fromInt(taxPercentage) / Decimal.fromInt(100),
    );
  }

  /// Net selling value = Selling Price - Discount + Tax
  Money get netSellingValue => sellingPriceAfterDiscount + taxAmount;

  /// Profit = Net Selling - Total Cost
  Money get profit => netSellingValue - totalActualCost;

  /// Profit Margin = (Profit / NetSellingValue) × 100
  Decimal get profitMarginPercent {
    if (netSellingValue.millimes == 0) return Decimal.zero;
    final margin = (profit.toDecimal / netSellingValue.toDecimal) *
        Decimal.fromInt(100);
    return margin.round(scale: 2);
  }

  bool get isProfitable => profit.isPositive;

  @override
  String toString() {
    return 'FinancialSummary('
        'materialCost: $materialCost, '
        'totalActualCost: $totalActualCost, '
        'sellingPrice: $sellingPrice, '
        'profit: $profit, '
        'margin: $profitMarginPercent%)';
  }
}
