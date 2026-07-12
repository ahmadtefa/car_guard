/// A reusable exception type for infrastructure and domain-level failures.
///
/// This type is intentionally generic so it can be used across services and
/// providers without introducing Flutter-specific dependencies.
class AppException implements Exception {
  /// Creates an application exception with a message and optional cause.
  const AppException({required this.message, this.cause, this.code});

  /// Human-readable message describing the exception.
  final String message;

  /// Optional underlying cause for debugging.
  final Object? cause;

  /// Optional machine-readable exception code.
  final String? code;

  @override
  String toString() => 'AppException(message: $message, code: $code)';
}
