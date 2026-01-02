
/// Navigation turn icons
enum G1NavigationTurn {
  straight(0x00),
  slightLeft(0x01),
  left(0x02),
  sharpLeft(0x03),
  slightRight(0x04),
  right(0x05),
  sharpRight(0x06),
  uTurn(0x07),
  destination(0x08),
  roundabout(0x09);

  final int code;
  const G1NavigationTurn(this.code);
}

/// Model for navigation data on G1.
class G1NavigationModel {
  /// Total trip duration (e.g., "15 min")
  final String totalDuration;

  /// Total trip distance (e.g., "5.2 km")
  final String totalDistance;

  /// Current direction instruction
  final String direction;

  /// Distance to next turn
  final String distance;

  /// Current speed (e.g., "50 km/h")
  final String speed;

  /// Turn type
  final G1NavigationTurn turn;

  /// Custom X position (optional)
  final List<int>? customX;

  /// Custom Y position
  final int customY;

  G1NavigationModel({
    required this.totalDuration,
    required this.totalDistance,
    required this.direction,
    required this.distance,
    required this.speed,
    required this.turn,
    this.customX,
    this.customY = 0x00,
  });
}
