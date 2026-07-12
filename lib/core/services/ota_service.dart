import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for over-the-air update infrastructure operations.
abstract class OtaService {
  /// Checks whether an update is available.
  Future<bool> checkForUpdate();

  /// Downloads the available update package.
  Future<void> downloadUpdate();

  /// Installs the downloaded update.
  Future<void> installUpdate();

  /// Rolls back to the previous application version if needed.
  Future<void> rollback();
}

/// Placeholder implementation for OTA infrastructure operations.
/// TODO: Replace this placeholder with an OTA update implementation.
class OtaServiceImpl implements OtaService {
  @override
  Future<bool> checkForUpdate() async => false;

  @override
  Future<void> downloadUpdate() async {}

  @override
  Future<void> installUpdate() async {}

  @override
  Future<void> rollback() async {}
}

/// Riverpod provider for exposing an OTA service implementation.
final otaServiceProvider = Provider<OtaService>((ref) => OtaServiceImpl());
