/// A generic result wrapper for representing either success or failure.
///
/// This type is intentionally framework-agnostic so it can be reused across
/// services, repositories, and providers without coupling to UI concerns.
abstract class Result<T> {
  /// Creates a successful result with the provided value.
  const factory Result.success(T value) = SuccessResult<T>;

  /// Creates a failed result with the provided failure information.
  const factory Result.failure(Failure failure) = FailureResult<T>;

  /// Returns whether this result represents a successful outcome.
  bool get isSuccess;

  /// Returns whether this result represents a failed outcome.
  bool get isFailure;

  /// Returns the successful value when available.
  T? get value;

  /// Returns the failure when available.
  Failure? get failure;
}

/// Successful result payload.
class SuccessResult<T> implements Result<T> {
  /// Creates a successful result with the provided value.
  const SuccessResult(this.value);

  @override
  final T? value;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  Failure? get failure => null;
}

/// Failed result payload.
class FailureResult<T> implements Result<T> {
  /// Creates a failed result with the provided failure information.
  const FailureResult(this.failure);

  @override
  final Failure? failure;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get value => null;
}

/// A structured failure descriptor used by the result layer.
class Failure implements Exception {
  /// Creates a failure with a message and optional cause.
  const Failure({required this.message, this.cause, this.code});

  /// Human-readable failure message.
  final String message;

  /// Optional underlying cause for debugging or logging.
  final Object? cause;

  /// Optional machine-readable failure code.
  final String? code;

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}
