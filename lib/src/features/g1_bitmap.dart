import 'dart:math';
import 'dart:typed_data';

import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';
import '../protocol/crc32.dart';

/// G1 Bitmap feature for sending images to the glasses display.
///
/// The G1 display supports monochrome BMP images with specific encoding.
class G1Bitmap {
  final G1Manager _manager;

  /// Maximum width of the display
  static const int maxWidth = 488;

  /// Maximum height of the display
  static const int maxHeight = 126;

  G1Bitmap(this._manager);

  /// Send a BMP image to the glasses display.
  ///
  /// [bmpData] - Raw BMP file data (monochrome, 1-bit per pixel)
  /// [x] - X position offset
  /// [y] - Y position offset
  Future<void> send(Uint8List bmpData, {int x = 0, int y = 0}) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final packets = buildBMPPackets(bmpData, x: x, y: y);

    for (final packet in packets) {
      await _manager.sendCommand(packet);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Build BMP packets for transmission.
  ///
  /// Returns a list of packets to send sequentially.
  static List<Uint8List> buildBMPPackets(
    Uint8List bmpData, {
    int x = 0,
    int y = 0,
  }) {
    // Skip BMP header (62 bytes for 1-bit BMP)
    const headerSize = 62;
    if (bmpData.length <= headerSize) {
      throw ArgumentError('Invalid BMP data');
    }

    // Read dimensions from BMP header
    final view = ByteData.sublistView(bmpData);
    final width = view.getInt32(18, Endian.little);
    final height = view.getInt32(22, Endian.little).abs();

    // Extract pixel data
    final pixelData = bmpData.sublist(headerSize);

    // Calculate row stride (padded to 4 bytes)
    final rowStride = ((width + 31) ~/ 32) * 4;

    // Build packets
    final packets = <Uint8List>[];
    final maxPacketSize = 190; // Max payload per packet

    // Calculate CRC32 of the pixel data
    final crc = Crc32();
    for (final byte in pixelData) {
      crc.update([byte]);
    }
    final crcValue = crc.getValue();

    // Build header packet
    final headerPacket = _buildHeaderPacket(
      width: width,
      height: height,
      x: x,
      y: y,
      totalSize: pixelData.length,
      crc: crcValue,
    );
    packets.add(headerPacket);

    // Split data into chunks
    int offset = 0;
    int seq = 0;

    while (offset < pixelData.length) {
      final chunkSize = min(maxPacketSize, pixelData.length - offset);
      final chunk = pixelData.sublist(offset, offset + chunkSize);

      final dataPacket = _buildDataPacket(
        seq: seq,
        data: chunk,
        isLast: offset + chunkSize >= pixelData.length,
      );
      packets.add(dataPacket);

      offset += chunkSize;
      seq++;
    }

    return packets;
  }

  static Uint8List _buildHeaderPacket({
    required int width,
    required int height,
    required int x,
    required int y,
    required int totalSize,
    required int crc,
  }) {
    final packet = Uint8List(16);
    final view = ByteData.sublistView(packet);

    packet[0] = G1Commands.bmp;
    packet[1] = 0x00; // Header packet type

    view.setUint16(2, width, Endian.little);
    view.setUint16(4, height, Endian.little);
    view.setUint16(6, x, Endian.little);
    view.setUint16(8, y, Endian.little);
    view.setUint32(10, totalSize, Endian.little);
    view.setUint32(14, crc, Endian.little);

    return packet;
  }

  static Uint8List _buildDataPacket({
    required int seq,
    required List<int> data,
    required bool isLast,
  }) {
    final packet = Uint8List(4 + data.length);

    packet[0] = G1Commands.bmp;
    packet[1] = isLast ? 0x02 : 0x01; // Data packet type
    packet[2] = seq & 0xFF;
    packet[3] = (seq >> 8) & 0xFF;

    for (int i = 0; i < data.length; i++) {
      packet[4 + i] = data[i];
    }

    return packet;
  }

  /// Convert RGB color to monochrome (1-bit).
  static int rgbToMono(int r, int g, int b) {
    // Use luminance formula
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
    return luminance > 127 ? 1 : 0;
  }

  /// Create a 1-bit BMP from raw pixel data.
  ///
  /// [pixels] - 2D array of pixel values (0 or 1)
  /// [width] - Image width
  /// [height] - Image height
  static Uint8List createMonochromeBMP({
    required List<List<int>> pixels,
    required int width,
    required int height,
  }) {
    // Calculate row stride (padded to 4 bytes)
    final rowStride = ((width + 31) ~/ 32) * 4;
    final pixelDataSize = rowStride * height;

    // BMP file size
    const headerSize = 62;
    final fileSize = headerSize + pixelDataSize;

    final bmp = Uint8List(fileSize);
    final view = ByteData.sublistView(bmp);

    // BMP File Header (14 bytes)
    bmp[0] = 0x42; // 'B'
    bmp[1] = 0x4D; // 'M'
    view.setUint32(2, fileSize, Endian.little);
    view.setUint32(10, headerSize, Endian.little);

    // DIB Header (40 bytes)
    view.setUint32(14, 40, Endian.little); // Header size
    view.setInt32(18, width, Endian.little);
    view.setInt32(22, -height, Endian.little); // Negative = top-down
    view.setUint16(26, 1, Endian.little); // Planes
    view.setUint16(28, 1, Endian.little); // Bits per pixel
    view.setUint32(30, 0, Endian.little); // Compression (none)
    view.setUint32(34, pixelDataSize, Endian.little);

    // Color Table (8 bytes for 1-bit)
    // Color 0: Black
    bmp[54] = 0x00;
    bmp[55] = 0x00;
    bmp[56] = 0x00;
    bmp[57] = 0x00;
    // Color 1: White
    bmp[58] = 0xFF;
    bmp[59] = 0xFF;
    bmp[60] = 0xFF;
    bmp[61] = 0x00;

    // Pixel data
    for (int y = 0; y < height; y++) {
      int byteIndex = headerSize + y * rowStride;
      int bitIndex = 0;
      int currentByte = 0;

      for (int x = 0; x < width; x++) {
        if (pixels[y][x] == 1) {
          currentByte |= (1 << (7 - bitIndex));
        }

        bitIndex++;
        if (bitIndex == 8) {
          bmp[byteIndex++] = currentByte;
          currentByte = 0;
          bitIndex = 0;
        }
      }

      // Write remaining bits
      if (bitIndex > 0) {
        bmp[byteIndex] = currentByte;
      }
    }

    return bmp;
  }
}
