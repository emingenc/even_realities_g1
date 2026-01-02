import 'dart:typed_data';

import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';

/// Brightness level for the G1 display.
enum G1Brightness {
  /// Auto brightness (sensor-based)
  auto(0),
  
  /// Level 1 - Darkest
  level1(1),
  
  /// Level 2
  level2(2),
  
  /// Level 3
  level3(3),
  
  /// Level 4
  level4(4),
  
  /// Level 5 - Brightest
  level5(5);

  final int value;
  const G1Brightness(this.value);
}

/// G1 Settings feature for device configuration.
class G1Settings {
  final G1Manager _manager;

  G1Settings(this._manager);

  /// Set display brightness.
  Future<void> setBrightness(G1Brightness brightness) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand([
      G1Commands.brightness,
      brightness.value,
    ]);
  }

  /// Enable or disable silent mode.
  ///
  /// When enabled, the glasses won't play sounds.
  Future<void> setSilentMode(bool enabled) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand([
      G1Commands.silentMode,
      enabled ? 0x01 : 0x00,
    ]);
  }

  /// Set the head-up display angle.
  ///
  /// This adjusts when the display activates based on head tilt.
  Future<void> setHeadUpAngle(int angle) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Angle is sent as a byte value
    await _manager.sendCommand([
      G1Commands.headUpAngle,
      angle.clamp(0, 90),
    ]);
  }

  /// Enable or disable head-up display mode.
  Future<void> setHeadUpDisplay(bool enabled) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand([
      G1Commands.headUpDisplay,
      enabled ? 0x01 : 0x00,
    ]);
  }

  /// Send a heartbeat to keep the connection alive.
  Future<void> heartbeat() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand([G1Commands.heartbeat]);
  }

  /// Perform initial setup sequence.
  ///
  /// This should be called after connection to initialize the glasses state.
  Future<void> performSetup() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Sync current time
    final now = DateTime.now();
    await _syncTime(now);

    // Set default brightness to auto
    await setBrightness(G1Brightness.auto);

    // Enable head-up display by default
    await setHeadUpDisplay(true);
  }

  Future<void> _syncTime(DateTime time) async {
    final unixTime = time.millisecondsSinceEpoch ~/ 1000;
    final tzOffset = time.timeZoneOffset.inMinutes ~/ 15; // Quarter hours

    final data = Uint8List(6);
    final view = ByteData.sublistView(data);

    view.setUint32(0, unixTime, Endian.little);
    view.setInt8(4, tzOffset);
    view.setUint8(5, 0x00); // Reserved

    await _manager.sendCommand([G1Commands.syncTime, ...data]);
  }

  /// Get battery level from the glasses.
  ///
  /// Returns the battery level when the glasses report it via callback.
  /// Listen to G1Manager's data streams to receive battery info.
  Future<void> requestBatteryLevel() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Battery level is typically reported automatically
    // This command can be used to request an immediate update
    await _manager.sendCommand([G1Commands.heartbeat]);
  }
}
