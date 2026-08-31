// lib/core/extensions/date_extension.dart

import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String toArabicDate() {
    final formatter = DateFormat('dd/MM/yyyy', 'ar');
    return formatter.format(this);
  }

  String toDisplayDate() {
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(this);
  }

  String toDisplayDateTime() {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    return formatter.format(this);
  }

  String toIso8601StringLocal() {
    return toIso8601String();
  }
}

extension NullableDateTimeExtension on DateTime? {
  String toDisplayDateOrEmpty() {
    if (this == null) return '';
    return this!.toDisplayDate();
  }
}
