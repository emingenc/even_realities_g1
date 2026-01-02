/// Bluetooth constants for Even Realities G1 glasses.
///
/// These UUIDs are used for UART communication with the G1 glasses.
class BluetoothConstants {
  BluetoothConstants._();

  /// UART Service UUID for G1 glasses
  static const String uartServiceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  /// UART TX Characteristic UUID (write to glasses)
  static const String uartTxCharUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

  /// UART RX Characteristic UUID (receive from glasses)
  static const String uartRxCharUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  /// Device name pattern for left glass
  static const String leftGlassPattern = '_L_';

  /// Device name pattern for right glass
  static const String rightGlassPattern = '_R_';

  /// Default MTU size
  static const int defaultMtu = 251;

  /// Heartbeat interval in seconds
  static const int heartbeatIntervalSeconds = 5;

  /// Default scan timeout in seconds
  static const int scanTimeoutSeconds = 30;

  /// Maximum retry attempts for scanning
  static const int maxScanRetries = 3;
}
