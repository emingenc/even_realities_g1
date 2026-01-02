
/// Navigation turn icons
/// Based on fahrplan reference implementation
enum G1NavigationTurn {
  straightDot(0x01),
  straight(0x02),
  right(0x03),
  left(0x04),
  slightRight(0x05),
  slightLeft(0x06),
  sharpRight(0x07),
  sharpLeft(0x08),
  uTurnLeft(0x09),
  uTurnRight(0x0A),
  merge(0x0B),
  roundabout1(0x0C),
  roundabout2(0x0D),
  roundabout3(0x0E),
  roundabout4(0x0F),
  roundabout5(0x10),
  roundabout6(0x11),
  roundabout7(0x12),
  roundabout8(0x13),
  roundaboutLeft1(0x14),
  roundaboutLeft2(0x15),
  roundaboutLeft3(0x16),
  roundaboutLeft4(0x17),
  roundaboutLeft5(0x18),
  roundaboutLeft6(0x19),
  roundaboutLeft7(0x1A),
  roundaboutLeft8(0x1B),
  laneRight(0x1C),
  laneLeft(0x1D),
  laneHalfRight(0x1E),
  laneHalfLeft(0x1F),
  arrive(0x20),
  arriveRight(0x21),
  arriveLeft(0x22),
  ferry(0x23);

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
