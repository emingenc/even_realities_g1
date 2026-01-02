# Even Realities G1 Library

A comprehensive Dart/Flutter library for controlling Even Realities G1 smart glasses via Bluetooth LE.

## Features

- 🔗 **Bluetooth Connection** - Automatic scanning, pairing, and connection management
- 📝 **Text Display** - Show text, notifications, and AI responses on the glasses
- 🗺️ **Navigation** - Turn-by-turn directions with navigation icons
- 🎤 **Voice Control** - Microphone access for voice commands and transcription
- 📊 **Dashboard** - Calendar events and information display
- 📝 **Quick Notes** - Add and manage quick notes on the glasses
- ⏰ **Time & Weather** - Sync time and weather information
- 🌐 **Translation** - Real-time translation display
- 🖼️ **Bitmap Display** - Send custom images to the glasses

## Documentation

- BLE protocol notes: [docs/BLE_PROTOCOL.md](docs/BLE_PROTOCOL.md)

## Installation

### Option 1: Git (Recommended)

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  even_realities_g1:
    git:
      url: https://github.com/emingenc/even_realities_g1.git
```

### Option 2: pub.dev

```yaml
dependencies:
  even_realities_g1: ^0.1.0
```

### Option 3: Local Path (for development)

```yaml
dependencies:
  even_realities_g1:
    path: ../even_realities_g1
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to G1 glasses</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to G1 glasses</string>
```

## Quick Start

```dart
import 'package:even_realities_g1/even_realities_g1.dart';

// Get the manager instance
final manager = G1Manager();

// Listen for connection events
manager.connectionStream.listen((event) {
  print('Connection: ${event.state}');
  
  if (event.state == G1ConnectionState.connected) {
    // Send a notification
    manager.notifications.send(
      G1NotificationModel(
        title: 'Hello',
        body: 'Connected to G1!',
        appName: 'MyApp',
      ),
    );
  }
});

// Start scanning for glasses
await manager.startScan();
```

## Usage Examples

### Display Text

```dart
// Simple text display
await manager.display.showText('Hello, World!');

// AI response with streaming
await manager.display.showAIResponse(
  'This is a longer response that will be paginated automatically.',
  isStreaming: false,
);
```

### Notifications

```dart
await manager.notifications.send(
  G1NotificationModel(
    title: 'New Message',
    body: 'You have a new message from John',
    appName: 'Messages',
  ),
);

// Simple notification
await manager.notifications.sendSimple(
  title: 'Reminder',
  body: 'Meeting in 5 minutes',
);
```

### Navigation

```dart
// Start navigation
await manager.navigation.start(
  G1NavigationModel(
    turnType: G1NavigationTurn.turnLeft,
    distance: '500m',
    streetName: 'Main Street',
  ),
);

// Update direction
await manager.navigation.showDirections(
  G1NavigationModel(
    turnType: G1NavigationTurn.turnRight,
    distance: '100m',
    streetName: 'Oak Avenue',
  ),
);

// End navigation
await manager.navigation.end();
```

### Dashboard & Calendar

```dart
await manager.dashboard.show(
  layout: G1DashboardLayout.dual,
  items: [
    G1CalendarModel(
      title: 'Team Meeting',
      time: DateTime.now().add(Duration(hours: 1)),
    ),
    G1CalendarModel(
      title: 'Lunch',
      time: DateTime.now().add(Duration(hours: 3)),
    ),
  ],
);
```

### Quick Notes

```dart
// Add a note
await manager.notes.add(
  G1NoteModel(
    position: 1, // 1-4
    text: 'Remember to call mom',
  ),
);

// Delete a note
await manager.notes.delete(position: 1);
```

### Time & Weather

```dart
// Manual sync
await manager.timeWeather.sync(
  G1WeatherModel(
    weatherIcon: G1WeatherIcon.sunny,
    temperature: 22,
    temperatureUnit: TemperatureUnit.celsius,
    timeFormat: TimeFormat.format24h,
  ),
);

// Sync from OpenWeatherMap
await manager.timeWeather.syncFromOpenWeatherMap(
  latitude: 52.52,
  longitude: 13.405,
  apiKey: 'YOUR_API_KEY',
);
```

### Voice Control

```dart
// Enable microphone
await manager.microphone.enable();

// Listen for audio data
manager.microphone.audioStream.listen((audioData) {
  // Process LC3 audio data
  // You'll need to decode LC3 and transcribe with Whisper or similar
});

// Disable microphone
await manager.microphone.disable();
```

### Settings

```dart
// Set brightness
await manager.settings.setBrightness(G1Brightness.level3);

// Enable silent mode
await manager.settings.setSilentMode(true);

// Set head-up angle
await manager.settings.setHeadUpAngle(15);
```

## Audio Processing

The G1 glasses use LC3 codec for audio. This library provides the raw audio stream - you'll need to:

1. Decode LC3 audio using platform channels (Swift/Kotlin)
2. Transcribe using Whisper or another speech-to-text service

Example with whisper_ggml:

```dart
import 'package:whisper_ggml/whisper_ggml.dart';

final whisper = Whisper();
await whisper.initialize(modelPath: 'path/to/model.bin');

manager.microphone.onAISessionEnd = (audioData) async {
  // Decode LC3 to PCM first (platform-specific)
  final pcmData = await decodeLc3(audioData);
  
  // Transcribe
  final result = await whisper.transcribe(pcmData);
  print('Transcription: ${result.text}');
};
```

## Architecture

```
even_realities_g1/
├── lib/
│   ├── even_realities_g1.dart      # Main exports
│   └── src/
│       ├── bluetooth/              # BLE connection layer
│       │   ├── bluetooth_constants.dart
│       │   ├── g1_connection_state.dart
│       │   ├── g1_glass.dart
│       │   └── g1_manager.dart
│       ├── protocol/               # G1 protocol
│       │   ├── commands.dart
│       │   └── crc32.dart
│       ├── features/               # Feature implementations
│       │   ├── g1_display.dart
│       │   ├── g1_notifications.dart
│       │   ├── g1_navigation.dart
│       │   ├── g1_dashboard.dart
│       │   ├── g1_notes.dart
│       │   ├── g1_time_weather.dart
│       │   ├── g1_settings.dart
│       │   ├── g1_bitmap.dart
│       │   └── g1_translate.dart
│       ├── voice/                  # Voice features
│       │   ├── g1_microphone.dart
│       │   ├── g1_voice_note.dart
│       │   └── voice_data_collector.dart
│       ├── models/                 # Data models
│       │   ├── notification_model.dart
│       │   ├── note_model.dart
│       │   ├── calendar_model.dart
│       │   ├── weather_model.dart
│       │   └── navigation_model.dart
│       └── utils/                  # Utilities
│           ├── emoji_converter.dart
│           └── text_formatter.dart
```

## Credits

Based on the G1 implementation from [fahrplan](https://github.com/meyskens/fahrplan) by Maartje Eyskens.

## License

MIT License - see [LICENSE](LICENSE) for details.
