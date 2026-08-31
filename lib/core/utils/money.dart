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

  /// Parse from string.
  ///
  /// Throws a [FormatException] when [value] is not a valid decimal number.
  factory Money.parse(String value) {
    final money = Money.tryParse(value);
    if (money == null) {
      throw FormatException('Invalid money value', value);
    }
    return money;
  }

  /// Parse from string, returning `null` instead of throwing when [value]
  /// is not a valid decimal number.
  static Money? tryParse(String value) {
    final cleaned = value.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    try {
      return Money.fromDecimal(Decimal.parse(cleaned));
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// The value stored as millimes (for database storage)
  int get millimes => _millimes;

  /// Convert to Decimal for display/calculations.
  ///
  /// Note: `Decimal operator /` in package:decimal 2.x returns a [Rational],
  /// so the result must be converted back with `.toDecimal()` (always exact
  /// here since we divide by 1000).
  Decimal get toDecimal =>
      (Decimal.fromInt(_millimes) / Decimal.fromInt(1000)).toDecimal();

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
    return multiplyByDecimal((percent / Decimal.fromInt(100)).toDecimal());
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

  /// Format for display (e.g., "1,850,000" or "1,850.5")
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
  // Multiply before dividing to stay inside Decimal for as long as possible.
  // The final division may be non-terminating (e.g. 1/3), so cap its scale
  // before rounding to 2 decimal places.
  final ratio = (sellingPrice.toDecimal - cost.toDecimal) *
      Decimal.fromInt(100) /
      sellingPrice.toDecimal;
  return ratio.toDecimal(scaleOnInfinitePrecision: 6).round(scale: 2);
}
