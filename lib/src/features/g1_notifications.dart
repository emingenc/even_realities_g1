import '../bluetooth/g1_manager.dart';
import '../models/notification_model.dart';
import '../utils/emoji_converter.dart';

/// G1 Notifications feature for sending notifications to glasses.
class G1Notifications {
  final G1Manager _manager;

  G1Notifications(this._manager);

  /// Send a notification to the glasses.
  ///
  /// [notification] - The notification to send
  /// [convertEmojis] - Whether to convert emojis to ASCII
  Future<void> send(
    G1NotificationModel notification, {
    bool convertEmojis = true,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Convert emojis if requested
    if (convertEmojis) {
      notification.title = EmojiConverter.convert(notification.title);
      notification.subtitle = EmojiConverter.convert(notification.subtitle);
      notification.message = EmojiConverter.convert(notification.message);
    }

    final packets = notification.buildPackets();

    for (final packet in packets) {
      await _manager.sendCommand(packet);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Send a simple notification with just title and message.
  Future<void> sendSimple({
    required String appName,
    required String title,
    required String message,
    String? subtitle,
    String? appIdentifier,
  }) async {
    final notification = G1NotificationModel(
      messageId: DateTime.now().millisecondsSinceEpoch,
      appIdentifier: appIdentifier ?? appName.toLowerCase().replaceAll(' ', '.'),
      title: title,
      subtitle: subtitle ?? '',
      message: message,
      displayName: appName,
    );

    await send(notification);
  }
}
