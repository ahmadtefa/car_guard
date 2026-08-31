// lib/core/utils/id_generator.dart

import 'package:uuid/uuid.dart';

class IdGenerator {
  IdGenerator._();

  static const _uuid = Uuid();

  /// Generate a new unique UUID v4
  static String generate() => _uuid.v4();

  /// Generate a station display number like ST-0001
  static String generateStationNumber(int sequence) {
    return 'ST-${sequence.toString().padLeft(4, '0')}';
  }
}
