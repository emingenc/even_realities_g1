import 'dart:convert';

import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';
import '../utils/text_formatter.dart';

/// G1 Display feature for showing text on the glasses.
///
/// Handles text rendering, pagination, and screen clearing.
class G1Display {
  final G1Manager _manager;

  int _textSeqNum = 0;

  G1Display(this._manager);

  /// Show text on the glasses display.
  ///
  /// [text] - The text to display
  /// [duration] - How long to show the text before clearing
  /// [clearOnComplete] - Whether to clear the screen after duration
  /// [margin] - Character margin on each side
  Future<void> showText(
    String text, {
    Duration duration = const Duration(seconds: 5),
    bool clearOnComplete = true,
    int margin = 5,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    if (text.trim().isEmpty) {
      await _manager.clearScreen();
      return;
    }

    final chunks = _createTextWallChunks(text, margin: margin);
    await _sendChunks(chunks, duration, clearOnComplete);
  }

  /// Show AI-style text response with status indicators.
  ///
  /// [text] - The text to display
  /// [isComplete] - Whether this is the final response
  Future<void> showAIResponse(
    String text, {
    bool isComplete = true,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final packets = _buildAIResponsePackets(text, isComplete: isComplete);
    for (final packet in packets) {
      await _manager.sendCommand(packet);
    }
  }

  List<List<int>> _createTextWallChunks(String text, {int margin = 5}) {
    final spaceWidth = TextFormatter.calculateTextWidth(' ');
    final marginWidth = margin * spaceWidth;
    final effectiveWidth = TextFormatter.displayWidth - (2 * marginWidth);

    final lines = TextFormatter.splitIntoLines(text, maxWidth: effectiveWidth);
    final totalPages = TextFormatter.calculatePageCount(lines);

    final allChunks = <List<int>>[];

    for (int page = 0; page < totalPages; page++) {
      final pageLines = TextFormatter.getLinesForPage(lines, page);

      // Add margin to each line
      final buffer = StringBuffer();
      final indentation = ' ' * margin;
      for (final line in pageLines) {
        buffer.write(indentation);
        buffer.write(line);
        buffer.write('\n');
      }

      final textBytes = buffer.toString().codeUnits;
      final totalChunks = (textBytes.length / TextFormatter.maxChunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * TextFormatter.maxChunkSize;
        final end = (start + TextFormatter.maxChunkSize).clamp(0, textBytes.length);
        final payloadChunk = textBytes.sublist(start, end);

        // Screen status: New content (0x01) + Text Show (0x70) = 0x71
        const screenStatus = 0x71;

        final header = <int>[
          G1Commands.sendResult,
          _textSeqNum,
          totalChunks,
          i,
          screenStatus,
          0x00, // new_char_pos0
          0x00, // new_char_pos1
          page,
          totalPages,
        ];

        allChunks.add([...header, ...payloadChunk]);
      }

      _textSeqNum = (_textSeqNum + 1) % 256;
    }

    return allChunks;
  }

  List<List<int>> _buildAIResponsePackets(String text, {bool isComplete = true}) {
    final lines = TextFormatter.formatTextByLength(text, maxLength: 20);
    final totalPages = ((lines.length + 4) ~/ 5).clamp(1, 999);

    final packets = <List<int>>[];

    int screenStatus = isComplete
        ? G1ScreenStatus.displayComplete
        : (G1ScreenStatus.displaying | G1ScreenStatus.newContent);

    for (int pn = 1, lineIndex = 0; lineIndex < lines.length; pn++, lineIndex += 5) {
      var pageLines = lines.sublist(
        lineIndex,
        (lineIndex + 5) > lines.length ? lines.length : (lineIndex + 5),
      );

      // Center pages with fewer than 5 lines
      if (pageLines.length < 5) {
        final padding = ((5 - pageLines.length) ~/ 2);
        pageLines = List.filled(padding, '') +
            pageLines +
            List.filled(5 - pageLines.length - padding, '');
      }

      final pageText = pageLines.join('\n');

      final packet = _buildTextPacket(
        textMessage: pageText,
        pageNumber: pn,
        maxPages: totalPages,
        screenStatus: isComplete && lineIndex + 5 >= lines.length
            ? G1ScreenStatus.displayComplete
            : screenStatus,
        seq: _textSeqNum,
      );

      packets.add(packet);
      _textSeqNum = (_textSeqNum + 1) % 256;
    }

    return packets;
  }

  List<int> _buildTextPacket({
    required String textMessage,
    int pageNumber = 1,
    int maxPages = 1,
    int screenStatus = G1ScreenStatus.newContent | G1ScreenStatus.displaying,
    int seq = 0,
  }) {
    final textBytes = utf8.encode(textMessage);

    return [
      G1Commands.sendResult,
      seq & 0xFF,
      1, // totalPackages
      0, // currentPackage
      screenStatus & 0xFF,
      0x00, // newCharPos0
      0x00, // newCharPos1
      pageNumber & 0xFF,
      maxPages & 0xFF,
      ...textBytes,
    ];
  }

  Future<void> _sendChunks(
    List<List<int>> chunks,
    Duration delay,
    bool clearOnComplete,
  ) async {
    for (int i = 0; i < chunks.length; i++) {
      await _manager.sendCommand(chunks[i]);

      if (i < chunks.length - 1 || clearOnComplete) {
        await Future.delayed(delay);
      }
    }

    if (clearOnComplete) {
      await _manager.clearScreen();
    }
  }

  /// Clear the display.
  Future<void> clear() async {
    await _manager.clearScreen();
  }
}
