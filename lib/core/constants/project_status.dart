// lib/core/constants/project_status.dart

/// Project status constants - stored as strings so custom statuses can be added
class ProjectStatus {
  ProjectStatus._();

  static const String study = 'study';
  static const String inspection = 'inspection';
  static const String pricing = 'pricing';
  static const String quotation = 'quotation';
  static const String contracted = 'contracted';
  static const String underExecution = 'under_execution';
  static const String completed = 'completed';
  static const String suspended = 'suspended';
  static const String cancelled = 'cancelled';

  /// Default statuses with Arabic display names
  static const List<Map<String, String>> defaults = [
    {'key': study, 'nameAr': 'دراسة', 'nameEn': 'Study'},
    {'key': inspection, 'nameAr': 'معاينة', 'nameEn': 'Inspection'},
    {'key': pricing, 'nameAr': 'تسعير', 'nameEn': 'Pricing'},
    {'key': quotation, 'nameAr': 'عرض سعر', 'nameEn': 'Quotation'},
    {'key': contracted, 'nameAr': 'تعاقد', 'nameEn': 'Contracted'},
    {'key': underExecution, 'nameAr': 'تحت التنفيذ', 'nameEn': 'Under Execution'},
    {'key': completed, 'nameAr': 'مكتمل', 'nameEn': 'Completed'},
    {'key': suspended, 'nameAr': 'متوقف', 'nameEn': 'Suspended'},
    {'key': cancelled, 'nameAr': 'ملغي', 'nameEn': 'Cancelled'},
  ];
}
