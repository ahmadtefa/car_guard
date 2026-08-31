// test/unit/result_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_manager/core/errors/failures.dart';
import 'package:solar_manager/core/utils/result.dart';

void main() {
  group('Result - Success', () {
    test('isSuccess is true', () {
      final r = Result<int>.success(42);
      expect(r.isSuccess, true);
      expect(r.isFailure, false);
    });

    test('value returns the value', () {
      final r = Result<String>.success('hello');
      expect(r.value, 'hello');
    });

    test('fold returns onSuccess result', () {
      final r = Result<int>.success(10);
      final result = r.fold(
        onSuccess: (v) => v * 2,
        onFailure: (_) => -1,
      );
      expect(result, 20);
    });

    test('map transforms value', () {
      final r = Result<int>.success(5);
      final mapped = r.map((v) => v.toString());
      expect(mapped.value, '5');
    });
  });

  group('Result - Failure', () {
    test('isFailure is true', () {
      final r = Result<int>.failure(const DatabaseFailure('error'));
      expect(r.isFailure, true);
      expect(r.isSuccess, false);
    });

    test('failure returns the failure', () {
      const failure = DatabaseFailure('db error');
      final r = Result<int>.failure(failure);
      expect(r.failure, equals(failure));
    });

    test('fold returns onFailure result', () {
      final r = Result<int>.failure(const DatabaseFailure('error'));
      final result = r.fold(
        onSuccess: (_) => 'ok',
        onFailure: (f) => f.message,
      );
      expect(result, 'error');
    });

    test('map on failure returns same failure', () {
      final r = Result<int>.failure(const DatabaseFailure('err'));
      final mapped = r.map((v) => v * 2);
      expect(mapped.isFailure, true);
    });
  });

  group('Failures', () {
    test('DatabaseFailure has correct message', () {
      const f = DatabaseFailure('db error');
      expect(f.message, 'db error');
    });

    test('ValidationFailure can have field errors', () {
      const f = ValidationFailure('invalid', fieldErrors: {'name': 'required'});
      expect(f.fieldErrors?['name'], 'required');
    });

    test('NotFoundFailure message', () {
      const f = NotFoundFailure('not found');
      expect(f.message, 'not found');
    });

    test('ImportFailure has reason', () {
      const f = ImportFailure('bad file',
          reason: ImportFailureReason.corruptedFile);
      expect(f.reason, ImportFailureReason.corruptedFile);
    });
  });
}
