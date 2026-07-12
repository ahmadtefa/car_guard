/// Enumeration describing the lifecycle state of an asynchronous operation.
///
/// This is a reusable model for representing pending, successful, failed, or
/// idle operations in a consistent manner.
/// TODO: Extend this enum with additional states if future workflows need them.
enum OperationState {
  /// The operation has not started yet.
  idle,

  /// The operation is currently in progress.
  loading,

  /// The operation completed successfully.
  success,

  /// The operation completed with a failure.
  failure,
}
