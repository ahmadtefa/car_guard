// lib/core/utils/result.dart
// Simple Result type (Either pattern) without external packages

import '../errors/failures.dart';

class Result<T> {
  final T? _value;
  final Failure? _failure;

  const Result._value(this._value) : _failure = null;
  const Result._failure(this._failure) : _value = null;

  factory Result.success(T value) => Result._value(value);
  factory Result.failure(Failure failure) => Result._failure(failure);

  bool get isSuccess => _failure == null;
  bool get isFailure => _failure != null;

  T get value {
    if (_failure != null) throw StateError('Result is a failure: $_failure');
    return _value as T;
  }

  Failure get failure {
    if (_failure == null) throw StateError('Result is a success');
    return _failure;
  }

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    if (isSuccess) return onSuccess(_value as T);
    return onFailure(_failure!);
  }

  Result<R> map<R>(R Function(T value) transform) {
    if (isSuccess) return Result.success(transform(_value as T));
    return Result.failure(_failure!);
  }

  @override
  String toString() =>
      isSuccess ? 'Success($_value)' : 'Failure($_failure)';
}
