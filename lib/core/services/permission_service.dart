import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class PermissionService {
  Future<bool> request(String permissionName);

  Future<bool> isGranted(String permissionName);
}

class PermissionServiceImpl implements PermissionService {
  @override
  Future<bool> request(String permissionName) async {
    final permission = _permission(permissionName);

    if (permission == null) {
      return false;
    }

    final status = await permission.request();
    return status.isGranted;
  }

  @override
  Future<bool> isGranted(String permissionName) async {
    final permission = _permission(permissionName);

    if (permission == null) {
      return false;
    }

    return permission.status.isGranted;
  }

  Permission? _permission(String name) {
    switch (name.toLowerCase()) {
      case 'notification':
      case 'notifications':
        return Permission.notification;

      case 'location':
        return Permission.location;

      case 'camera':
        return Permission.camera;

      case 'storage':
        return Permission.storage;

      case 'bluetooth':
        return Permission.bluetooth;

      default:
        return null;
    }
  }
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionServiceImpl(),
);