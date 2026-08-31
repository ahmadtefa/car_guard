// test/unit/id_generator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_manager/core/utils/id_generator.dart';

void main() {
  group('IdGenerator', () {
    test('generates non-empty UUID', () {
      final id = IdGenerator.generate();
      expect(id.isNotEmpty, true);
    });

    test('generates unique IDs', () {
      final id1 = IdGenerator.generate();
      final id2 = IdGenerator.generate();
      expect(id1, isNot(equals(id2)));
    });

    test('UUID has correct format', () {
      final id = IdGenerator.generate();
      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false);
      expect(uuidRegex.hasMatch(id), true);
    });

    test('station number ST-0001 for sequence 1', () {
      final num = IdGenerator.generateStationNumber(1);
      expect(num, 'ST-0001');
    });

    test('station number ST-0010 for sequence 10', () {
      final num = IdGenerator.generateStationNumber(10);
      expect(num, 'ST-0010');
    });

    test('station number ST-0100 for sequence 100', () {
      final num = IdGenerator.generateStationNumber(100);
      expect(num, 'ST-0100');
    });

    test('station number ST-1000 for sequence 1000', () {
      final num = IdGenerator.generateStationNumber(1000);
      expect(num, 'ST-1000');
    });
  });
}
