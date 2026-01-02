/// Represents which side of the glasses (left or right).
enum GlassSide {
  left,
  right;

  @override
  String toString() => name;
}

/// Connection state for G1 glasses.
enum G1ConnectionState {
  /// Not connected to any glasses
  disconnected,

  /// Scanning for glasses
  scanning,

  /// Found glasses, connecting
  connecting,

  /// Connected to both glasses
  connected,

  /// Connection error occurred
  error,
}

/// Event data for connection state changes.
class G1ConnectionEvent {
  /// The current connection state
  final G1ConnectionState state;

  /// Optional error message if state is error
  final String? errorMessage;

  /// Name of left glass if found
  final String? leftGlassName;

  /// Name of right glass if found
  final String? rightGlassName;

  const G1ConnectionEvent({
    required this.state,
    this.errorMessage,
    this.leftGlassName,
    this.rightGlassName,
  });

  @override
  String toString() =>
      'G1ConnectionEvent(state: $state, left: $leftGlassName, right: $rightGlassName, error: $errorMessage)';
}
