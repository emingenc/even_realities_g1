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

/// Double-tap action options
enum G1DoubleTapActionType {
  /// Close active feature / Do nothing
  none(0x00),

  /// Open Translate feature
  translate(0x02),

  /// Open Teleprompter feature
  teleprompter(0x03),

  /// Show Dashboard
  dashboard(0x04),

  /// Open Transcribe feature
  transcribe(0x05);

  final int value;
  const G1DoubleTapActionType(this.value);
}

/// Head-up action behavior
enum G1HeadUpActionType {
  /// Show the Dashboard when looking up
  showDashboard(0x00),

  /// Do nothing when looking up
  doNothing(0x02);

  final int value;
  const G1HeadUpActionType(this.value);
}

/// System language options
enum G1SystemLanguageType {
  chinese(0x01),
  english(0x02),
  japanese(0x03),
  french(0x05),
  german(0x06),
  spanish(0x07),
  italian(0x0E);

  final int value;
  const G1SystemLanguageType(this.value);
}

/// G1 Settings feature for device configuration.
class G1Settings {
  final G1Manager _manager;
  int _hardwareSeq = 0;

  G1Settings(this._manager);

  int _nextSeq() {
    final seq = _hardwareSeq;
    _hardwareSeq = (_hardwareSeq + 1) % 256;
    return seq;
  }

  /// Set display brightness.
  Future<void> setBrightness(G1Brightness brightness) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Python: [Command.BRIGHTNESS, level, auto] sent to BOTH glasses
    final bool auto = brightness == G1Brightness.auto;
    final int level = switch (brightness) {
      G1Brightness.auto => 0x00,
      G1Brightness.level1 => 0x08,
      G1Brightness.level2 => 0x10,
      G1Brightness.level3 => 0x18,
      G1Brightness.level4 => 0x20,
      G1Brightness.level5 => 0x2A,
    };

    await _manager.sendCommand([
      G1Commands.brightness,
      level & 0xFF,
      auto ? 0x01 : 0x00,
    ]);
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

    // Python: [Command.HEADUP_ANGLE, angle, 0x01] sent to BOTH glasses
    await _manager.sendCommand([
      G1Commands.headUpAngle,
      angle.clamp(0, 60),
      0x01,
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

  /// Set what action happens when user double-taps the touchpad.
  ///
  /// [action] - The action to perform on double-tap
  Future<void> setDoubleTapAction(G1DoubleTapActionType action) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Hardware Set (0x26): 26 06 00 [seq] 04 [action]
    // Subcommand 0x04 is for double-tap action
    // Send to both glasses to ensure setting is applied
    final seq = _nextSeq();
    await _manager.sendCommand([
      G1Commands.hardwareSet,
      0x06, // length
      0x00, // padding
      seq,
      G1HardwareSubCommands.doubleTapAction,
      action.value,
    ]);
  }

  /// Enable or disable long-press action.
  ///
  /// When enabled, long-pressing the touchpad triggers an action.
  Future<void> setLongPressEnabled(bool enabled) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Hardware Set (0x26): 26 06 00 [seq] 07 [0/1]
    // Send to both glasses to ensure setting is applied
    final seq = _nextSeq();
    await _manager.sendCommand([
      G1Commands.hardwareSet,
      0x06, // length
      0x00, // padding
      seq,
      G1HardwareSubCommands.longPressAction,
      enabled ? 0x01 : 0x00,
    ]);
  }

