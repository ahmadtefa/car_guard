// lib/core/utils/money.dart
// Financial calculations using integer arithmetic to avoid floating point issues.
// All values stored as integer millimes (1 EGP = 1000 millimes).

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

class Money {
  /// Internal value stored as millimes (1/1000 of currency unit)
  final int _millimes;

  const Money._(this._millimes);

  factory Money.zero() => const Money._(0);

  /// Create from a decimal amount (e.g., 1850.50 EGP)
  factory Money.fromDecimal(Decimal amount) {
    final millimes = (amount * Decimal.fromInt(1000)).round().toBigInt().toInt();
    return Money._(millimes);
  }

  /// Create from a double (be careful - use fromDecimal when possible)
  factory Money.fromDouble(double amount) {
    final millimes = (amount * 1000).round();
    return Money._(millimes);
  }

  /// Create from an integer amount (whole currency units)
  factory Money.fromInt(int amount) => Money._(amount * 1000);

  /// Create from stored integer millimes
  factory Money.fromMillimes(int millimes) => Money._(millimes);

  /// Parse from string
  factory Money.parse(String value) {
    final cleaned = value.replaceAll(',', '').trim();
    return Money.fromDecimal(Decimal.parse(cleaned));
  }

  /// The value stored as millimes (for database storage)
  int get millimes => _millimes;

  /// Convert to Decimal for display/calculations
  Decimal get toDecimal =>
      Decimal.fromInt(_millimes) / Decimal.fromInt(1000);

  /// Convert to double (for display only, not for calculations)
  double get toDouble => _millimes / 1000.0;

  Money operator +(Money other) => Money._(_millimes + other._millimes);
  Money operator -(Money other) => Money._(_millimes - other._millimes);
  Money operator -() => Money._(-_millimes);

  Money multiplyByInt(int factor) => Money._(_millimes * factor);

  Money multiplyByDecimal(Decimal factor) {
    final result = (toDecimal * factor);
    return Money.fromDecimal(result);
  }

  /// Multiply by a percentage (0-100)
  Money percentage(Decimal percent) {
    return multiplyByDecimal(percent / Decimal.fromInt(100));
  }

  bool operator >(Money other) => _millimes > other._millimes;
  bool operator <(Money other) => _millimes < other._millimes;
  bool operator >=(Money other) => _millimes >= other._millimes;
  bool operator <=(Money other) => _millimes <= other._millimes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && runtimeType == other.runtimeType && _millimes == other._millimes;

  @override
  int get hashCode => _millimes.hashCode;

  /// Format for display (e.g., "1,850,000.000")
  String format({String symbol = 'ج.م', bool showSymbol = true}) {
    final formatter = NumberFormat('#,##0.###', 'en');
    final formatted = formatter.format(toDouble);
    return showSymbol ? '$formatted $symbol' : formatted;
  }

  /// Format without decimal for whole numbers
  String formatWhole({String symbol = 'ج.م', bool showSymbol = true}) {
    final formatter = NumberFormat('#,##0', 'en');
    final formatted = formatter.format(toDouble.round());
    return showSymbol ? '$formatted $symbol' : formatted;
  }

  @override
  String toString() => format();

  bool get isZero => _millimes == 0;
  bool get isPositive => _millimes > 0;
  bool get isNegative => _millimes < 0;
}

/// Calculate profit margin as a percentage
Decimal profitMargin({required Money cost, required Money sellingPrice}) {
  if (sellingPrice.millimes == 0) return Decimal.zero;
  final margin = (sellingPrice.toDecimal - cost.toDecimal) /
      sellingPrice.toDecimal *
      Decimal.fromInt(100);
  return margin.round(scale: 2);
}
