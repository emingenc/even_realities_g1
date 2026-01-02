import '../bluetooth/g1_connection_state.dart';
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

    // Wiki: Brightness Set (0x01) payload is [level(0x00..0x2A), auto(0/1)] and is sent to Right.
    final bool auto = brightness == G1Brightness.auto;
    final int level = switch (brightness) {
      G1Brightness.auto => 0x00,
      G1Brightness.level1 => 0x08,
      G1Brightness.level2 => 0x10,
      G1Brightness.level3 => 0x18,
      G1Brightness.level4 => 0x20,
      G1Brightness.level5 => 0x2A,
    };

    await _manager.sendCommandToSide(
      GlassSide.right,
      [
        G1Commands.brightness,
        level & 0xFF,
        auto ? 0x01 : 0x00,
      ],
    );
  }

  /// Enable or disable silent mode.
  ///
  /// When enabled, the glasses won't play sounds.
  Future<void> setSilentMode(bool enabled) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Wiki: Silent Mode Set (0x03) uses fixed bytes: 0x0C (on) / 0x0A (off)
    await _manager.sendCommand([
      G1Commands.silentMode,
      enabled ? 0x0C : 0x0A,
    ]);
  }

  /// Set the head-up display angle.
  ///
  /// This adjusts when the display activates based on head tilt.
  Future<void> setHeadUpAngle(int angle) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Wiki: Head Up Angle Set (0x0B) appears as [0x0B, 0x00..0x3C, 0x01] and is sent to Right.
    await _manager.sendCommandToSide(
      GlassSide.right,
      [
        G1Commands.headUpAngle,
        angle.clamp(0, 60),
        0x01,
      ],
    );
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

    // Set default brightness to auto
    await setBrightness(G1Brightness.auto);

    // Enable head-up display by default
    await setHeadUpDisplay(true);
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
