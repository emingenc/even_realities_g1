import 'dart:convert';
import 'dart:typed_data';

import '../protocol/commands.dart';

/// Model for G1 quick notes.
///
/// Quick notes appear on the dashboard and can hold short text content.
class G1NoteModel {
  /// Note position (1-4)
  final int noteNumber;

  /// Note title/name
  final String name;

  /// Note content text
  final String text;

  G1NoteModel({
    required this.noteNumber,
    required this.name,
    required this.text,
  }) {
    if (noteNumber < 1 || noteNumber > 4) {
      throw ArgumentError('Note number must be between 1 and 4');
    }
  }

  Uint8List _getFixedBytes() {
    return Uint8List.fromList([0x03, 0x01, 0x00, 0x01, 0x00]);
  }

  int _getVersioningByte() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 % 256;
  }

  int _calculatePayloadLength(Uint8List nameBytes, Uint8List textBytes) {
    return 1 + // Fixed byte
        1 + // Versioning byte
        _getFixedBytes().length +
        1 + // Note number
        1 + // Fixed byte 2
        1 + // Title length
        nameBytes.length +
        1 + // Text length
        1 + // Fixed byte after text length
        textBytes.length +
        2; // Final bytes
  }

  /// Build command to add/update this note.
  Uint8List buildAddCommand() {
    final nameBytes = Uint8List.fromList(utf8.encode(name));
    final textBytes = Uint8List.fromList(utf8.encode(text));

    final payloadLength = _calculatePayloadLength(nameBytes, textBytes);
    final versioningByte = _getVersioningByte();
    final fixedBytes = _getFixedBytes();

    final command = <int>[
      G1Commands.quickNoteAdd,
      payloadLength & 0xFF,
      0x00, // Fixed
      versioningByte,
      ...fixedBytes,
      noteNumber,
      0x01, // Fixed
      nameBytes.length & 0xFF,
      ...nameBytes,
      textBytes.length & 0xFF,
      0x00, // Fixed
      ...textBytes,
    ];

    return Uint8List.fromList(command);
  }

  /// Build command to delete this note.
  Uint8List buildDeleteCommand() {
    return Uint8List.fromList([
      0x1E,
      0x10,
      0x00,
      0xE0,
      0x03,
      0x01,
      0x00,
      0x01,
      0x00,
      noteNumber,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
    ]);
  }
}

/// Supported icons for notes
class NoteSupportedIcons {
  NoteSupportedIcons._();
  
  static const String checkbox = '☐';
  static const String check = '​✓';
}
