import 'dart:convert';
import 'dart:typed_data';

import '../protocol/commands.dart';

/// Model for G1 notifications (NCS format).
///
/// This is the notification format expected by G1 glasses.
class G1NotificationModel {
  /// Unique message ID
  final int messageId;

  /// Action type (0 = add)
  final int action;

  /// Notification type
  final int type;

  /// App package identifier
  final String appIdentifier;

  /// Notification title
  String title;

  /// Notification subtitle
  String subtitle;

  /// Notification message body
  String message;

  /// Unix timestamp in seconds
  final int timeSeconds;

  /// Formatted date string
  final String date;

  /// Display name of the app
  final String displayName;

  G1NotificationModel({
    required this.messageId,
    this.action = 0,
    this.type = 1,
    required this.appIdentifier,
    required this.title,
    this.subtitle = '',
    required this.message,
    int? timeSeconds,
    String? date,
    required this.displayName,
  })  : timeSeconds =
            timeSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        date = date ?? _formatDate(DateTime.now());

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  /// Convert to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'msg_id': messageId,
      'action': action,
      'app_identifier': appIdentifier,
      'title': title,
      'subtitle': subtitle,
      'message': message,
      'time_s': timeSeconds,
      'date': date,
      'display_name': displayName,
    };
  }

  /// Serialize to bytes
  Uint8List toBytes() {
    return Uint8List.fromList(utf8.encode(jsonEncode({'ncs_notification': toJson()})));
  }

  /// Build chunked notification packets for transmission.
  ///
  /// Returns a list of packets, each with a header and payload chunk.
  List<Uint8List> buildPackets() {
    final jsonBytes = toBytes();
    const maxChunkSize = 180 - 4; // 4 bytes for header
    final chunks = <Uint8List>[];

    for (int i = 0; i < jsonBytes.length; i += maxChunkSize) {
      final end = (i + maxChunkSize < jsonBytes.length)
          ? i + maxChunkSize
          : jsonBytes.length;
      chunks.add(jsonBytes.sublist(i, end));
    }

    final totalChunks = chunks.length;
    final packets = <Uint8List>[];

    for (int i = 0; i < chunks.length; i++) {
      final header = [
        G1Commands.notification,
        1, // notify ID
        totalChunks,
        i,
      ];
      packets.add(Uint8List.fromList(header + chunks[i]));
    }

    return packets;
  }
}
