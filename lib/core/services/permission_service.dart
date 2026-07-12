import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for permission infrastructure operations.
abstract class PermissionService {
  /// Requests a specific permission from the platform layer.
  Future<bool> request(String permissionName);

  /// Returns whether the requested permission is already granted.
  Future<bool> isGranted(String permissionName);
}

/// Placeholder implementation for permission infrastructure operations.
/// TODO: Replace this placeholder with a permission handling implementation.
class PermissionServiceImpl implements PermissionService {
  @override
  Future<bool> request(String permissionName) async => true;

  @override
  Future<bool> isGranted(String permissionName) async => true;
}

/// Riverpod provider for exposing a permission service implementation.
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionServiceImpl(),
);
