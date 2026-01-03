import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'bluetooth_constants.dart';
import 'g1_connection_state.dart';
import 'g1_glass.dart';
import '../protocol/commands.dart';
import '../features/g1_display.dart';
import '../features/g1_notifications.dart';
import '../features/g1_navigation.dart';
import '../features/g1_dashboard.dart';
import '../features/g1_notes.dart';
import '../features/g1_time_weather.dart';
import '../features/g1_settings.dart';
import '../features/g1_bitmap.dart';
import '../features/g1_translate.dart';
import '../voice/g1_microphone.dart';
import '../voice/g1_voice_note.dart';

/// Callback for glasses discovery
typedef OnGlassesFound = void Function(String leftName, String rightName);

/// Callback for connection success
typedef OnConnected = void Function();

/// Callback for status updates
typedef OnStatusUpdate = void Function(String message);

/// Main manager class for Even Realities G1 smart glasses.
///
/// This is the primary entry point for controlling G1 glasses. It handles:
/// - Bluetooth scanning and connection
/// - Managing left and right glasses
/// - Providing access to all G1 features (display, notifications, etc.)
///
/// Example:
/// ```dart
/// final g1 = G1Manager();
///
/// await g1.startScan(
///   onGlassesFound: (left, right) => print('Found!'),
///   onConnected: () => print('Connected!'),
/// );
///
/// await g1.display.showText('Hello G1!');
/// ```
class G1Manager {
  /// Singleton instance
  static final G1Manager _instance = G1Manager._internal();

  /// Factory constructor returns singleton
  factory G1Manager() => _instance;

  G1Manager._internal() {
    _initializeFeatures();
  }

  // Glass instances
  G1Glass? _leftGlass;
  G1Glass? _rightGlass;

  // Scanning state
  Timer? _scanTimer;
  StreamSubscription? _scanSubscription;
  bool _isScanning = false;
  int _retryCount = 0;
  bool _connectionCallbackFired = false;

  // Features
  late final G1Display display;
  late final G1Notifications notifications;
  late final G1Navigation navigation;
  late final G1Dashboard dashboard;
  late final G1Notes notes;
  late final G1TimeWeather timeWeather;
  late final G1Settings settings;
  late final G1Bitmap bitmap;
  late final G1Translate translate;
  late final G1Microphone microphone;
  late final G1VoiceNote voiceNote;

  // Connection state stream
  final _connectionStateController =
      StreamController<G1ConnectionEvent>.broadcast();

  /// Stream of connection state changes
  Stream<G1ConnectionEvent> get connectionState =>
      _connectionStateController.stream;

  /// Left glass instance (null if not connected)
  G1Glass? get leftGlass => _leftGlass;

  /// Right glass instance (null if not connected)
  G1Glass? get rightGlass => _rightGlass;

  /// Whether both glasses are connected
  bool get isConnected =>
      _leftGlass?.isConnected == true && _rightGlass?.isConnected == true;

  /// Whether both glasses are connected (alias for isConnected)
  bool get isBothConnected => isConnected;

  /// Whether at least one glass is connected
  bool get isAnyConnected =>
      _leftGlass?.isConnected == true || _rightGlass?.isConnected == true;

  /// Whether scanning is in progress
  bool get isScanning => _isScanning;

  /// Callback for data received from glasses
  G1DataCallback? onDataReceived;

  /// Callback for connection state changes
  void Function(G1ConnectionState state, GlassSide? side)? onConnectionChanged;

  void _initializeFeatures() {
    display = G1Display(this);
    notifications = G1Notifications(this);
    navigation = G1Navigation(this);
    dashboard = G1Dashboard(this);
    notes = G1Notes(this);
    timeWeather = G1TimeWeather(this);
    settings = G1Settings(this);
    bitmap = G1Bitmap(this);
    translate = G1Translate(this);
    microphone = G1Microphone(this);
    voiceNote = G1VoiceNote(this);
  }

