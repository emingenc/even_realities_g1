import 'dart:typed_data';

/// CRC32 implementation for G1 glasses.
///
/// Used for verifying bitmap and data integrity during transmission.
class Crc32 {
  static const int _polynomial = 0xEDB88320;
  static final List<int> _table = _generateTable();

  int _crc = 0xFFFFFFFF;

  static List<int> _generateTable() {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = i;
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) == 1) {
          crc = (crc >> 1) ^ _polynomial;
        } else {
          crc >>= 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// Add bytes to the CRC calculation.
  void add(List<int> data) {
    for (final byte in data) {
      _crc = _table[(_crc ^ byte) & 0xFF] ^ (_crc >> 8);
    }
  }

  /// Alias for add() - update the CRC with new data.
  void update(List<int> data) => add(data);

  /// Get the current CRC value without finalizing.
  int getValue() => _crc ^ 0xFFFFFFFF;

  /// Finalize and return the CRC32 value.
  int close() {
    return _crc ^ 0xFFFFFFFF;
  }

  /// Calculate CRC32 for a byte array.
  static int calculate(Uint8List data) {
    final crc = Crc32();
    crc.add(data);
    return crc.close();
  }

  /// Convert CRC32 value to bytes (big-endian).
  static Uint8List toBytes(int crc32) {
    final bytes = Uint8List(4);
    bytes[0] = (crc32 >> 24) & 0xFF;
    bytes[1] = (crc32 >> 16) & 0xFF;
    bytes[2] = (crc32 >> 8) & 0xFF;
    bytes[3] = crc32 & 0xFF;
    return bytes;
  }
}
