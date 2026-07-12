/// Enumeration describing the current connection state of a transport.
///
/// The values are intentionally generic so they can describe network or device
/// connectivity without coupling the model layer to a specific implementation.
/// TODO: Expand this enum when more connection states are needed.
enum ConnectionStatus {
  /// The transport is currently disconnected.
  disconnected,

  /// The transport is currently connected.
  connected,

  /// The transport is currently connecting.
  connecting,

  /// The transport is currently disconnecting.
  disconnecting,

  /// The transport state is unknown.
  unknown,
}
