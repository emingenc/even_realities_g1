import 'dart:typed_data';

import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';
import '../protocol/crc32.dart';

/// G1 Bitmap feature for sending images to the glasses display.
///
/// The G1 display supports monochrome BMP images (576x136 pixels).
/// This implementation matches the visionlink reference.
class G1Bitmap {
  final G1Manager _manager;

  /// Canvas width for display
  static const int canvasWidth = 576;

  /// Canvas height for display  
  static const int canvasHeight = 136;

  /// Maximum width of the display
  static const int maxWidth = 488;

  /// Maximum height of the display
  static const int maxHeight = 126;

  G1Bitmap(this._manager);

  /// Send a BMP image to the glasses display.
  ///
  /// [bmpData] - Raw BMP file data (monochrome, 1-bit per pixel)
  /// The BMP should be 576x136 pixels for best results.
  Future<void> send(Uint8List bmpData) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Divide BMP data into 194-byte chunks (matching visionlink)
    final chunks = _divideUint8List(bmpData, 194);
    final List<List<int>> sentPackets = [];

    // Send all data packets
    for (int i = 0; i < chunks.length; i++) {
      final packet = await _sendBmpPacket(dataChunk: chunks[i], seq: i);
      if (packet != null) {
        sentPackets.add(packet);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Send end packet
    await _sendPacketEndPacket();
    await Future.delayed(const Duration(milliseconds: 500));

    // Concatenate all sent packets for CRC calculation
    final concatenatedList = <int>[];
    for (final packet in sentPackets) {
      concatenatedList.addAll(packet);
    }
    final concatenatedPackets = Uint8List.fromList(concatenatedList);

    // Send CRC packet
    await _sendCRCPacket(packets: concatenatedPackets);
  }

  /// Divide a Uint8List into chunks of specified size
  List<Uint8List> _divideUint8List(Uint8List data, int chunkSize) {
    final chunks = <Uint8List>[];
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      chunks.add(data.sublist(i, end));
    }
    return chunks;
  }

  /// Send a single BMP data packet
  Future<List<int>?> _sendBmpPacket({
    required Uint8List dataChunk,
    int seq = 0,
  }) async {
    // Build packet: [0x15, seq, ...data]
    final List<int> bmpCommand = [
      G1Commands.bmp,
      seq & 0xFF,
      ...dataChunk,
    ];

    // First packet gets special header bytes
    if (seq == 0) {
      bmpCommand.insertAll(2, [0x00, 0x1c, 0x00, 0x00]);
    }

    try {
      await _manager.sendCommand(bmpCommand, needsAck: false, delay: const Duration(milliseconds: 8));
      return bmpCommand;
    } catch (e) {
      return null;
    }
  }

  /// Send packet end marker
  Future<void> _sendPacketEndPacket() async {
    await _manager.sendCommand([G1Commands.packetEnd, 0x0d, 0x0e], needsAck: false);
  }

  /// Send CRC packet for verification
  Future<void> _sendCRCPacket({required Uint8List packets}) async {
    final crc = Crc32();
    crc.update(packets);
    final crc32Checksum = crc.getValue() & 0xFFFFFFFF;
    
    final crc32Bytes = Uint8List(4);
    crc32Bytes[0] = (crc32Checksum >> 24) & 0xFF;
    crc32Bytes[1] = (crc32Checksum >> 16) & 0xFF;
    crc32Bytes[2] = (crc32Checksum >> 8) & 0xFF;
    crc32Bytes[3] = crc32Checksum & 0xFF;

    final crcCommand = [
      G1Commands.crc,
      ...crc32Bytes,
    ];

    await _manager.sendCommand(crcCommand, needsAck: false);
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
