import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_models.dart';
import 'device_provider.dart';

final deviceStatusProvider = StreamProvider<DeviceStatus>((ref) {
  final repository = ref.watch(esp8266RepositoryProvider);

  return repository.liveUpdates;
});