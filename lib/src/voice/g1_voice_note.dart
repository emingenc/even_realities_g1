import 'dart:async';
import 'dart:typed_data';

import '../bluetooth/g1_connection_state.dart';
import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';

/// Represents a voice note stored on the glasses.
class VoiceNote {
  /// Note index on the device (1-based)
  final int index;

  /// Unix timestamp when the note was created
  final int? timestamp;

  /// CRC32 checksum of the audio data
  final int? crc;

  VoiceNote({
    required this.index,
    this.timestamp,
    this.crc,
  });

  /// Build command to fetch audio data for this note.
  Uint8List buildFetchCommand(int syncId) {
    return Uint8List.fromList([
      G1Commands.quickNoteAdd,
      0x06,
      0x00,
      syncId,
      G1NoteSubCommands.requestAudioData,
      index,
    ]);
  }

  /// Build command to delete this voice note.
  Uint8List buildDeleteCommand(int syncId) {
    return Uint8List.fromList([
      G1Commands.quickNoteAdd,
      0x06,
      0x00,
      syncId,
      G1NoteSubCommands.deleteAudioStream,
      index,
    ]);
  }
}

/// G1 Voice Note feature for managing voice notes on the glasses.
class G1VoiceNote {
  final G1Manager _manager;

  int _syncId = 0;

  /// Stream controller for completed voice note audio
  final _audioStreamController = StreamController<VoiceNoteAudio>.broadcast();

  /// Buffer for collecting audio chunks
  final Map<int, List<int>> _audioBuffer = {};

  /// Callback when voice notes list is updated
  void Function(List<VoiceNote> notes)? onNotesUpdated;

  /// Callback when voice note audio is ready
  void Function(int index, List<int> audioData)? onAudioReady;

  G1VoiceNote(this._manager);

  /// Stream of completed voice note audio data.
  Stream<VoiceNoteAudio> get audioStream => _audioStreamController.stream;

  /// Fetch a voice note's audio data.
  Future<void> fetchNote(int index) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final note = VoiceNote(index: index);
    await _manager.rightGlass?.sendData(note.buildFetchCommand(_syncId++));
  }

  /// Delete a voice note.
  Future<void> deleteNote(int index) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final note = VoiceNote(index: index);
    await _manager.rightGlass?.sendData(note.buildDeleteCommand(_syncId++));
  }

  /// Delete all voice notes.
  Future<void> deleteAll() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand([
      G1Commands.quickNoteAdd,
      0x05,
      0x00,
      _syncId++,
      G1NoteSubCommands.deleteAll,
    ]);
  }

  /// Handle incoming data from glasses related to voice notes.
  Future<void> handleData(GlassSide side, List<int> data) async {
    if (data.isEmpty) return;

    final command = data[0];

    switch (command) {
      case G1Commands.quickNote:
        _handleQuickNoteCommand(side, data);
        break;

      case G1Commands.quickNoteAdd:
        _handleQuickNoteAudioData(side, data);
        break;
    }
  }

  void _handleQuickNoteCommand(GlassSide side, List<int> data) {
    try {
      final notification = _parseVoiceNoteNotification(Uint8List.fromList(data));
      onNotesUpdated?.call(notification);

      if (notification.isNotEmpty) {
        // Fetch the newest note automatically
        _audioBuffer.clear();
        final entry = notification.first;
        _manager.rightGlass?.sendData(entry.buildFetchCommand(_syncId++));
      }
    } catch (e) {
      // Failed to parse voice note notification
    }
  }

  void _handleQuickNoteAudioData(GlassSide side, List<int> data) {
    // Check if this is an audio data packet
    if (data.length > 4 && data[4] != 0x02) {
      return;
    }

    if (data.length < 11) {
      return;
    }

    final seq = data[3];
    final totalPackets = (data[5] << 8) | data[4];
    final currentPacket = (data[7] << 8) | data[6];
    final index = data[9] - 1;
    final audioData = data.sublist(10);

    _audioBuffer[seq] = audioData;

    // Check if this is the last packet
    if (currentPacket + 2 == totalPackets) {
      // Collect all audio data
      final completeAudio = <int>[];
      final keys = _audioBuffer.keys.toList()..sort();

      for (final key in keys) {
        completeAudio.addAll(_audioBuffer[key]!);
      }

      _audioBuffer.clear();

      // Delete the note from the device
      _manager.rightGlass?.sendData(
        VoiceNote(index: index + 1).buildDeleteCommand(_syncId++),
      );

      // Notify listeners
      final voiceNoteAudio = VoiceNoteAudio(
        index: index,
        audioData: completeAudio,
      );

      _audioStreamController.add(voiceNoteAudio);
      onAudioReady?.call(index, completeAudio);
    }
  }

  List<VoiceNote> _parseVoiceNoteNotification(Uint8List data) {
    if (data[0] != G1Commands.quickNote) {
      throw Exception('Invalid command');
    }
    if (data.length < 6) {
      throw Exception('Invalid data length');
    }
    if (data[4] != 0x01) {
      throw Exception('Invalid subcommand');
    }

    final length = data[1] + (data[2] << 8);
    final numNotesLength = (length - 6) / 9;

    if (numNotesLength % 1 != 0) {
      throw Exception('Invalid data length');
    }

    final numNotes = data[5];
    if (numNotes != numNotesLength) {
      throw Exception('Invalid data length');
    }

    final entries = <VoiceNote>[];

    for (int i = 0; i < numNotes; i++) {
      final index = data[6 + i * 9];

      final timestampBytes = data.sublist(7 + i * 9, 11 + i * 9);
      final timestamp = timestampBytes[0] +
          (timestampBytes[1] << 8) +
          (timestampBytes[2] << 16) +
          (timestampBytes[3] << 24);

      final crcBytes = data.sublist(11 + i * 9, 15 + i * 9);
      final crc = crcBytes[0] +
          (crcBytes[1] << 8) +
          (crcBytes[2] << 16) +
          (crcBytes[3] << 24);

      entries.add(VoiceNote(index: index, timestamp: timestamp, crc: crc));
    }

    return entries;
  }

  /// Dispose of resources.
  void dispose() {
    _audioStreamController.close();
  }
}

/// Represents completed voice note audio data.
class VoiceNoteAudio {
  /// Note index
  final int index;

  /// Raw LC3 audio data
  final List<int> audioData;

  VoiceNoteAudio({
    required this.index,
    required this.audioData,
  });
}
