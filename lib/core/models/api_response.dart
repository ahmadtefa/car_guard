/// Generic envelope for API-style responses.
///
/// This model keeps payload handling reusable and immutable while leaving the
/// actual data shape open for future implementations.
class ApiResponse<T> {
  /// Creates an API response envelope.
  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  /// Whether the response was considered successful.
  final bool success;

  /// Optional payload returned by the response.
  final T? data;

  /// Optional human-readable message.
  final String? message;

  /// Optional machine-readable error code.
  final String? errorCode;
}
