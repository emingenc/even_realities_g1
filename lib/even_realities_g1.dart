/// Even Realities G1 Smart Glasses Library
///
/// A comprehensive Dart library for controlling Even Realities G1 smart glasses
/// via Bluetooth LE. Supports display, notifications, navigation, voice control,
/// dashboard management, and more.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:even_realities_g1/even_realities_g1.dart';
///
/// // Create manager instance
/// final g1 = G1Manager();
///
/// // Scan and connect
/// await g1.startScan(
///   onGlassesFound: (left, right) => print('Found: $left, $right'),
///   onConnected: () => print('Connected!'),
/// );
///
/// // Display text
/// await g1.display.showText('Hello G1!');
///
/// // Send notification
/// await g1.notifications.send(
///   G1Notification(
///     appName: 'MyApp',
///     title: 'Hello',
///     message: 'World',
///   ),
/// );
///
/// // Disconnect
/// await g1.disconnect();
/// ```
library even_realities_g1;

// Bluetooth layer
export 'src/bluetooth/g1_manager.dart';
export 'src/bluetooth/g1_glass.dart';
export 'src/bluetooth/g1_connection_state.dart';
export 'src/bluetooth/bluetooth_constants.dart';

// Protocol layer
export 'src/protocol/commands.dart';
export 'src/protocol/crc32.dart';

// Features
export 'src/features/g1_display.dart';
export 'src/features/g1_notifications.dart';
export 'src/features/g1_navigation.dart';
export 'src/features/g1_dashboard.dart';
export 'src/features/g1_notes.dart';
export 'src/features/g1_time_weather.dart';
export 'src/features/g1_settings.dart';
export 'src/features/g1_bitmap.dart';
export 'src/features/g1_translate.dart';

// Voice
export 'src/voice/g1_microphone.dart';
export 'src/voice/g1_voice_note.dart';
export 'src/voice/voice_data_collector.dart';

// Utils
export 'src/utils/emoji_converter.dart';
export 'src/utils/text_formatter.dart';

// Models
export 'src/models/notification_model.dart';
export 'src/models/note_model.dart';
export 'src/models/calendar_model.dart';
export 'src/models/weather_model.dart';
export 'src/models/navigation_model.dart';
