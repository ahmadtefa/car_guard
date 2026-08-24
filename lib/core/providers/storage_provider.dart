import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

/// Riverpod provider for exposing the storage infrastructure service contract.
///
/// This keeps persistence access abstract and reusable across the application.
final storageProvider = Provider<StorageService>(
  (ref) => ref.watch(storageServiceProvider),
);