  /// Initialize the Bluetooth manager.
  ///
  /// Must be called before scanning. Optionally set log level.
  Future<void> initialize({LogLevel logLevel = LogLevel.none}) async {
    FlutterBluePlus.setLogLevel(logLevel);
  }

  /// Request necessary Bluetooth permissions.
  ///
  /// Returns true if all permissions are granted.
  Future<bool> requestPermissions() async {
    // Permission handling should be done by the app using this library
    // This is a placeholder for documentation
    return true;
  }

  /// Start scanning for G1 glasses and connect when found.
  ///
  /// [onUpdate] - Called with status updates during scanning
  /// [onGlassesFound] - Called when both glasses are discovered
  /// [onConnected] - Called when both glasses are connected
  /// [timeout] - Scan timeout duration
  Future<void> startScan({
    OnStatusUpdate? onUpdate,
    OnGlassesFound? onGlassesFound,
    OnConnected? onConnected,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!await FlutterBluePlus.isSupported) {
      final msg = 'Bluetooth is not supported on this device';
      onUpdate?.call(msg);
      throw Exception(msg);
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      final msg = 'Bluetooth is turned off';
      onUpdate?.call(msg);
      throw Exception(msg);
    }

    // Reset state
    _isScanning = true;
    _retryCount = 0;
    _connectionCallbackFired = false;
    _leftGlass = null;
    _rightGlass = null;

    _connectionStateController.add(const G1ConnectionEvent(
      state: G1ConnectionState.scanning,
    ));
    onConnectionChanged?.call(G1ConnectionState.scanning, null);

    // First check for already connected/bonded devices
    onUpdate?.call('Checking for paired glasses...');
    final connected = await _checkConnectedDevices(onUpdate, onGlassesFound, onConnected);
    if (connected) {
      return;
    }

    await _startScan(onUpdate, onGlassesFound, onConnected, timeout);
  }

  /// Check for already connected or bonded G1 glasses
  Future<bool> _checkConnectedDevices(
    OnStatusUpdate? onUpdate,
    OnGlassesFound? onGlassesFound,
    OnConnected? onConnected,
  ) async {
    try {
      // Check system connected devices
      final connectedDevices = await FlutterBluePlus.systemDevices([]);
      debugPrint('Found ${connectedDevices.length} system connected devices');
      
      for (final device in connectedDevices) {
        final name = device.platformName;
        debugPrint('Checking connected device: $name');
        
        if (name.contains(BluetoothConstants.leftGlassPattern) && _leftGlass == null) {
          debugPrint('Found already-connected left glass: $name');
          _leftGlass = G1Glass(
            name: name,
            device: device,
            side: GlassSide.left,
            onDataReceived: _handleDataReceived,
          );
          await _leftGlass!.connect();
          _setupReconnect(_leftGlass!);
          onUpdate?.call('Left glass found (already paired): $name');
        } else if (name.contains(BluetoothConstants.rightGlassPattern) && _rightGlass == null) {
          debugPrint('Found already-connected right glass: $name');
          _rightGlass = G1Glass(
            name: name,
            device: device,
            side: GlassSide.right,
            onDataReceived: _handleDataReceived,
          );
          await _rightGlass!.connect();
          _setupReconnect(_rightGlass!);
          onUpdate?.call('Right glass found (already paired): $name');
        }
      }

      // Check bonded devices as well
      final bondedDevices = await FlutterBluePlus.bondedDevices;
      debugPrint('Found ${bondedDevices.length} bonded devices');
      
      for (final device in bondedDevices) {
        final name = device.platformName;
        debugPrint('Checking bonded device: $name');
        
        if (name.contains(BluetoothConstants.leftGlassPattern) && _leftGlass == null) {
          debugPrint('Found bonded left glass: $name');
          _leftGlass = G1Glass(
            name: name,
            device: device,
            side: GlassSide.left,
            onDataReceived: _handleDataReceived,
          );
          await _leftGlass!.connect();
          _setupReconnect(_leftGlass!);
          onUpdate?.call('Left glass found (bonded): $name');
        } else if (name.contains(BluetoothConstants.rightGlassPattern) && _rightGlass == null) {
          debugPrint('Found bonded right glass: $name');
          _rightGlass = G1Glass(
            name: name,
            device: device,
            side: GlassSide.right,
            onDataReceived: _handleDataReceived,
          );
          await _rightGlass!.connect();
          _setupReconnect(_rightGlass!);
          onUpdate?.call('Right glass found (bonded): $name');
        }
      }

      // Check if both glasses are now connected
      if (_leftGlass != null && _rightGlass != null &&
          _leftGlass!.isConnected && _rightGlass!.isConnected) {
        _connectionCallbackFired = true;
        _isScanning = false;
        
        onGlassesFound?.call(_leftGlass!.name, _rightGlass!.name);
        _connectionStateController.add(G1ConnectionEvent(
          state: G1ConnectionState.connected,
          leftGlassName: _leftGlass!.name,
          rightGlassName: _rightGlass!.name,
        ));
        onConnectionChanged?.call(G1ConnectionState.connected, null);
        onConnected?.call();
        return true;
      }
    } catch (e) {
      debugPrint('Error checking connected devices: $e');
    }
    return false;
  }

