// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  static const String appName = 'Solar Manager';
  static const String appNameAr = 'سولار مانجر';
  static const String version = '1.0.0';
  static const int fileFormatVersion = 1;
  static const String stationFileExtension = '.station';
  static const String stationFilePrefix = 'ST-';

  // Database
  static const String databaseName = 'solar_manager.db';
  static const int databaseVersion = 1;

  // Export
  static const String exportMimeType = 'application/octet-stream';
  static const String pdfMimeType = 'application/pdf';

  // Validation
  static const int maxStationNameLength = 200;
  static const int maxCustomerNameLength = 200;
  static const int maxNotesLength = 2000;
  static const int maxDescriptionLength = 1000;

  // Financial precision - store as integer (millimes)
  // 1 EGP = 1000 millimes to avoid floating point issues
  static const int moneyPrecision = 3;
}
