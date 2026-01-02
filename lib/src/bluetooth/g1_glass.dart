import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'bluetooth_constants.dart';
import 'g1_connection_state.dart';
import '../protocol/commands.dart';

/// Callback for receiving data from glasses
typedef G1DataCallback = Future<void> Function(GlassSide side, List<int> data);

/// Represents a single G1 glass (left or right).
///
/// Handles BLE connection, UART communication, and heartbeat for one glass.
class G1Glass {
  /// The display name of this glass
  final String name;

  /// Which side this glass is on
  final GlassSide side;

  /// The underlying Bluetooth device
  final BluetoothDevice device;

  /// Callback for when data is received
  G1DataCallback? onDataReceived;

  BluetoothCharacteristic? _uartTx;
  BluetoothCharacteristic? _uartRx;
  StreamSubscription<List<int>>? _notificationSubscription;
  Timer? _heartbeatTimer;
  int _heartbeatSeq = 0;

  // ACK tracking for reliable transmission
  final Map<int, Completer<void>> _ackCompleters = {};

  /// Whether this glass is currently connected
  bool get isConnected => device.isConnected;

  /// Creates a new G1Glass instance.
  G1Glass({
    required this.name,
    required this.device,
    required this.side,
    this.onDataReceived,
  });

  /// Connect to this glass and set up UART communication.
  Future<void> connect() async {
    try {
      await device.connect();
      await _discoverServices();
      await device.requestMtu(BluetoothConstants.defaultMtu);
      await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );
      _startHeartbeat();
      debugPrint('[$side Glass] Connected successfully');
    } catch (e) {
      debugPrint('[$side Glass] Connection error: $e');
      rethrow;
    }
  }

  Future<void> _discoverServices() async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toUpperCase() ==
          BluetoothConstants.uartServiceUuid) {
        for (final characteristic in service.characteristics) {
          final uuid = characteristic.uuid.toString().toUpperCase();

          if (uuid == BluetoothConstants.uartTxCharUuid) {
            if (characteristic.properties.write) {
              _uartTx = characteristic;
              debugPrint('[$side Glass] UART TX found and writable');
            }
          } else if (uuid == BluetoothConstants.uartRxCharUuid) {
            _uartRx = characteristic;
          }
        }
      }
    }

    if (_uartRx != null) {
      await _uartRx!.setNotifyValue(true);
      _notificationSubscription = _uartRx!.lastValueStream.listen(_handleNotification);
      debugPrint('[$side Glass] UART RX notifications enabled');
    } else {
      debugPrint('[$side Glass] UART RX not found');
    }

    if (_uartTx == null) {
      debugPrint('[$side Glass] UART TX not found');
    }
  }

  void _handleNotification(List<int> data) async {
    if (data.isEmpty) return;

    // Check for ACK response
    final commandByte = data[0];
    if (_ackCompleters.containsKey(commandByte) && data.length >= 2) {
      final status = data[1];
      if (status == G1ResponseStatus.success || status == 0xCB) {
        _ackCompleters[commandByte]?.complete();
        _ackCompleters.remove(commandByte);
      } else if (status == G1ResponseStatus.failure) {
        _ackCompleters[commandByte]?.completeError(
          StateError('Command failed: 0x${commandByte.toRadixString(16)}'),
        );
        _ackCompleters.remove(commandByte);
      }
    }

    // Forward data to callback
    if (onDataReceived != null) {
      await onDataReceived!(side, data);
    }
  }

  /// Send data to the glass without waiting for ACK.
  Future<void> sendData(List<int> data) async {
    if (_uartTx == null) {
      debugPrint('[$side Glass] UART TX not available');
      return;
    }

    try {
      await _uartTx!.write(data, withoutResponse: false);
    } catch (e) {
      debugPrint('[$side Glass] Error sending data: $e');
      rethrow;
    }
  }

  /// Send data and wait for ACK with timeout.
  Future<void> sendDataWithAck(
    List<int> data, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_uartTx == null) {
      debugPrint('[$side Glass] UART TX not available');
      return;
    }

    if (data.isEmpty) {
      debugPrint('[$side Glass] Cannot send empty data');
      return;
    }

    final commandByte = data[0];
    final completer = Completer<void>();
    _ackCompleters[commandByte] = completer;

    try {
      await _uartTx!.write(data, withoutResponse: false);

      await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint(
            '[$side Glass] ACK timeout for 0x${commandByte.toRadixString(16)}',
          );
          _ackCompleters.remove(commandByte);
        },
      );
    } catch (e) {
      debugPrint('[$side Glass] Error sending data: $e');
      _ackCompleters.remove(commandByte);
      rethrow;
    }
  }

  List<int> _buildHeartbeat(int seq) {
    const length = 6;
    return [
      G1Commands.heartbeat,
      length & 0xFF,
      (length >> 8) & 0xFF,
      seq % 0xFF,
      0x04,
      seq % 0xFF,
    ];
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: BluetoothConstants.heartbeatIntervalSeconds),
      (timer) async {
        if (device.isConnected) {
          await sendData(_buildHeartbeat(_heartbeatSeq++));
        }
      },
    );
  }

  /// Disconnect from this glass.
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    await _notificationSubscription?.cancel();
    await device.disconnect();
    debugPrint('[$side Glass] Disconnected');
  }

  /// Listen to connection state changes.
  Stream<BluetoothConnectionState> get connectionState =>
      device.connectionState;

  @override
  String toString() => 'G1Glass($side, $name)';
}