  Future<void> _startScan(
    OnStatusUpdate? onUpdate,
    OnGlassesFound? onGlassesFound,
    OnConnected? onConnected,
    Duration timeout,
  ) async {
    // Cancel any existing subscription to avoid stacking listeners
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    debugPrint(
        'Starting scan attempt ${_retryCount + 1}/${BluetoothConstants.maxScanRetries}');

    // Set scan timeout
    _scanTimer?.cancel();
    _scanTimer = Timer(timeout, () {
      if (_isScanning) {
        _handleScanTimeout(onUpdate, onGlassesFound, onConnected, timeout);
      }
    });

    // Subscribe to scan results BEFORE starting scan
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          final deviceName = result.device.platformName;
          final advName = result.advertisementData.advName;
          final name = deviceName.isNotEmpty ? deviceName : advName;
          
          if (name.isNotEmpty) {
            debugPrint('Found device: $name (platformName: $deviceName, advName: $advName)');
            _handleDeviceFound(
                result, name, onUpdate, onGlassesFound, onConnected);
          }
        }
      },
      onError: (error) {
        debugPrint('Scan error: $error');
        onUpdate?.call(error.toString());
      },
    );

    await FlutterBluePlus.startScan(
      // Note: G1 glasses may not advertise UART service in ads, so we filter by name pattern instead
      timeout: timeout,
      androidUsesFineLocation: true,
    );
  }

  Future<void> _handleDeviceFound(
    ScanResult result,
    String deviceName,
    OnStatusUpdate? onUpdate,
    OnGlassesFound? onGlassesFound,
    OnConnected? onConnected,
  ) async {
    G1Glass? glass;

    if (deviceName.contains(BluetoothConstants.leftGlassPattern) &&
        _leftGlass == null) {
      debugPrint('Found left glass: $deviceName');
      glass = G1Glass(
        name: deviceName,
        device: result.device,
        side: GlassSide.left,
        onDataReceived: _handleDataReceived,
      );
      _leftGlass = glass;
      onUpdate?.call('Left glass found: $deviceName');
    } else if (deviceName.contains(BluetoothConstants.rightGlassPattern) &&
        _rightGlass == null) {
      debugPrint('Found right glass: $deviceName');
      glass = G1Glass(
        name: deviceName,
        device: result.device,
        side: GlassSide.right,
        onDataReceived: _handleDataReceived,
      );
      _rightGlass = glass;
      onUpdate?.call('Right glass found: $deviceName');
    }

    if (glass != null) {
      await glass.connect();
      _setupReconnect(glass);
      
      // Check if both glasses are now connected after this connection completes
      _checkBothConnected(onUpdate, onGlassesFound, onConnected);
    }
  }
  
  void _checkBothConnected(
    OnStatusUpdate? onUpdate,
    OnGlassesFound? onGlassesFound,
    OnConnected? onConnected,
  ) {
    // Prevent duplicate callbacks
    if (_connectionCallbackFired) return;
    
    // Check if both glasses are found and connected
    if (_leftGlass != null && _rightGlass != null &&
        _leftGlass!.isConnected && _rightGlass!.isConnected) {
      _connectionCallbackFired = true;
      
      if (_isScanning) {
        _isScanning = false;
        stopScan();
      }

      onGlassesFound?.call(_leftGlass!.name, _rightGlass!.name);
      
      _connectionStateController.add(G1ConnectionEvent(
        state: G1ConnectionState.connected,
        leftGlassName: _leftGlass!.name,
        rightGlassName: _rightGlass!.name,
      ));
      onConnectionChanged?.call(G1ConnectionState.connected, null);
      onConnected?.call();
    }
  }

  Future<void> _handleDataReceived(GlassSide side, List<int> data) async {
    // Forward to voice/microphone handlers
    await microphone.handleData(side, data);
    await voiceNote.handleData(side, data);

    // Forward to user callback
    if (onDataReceived != null) {
      await onDataReceived!(side, data);
    }
  }

  void _setupReconnect(G1Glass glass) {
    glass.connectionState.listen((state) {
      debugPrint('[${glass.side} Glass] Connection state: $state');
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('[${glass.side} Glass] Attempting reconnect...');
        glass.connect();
      }
    });
  }

  void _handleScanTimeout(
    OnStatusUpdate? onUpdate,
    OnGlassesFound? onGlassesFound,
    OnConnected? onConnected,
    Duration timeout,
  ) async {
    debugPrint('Scan timeout');

    if (_retryCount < BluetoothConstants.maxScanRetries &&
        (_leftGlass == null || _rightGlass == null)) {
      _retryCount++;
      debugPrint(
          'Retrying scan (${_retryCount}/${BluetoothConstants.maxScanRetries})');
      await _startScan(onUpdate, onGlassesFound, onConnected, timeout);
    } else {
      _isScanning = false;
      await stopScan();

      final message = _leftGlass == null && _rightGlass == null
          ? 'No glasses found'
          : 'Scan completed';
      onUpdate?.call(message);

      _connectionStateController.add(G1ConnectionEvent(
        state: _leftGlass == null && _rightGlass == null
            ? G1ConnectionState.error
            : G1ConnectionState.connected,
        errorMessage:
            _leftGlass == null && _rightGlass == null ? message : null,
      ));
      onConnectionChanged?.call(
        _leftGlass == null && _rightGlass == null
            ? G1ConnectionState.error
            : G1ConnectionState.connected,
        null,
      );
    }
  }

  /// Configure Even AI interaction callbacks (touch bar + AI session lifecycle).
  ///
  /// This mirrors the behavior in the visionlink and fahrplan samples:
  /// - left tap  => page up
  /// - right tap => page down
  /// - double tap => exit to dashboard
  /// - AI session start/stop => long-press on touch bar begins/ends recording
  void configureEvenAI({
    void Function()? onLeftTap,
    void Function()? onRightTap,
    void Function()? onDoubleTap,
    void Function()? onExitToDashboard,
    void Function()? onAISessionStart,
    void Function(List<int> audioData)? onAISessionEnd,
  }) {
    microphone.onLeftTap = onLeftTap;
    microphone.onRightTap = onRightTap;
    microphone.onDoubleTap = onDoubleTap;
    microphone.onExitToDashboard = onExitToDashboard;
    microphone.onAISessionStart = onAISessionStart;
    microphone.onAISessionEnd = onAISessionEnd;
  }

  /// Configure voice note callbacks (quick note notification + audio fetch).
  ///
  /// When the glasses send a quick note notification, the newest note is
  /// automatically fetched and the audio is provided via [onAudioReady].
  void configureVoiceNotes({
    void Function(List<VoiceNote> notes)? onNotesUpdated,
    void Function(int index, List<int> audioData)? onAudioReady,
  }) {
    voiceNote.onNotesUpdated = onNotesUpdated;
    voiceNote.onAudioReady = onAudioReady;
  }

  /// Stop scanning for glasses.
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    debugPrint('Scanning stopped');
  }

  /// Connect to previously paired glasses using stored identifiers.
  ///
  /// [leftId] - The Bluetooth device ID of the left glass
  /// [rightId] - The Bluetooth device ID of the right glass
  /// [leftName] - Optional display name for left glass
  /// [rightName] - Optional display name for right glass
  Future<void> connectToKnownGlasses({
    required String leftId,
    required String rightId,
    String? leftName,
    String? rightName,
  }) async {
    _leftGlass = G1Glass(
      name: leftName ?? 'Left Glass',
      device: BluetoothDevice(remoteId: DeviceIdentifier(leftId)),
      side: GlassSide.left,
      onDataReceived: _handleDataReceived,
    );

    _rightGlass = G1Glass(
      name: rightName ?? 'Right Glass',
      device: BluetoothDevice(remoteId: DeviceIdentifier(rightId)),
      side: GlassSide.right,
      onDataReceived: _handleDataReceived,
    );

    await _leftGlass!.connect();
    _setupReconnect(_leftGlass!);

    await _rightGlass!.connect();
    _setupReconnect(_rightGlass!);

    _connectionStateController.add(G1ConnectionEvent(
      state: G1ConnectionState.connected,
      leftGlassName: _leftGlass!.name,
      rightGlassName: _rightGlass!.name,
    ));
    onConnectionChanged?.call(G1ConnectionState.connected, null);
  }

  /// Send a command to both glasses.
  ///
  /// [command] - The data to send
  /// [needsAck] - Whether to wait for acknowledgment
  /// [delay] - Delay between sends (if not using ACK)
  Future<void> sendCommand(
    List<int> command, {
    bool needsAck = true,
    Duration delay = Duration.zero,
  }) async {
    if (_leftGlass != null) {
      if (needsAck) {
        await _leftGlass!.sendDataWithAck(command);
      } else {
        await _leftGlass!.sendData(command);
        if (delay > Duration.zero) {
          await Future.delayed(delay);
        }
      }
    }

    if (_rightGlass != null) {
      if (needsAck) {
        await _rightGlass!.sendDataWithAck(command);
      } else {
        await _rightGlass!.sendData(command);
        if (delay > Duration.zero) {
          await Future.delayed(delay);
        }
      }
    }
  }

  /// Send a command to a specific side.
  Future<void> sendCommandToSide(
    GlassSide side,
    List<int> command, {
    bool needsAck = true,
    Duration delay = Duration.zero,
  }) async {
    final glass = side == GlassSide.left ? _leftGlass : _rightGlass;
    if (glass == null) return;

    if (needsAck) {
      await glass.sendDataWithAck(command);
      return;
    }

    await glass.sendData(command);
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
  }

  /// Clear the display on both glasses.
  Future<void> clearScreen() async {
    await sendCommand([G1Commands.clearScreen]);
  }

  /// Disconnect from both glasses.
  Future<void> disconnect() async {
    await _leftGlass?.disconnect();
    await _rightGlass?.disconnect();

    _leftGlass = null;
    _rightGlass = null;

    _connectionStateController.add(const G1ConnectionEvent(
      state: G1ConnectionState.disconnected,
    ));
    onConnectionChanged?.call(G1ConnectionState.disconnected, null);
  }

  /// Dispose of resources.
  void dispose() {
    _scanTimer?.cancel();
    _connectionStateController.close();
  }
}