  /// Enable or disable microphone activation on head lift.
  ///
  /// When enabled, lifting your head will start audio streaming to the phone.
  Future<void> setHeadLiftMicEnabled(bool enabled) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Hardware Set (0x26): 26 06 00 [seq] 08 [0/1]
    // Note: Mic-related commands go to right glass only per protocol
    final seq = _nextSeq();
    await _manager.sendCommandToSide(
      GlassSide.right,
      [
        G1Commands.hardwareSet,
        0x06, // length
        0x00, // padding
        seq,
        G1HardwareSubCommands.headLiftMic,
        enabled ? 0x01 : 0x00,
      ],
    );
  }

  /// Start wake-word detection (AI wake word).
  Future<void> startWakeWordDetection() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Best-effort: send start AI wake-word subcommand to right glass
    await _manager.sendCommandToSide(
      GlassSide.right,
      [G1Commands.startAI, G1AISubCommands.startWakeWord],
    );
  }

  /// Stop wake-word detection.
  Future<void> stopWakeWordDetection() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommandToSide(
      GlassSide.right,
      [G1Commands.startAI, G1AISubCommands.stopWakeWord],
    );
  }

  /// Set what happens when the user looks up (head lift action).
  ///
  /// [action] - The action to perform on head lift
  Future<void> setHeadUpAction(G1HeadUpActionType action) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Head Up Action Set (0x08): 08 06 00 [seq] [03/04] [action]
    // 03 = send to left only (left forwards to right)
    // 04 = send to both
    final seq = _nextSeq();
    await _manager.sendCommand([
      G1Commands.headUpAction,
      0x06, // length
      0x00, // padding
      seq,
      0x04, // send to both sides
      action.value,
    ]);
  }

  /// Set display height and depth position.
  ///
  /// [height] - Height position (0-8)
  /// [depth] - Depth position (1-9)
  /// [preview] - If true, preview the setting temporarily; if false, save it
  Future<void> setDisplayPosition({
    required int height,
    required int depth,
    bool preview = false,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Hardware Set (0x26): 26 08 00 [seq] 02 [preview] [height] [depth]
    // Send to both glasses to ensure setting is applied
    final seq = _nextSeq();
    await _manager.sendCommand([
      G1Commands.hardwareSet,
      0x08, // length
      0x00, // padding
      seq,
      G1HardwareSubCommands.heightAndDepth,
      preview ? 0x01 : 0x00,
      height.clamp(0, 8),
      depth.clamp(1, 9),
    ]);
  }

  /// Enable or disable wear detection.
  ///
  /// When enabled, the glasses detect if they're being worn and send events.
  Future<void> setWearDetection(bool enabled) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Wear Detection Set (0x27): 27 [0/1]
    await _manager.sendCommand([
      G1Commands.wearDetection,
      enabled ? 0x01 : 0x00,
    ]);
  }

  /// Set the glasses system language.
  Future<void> setLanguage(G1SystemLanguageType language) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Language Set (0x3D): 3D 06 00 [seq] 01 [language]
    final seq = _nextSeq();
    await _manager.sendCommand([
      G1Commands.languageSet,
      0x06,
      0x00,
      seq,
      0x01,
      language.value,
    ]);
  }

  /// Send a heartbeat to keep the connection alive.
  Future<void> heartbeat() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand([G1Commands.heartbeat]);
  }

  /// Reboot the glasses.
  ///
  /// Warning: This will disconnect the BLE connection.
  Future<void> reboot() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // System Control (0x23): 23 72
    await _manager.sendCommand([
      G1Commands.systemControl,
      G1SystemControlSubCommands.reboot,
    ]);
  }

  /// Enable or disable debug logging on the glasses.
  ///
  /// When enabled, debug messages are sent via 0xF4 packets.
  Future<void> setDebugLogging(bool enabled) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // System Control (0x23): 23 6C [00=enable / C1=disable]
    await _manager.sendCommand([
      G1Commands.systemControl,
      G1SystemControlSubCommands.debugLogging,
      enabled ? 0x00 : 0xC1,
    ]);
  }

  /// Request firmware build info from the glasses.
  ///
  /// The response will be received via the data callback as raw ASCII.
  Future<void> requestFirmwareInfo() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // System Control (0x23): 23 74
    await _manager.sendCommand([
      G1Commands.systemControl,
      G1SystemControlSubCommands.firmwareBuildInfo,
    ]);
  }

  /// Request battery and firmware info.
  ///
  /// [side] - Which side to query (1=left, 2=right)
  Future<void> requestBatteryInfo({int side = 1}) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Info Battery and Firmware Get (0x2C): 2C [01/02]
    await _manager.sendCommand([
      G1Commands.infoBatteryFirmware,
      side.clamp(1, 2),
    ]);
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
