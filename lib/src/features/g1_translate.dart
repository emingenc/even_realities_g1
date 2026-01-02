import 'dart:typed_data';

import '../bluetooth/g1_connection_state.dart';
import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';
import '../utils/text_formatter.dart';

/// Language codes for translation.
enum G1Language {
  english('en'),
  chinese('zh'),
  japanese('ja'),
  korean('ko'),
  french('fr'),
  german('de'),
  spanish('es'),
  italian('it'),
  portuguese('pt'),
  russian('ru'),
  arabic('ar'),
  hindi('hi');

  final String code;
  const G1Language(this.code);
}

/// G1 Translate feature for real-time translation display.
class G1Translate {
  final G1Manager _manager;

  int _currentSeq = 0;

  /// Callback when translation result is received
  void Function(String text, bool isComplete)? onTranslationReceived;

  G1Translate(this._manager);

  /// Show translated text on the glasses display.
  ///
  /// [originalText] - The original text being translated
  /// [translatedText] - The translated text to display
  /// [fromLanguage] - Source language
  /// [toLanguage] - Target language
  Future<void> showTranslation({
    required String originalText,
    required String translatedText,
    required G1Language fromLanguage,
    required G1Language toLanguage,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Format the display text
    final displayText = '''$translatedText

---
${fromLanguage.code.toUpperCase()} → ${toLanguage.code.toUpperCase()}''';

    // Use text chunks for display
    final chunks = _createTextChunks(displayText);

    for (final chunk in chunks) {
      await _manager.sendCommand(chunk);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Show streaming translation (partial updates).
  ///
  /// [text] - The partial translation text
  /// [isComplete] - Whether this is the final chunk
  Future<void> showStreamingTranslation({
    required String text,
    required bool isComplete,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final chunks = _createStreamingChunks(text, isComplete: isComplete);

    for (final chunk in chunks) {
      await _manager.sendCommand(chunk);
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  /// Handle incoming translation-related data.
  Future<void> handleData(GlassSide side, List<int> data) async {
    if (data.isEmpty) return;

    // Translation responses typically come as text data
    if (data[0] == G1Commands.sendResult) {
      final textData = data.sublist(1);
      final text = String.fromCharCodes(textData);
      final isComplete = text.endsWith('\n');

      onTranslationReceived?.call(text.trim(), isComplete);
    }
  }

  /// Clear the translation display.
  Future<void> clear() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand([
      G1Commands.sendResult,
      G1ScreenStatus.hideScreen,
    ]);
  }

  List<Uint8List> _createTextChunks(String text) {
    final lines = TextFormatter.splitIntoLines(text);
    final chunks = <Uint8List>[];

    int seq = _currentSeq;

    for (int i = 0; i < lines.length; i++) {
      final isFirst = i == 0;
      final isLast = i == lines.length - 1;
      final line = lines[i];

      final lineBytes = line.codeUnits;
      
      final chunk = Uint8List(5 + lineBytes.length);
      chunk[0] = G1Commands.sendResult;
      chunk[1] = isFirst ? 0x01 : 0x00;
      chunk[2] = isLast ? 0x01 : 0x00;
      chunk[3] = seq & 0xFF;
      chunk[4] = (seq >> 8) & 0xFF;

      for (int j = 0; j < lineBytes.length; j++) {
        chunk[5 + j] = lineBytes[j];
      }

      chunks.add(chunk);
      seq++;
    }

    _currentSeq = seq;
    return chunks;
  }

  List<Uint8List> _createStreamingChunks(String text, {required bool isComplete}) {
    final chunks = <Uint8List>[];
    final textBytes = text.codeUnits;

    const maxChunkSize = 180;
    int offset = 0;

    while (offset < textBytes.length) {
      final isFirst = offset == 0;
      final chunkSize =
          (offset + maxChunkSize > textBytes.length) ? textBytes.length - offset : maxChunkSize;
      final isLast = isComplete && (offset + chunkSize >= textBytes.length);

      final chunkData = textBytes.sublist(offset, offset + chunkSize);

      final chunk = Uint8List(5 + chunkData.length);
      chunk[0] = G1Commands.sendResult;
      chunk[1] = isFirst ? 0x01 : 0x00;
      chunk[2] = isLast ? 0x01 : 0x00;
      chunk[3] = _currentSeq & 0xFF;
      chunk[4] = (_currentSeq >> 8) & 0xFF;

      for (int j = 0; j < chunkData.length; j++) {
        chunk[5 + j] = chunkData[j];
      }

      chunks.add(chunk);
      _currentSeq++;
      offset += chunkSize;
    }

    return chunks;
  }
}
