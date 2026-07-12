import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/permission_service.dart';

/// Riverpod provider for exposing the permission infrastructure service contract.
///
/// This provider keeps platform permission checks abstract and reusable.
/// TODO: Update this wiring when permission handling is implemented.
final permissionProvider = Provider<PermissionService>(
  (ref) => ref.watch(permissionServiceProvider),
);
