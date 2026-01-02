import 'dart:convert';
import 'dart:typed_data';

/// Model for calendar events on G1 dashboard.
class G1CalendarModel {
  /// Event name/title
  final String name;

  /// Event time (e.g., "14:00")
  final String time;

  /// Event location
  final String location;

  G1CalendarModel({
    required this.name,
    required this.time,
    required this.location,
  });

  /// Build dashboard calendar item command.
  Uint8List buildDashboardCommand() {
    final bytes = <int>[
      0x00, 0x6d, 0x03, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0x01,
    ];

    // Event name
    bytes.add(0x01);
    bytes.add(name.length);
    bytes.addAll(utf8.encode(name));

    // Event time
    bytes.add(0x02);
    bytes.add(time.length);
    bytes.addAll(utf8.encode(time));

    // Event location
    bytes.add(0x03);
    bytes.add(location.length);
    bytes.addAll(utf8.encode(location));

    final length = bytes.length + 2;
    return Uint8List.fromList([0x06, length, ...bytes]);
  }
}
