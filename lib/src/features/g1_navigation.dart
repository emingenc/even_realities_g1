import 'dart:typed_data';

import '../bluetooth/g1_manager.dart';
import '../models/navigation_model.dart';

/// G1 Navigation feature for turn-by-turn navigation display.
class G1Navigation {
  final G1Manager _manager;

  int _seqId = 0;
  int _pollerSeqId = 1;

  G1Navigation(this._manager);

  /// Initialize navigation mode on the glasses.
  Future<void> start() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand(_buildInitCommand());
  }

  /// Send navigation directions to the glasses.
  Future<void> showDirections(G1NavigationModel navigation) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand(_buildDirectionsCommand(navigation));
  }

  /// Send primary navigation image (136x136 pixels).
  ///
  /// [image] - 136*136 bits as List<int> (0 or 1)
  /// [overlay] - 136*136 bits as List<int> (0 or 1)
  Future<void> sendPrimaryImage({
    required List<int> image,
    required List<int> overlay,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final commands = _buildPrimaryImageCommands(image, overlay);
    for (final command in commands) {
      await _manager.sendCommand(
        command,
        needsAck: false,
        delay: const Duration(milliseconds: 8),
      );
      await Future.delayed(const Duration(milliseconds: 8));
    }
  }

  /// Send secondary navigation image (488x136 pixels).
  ///
  /// [image] - 488*136 bits as List<int>
  /// [overlay] - 488*136 bits as List<int>
  Future<void> sendSecondaryImage({
    required List<int> image,
    required List<int> overlay,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final commands = _buildSecondaryImageCommands(image, overlay);
    for (final command in commands) {
      await _manager.sendCommand(command, needsAck: false);
      await Future.delayed(const Duration(milliseconds: 8));
    }
  }

  /// Send navigation poller data.
  Future<void> sendPoller() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand(_buildPollerCommand());
  }

  /// End navigation mode.
  Future<void> end() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand(_buildEndCommand());
  }

  /// Stop navigation mode (alias for end).
  Future<void> stop() => end();

  Uint8List _buildInitCommand() {
    final part = <int>[0x00, _seqId, 0x00, 0x01];
    final data = <int>[0x0A, part.length + 2, ...part];
    _seqId = (_seqId + 1) % 256;
    return Uint8List.fromList(data);
  }

  Uint8List _buildDirectionsCommand(G1NavigationModel nav) {
    const unknown1 = 0x01;
    final x = nav.customX ?? [0x00, 0x00];
    final y = nav.customY;

    final totalDurationData = _stringToBytes(nav.totalDuration);
    final totalDistanceData = _stringToBytes(nav.totalDistance);
    final directionData = _stringToBytes(nav.direction);
    final distanceData = _stringToBytes(nav.distance);
    final speedData = _stringToBytes(nav.speed);

    final part0 = <int>[0x00, _seqId, unknown1, nav.turn.code, ...x, y, 0x00];
    final part = <int>[
      ...part0,
      ...totalDurationData,
      0x00,
      ...totalDistanceData,
      0x00,
      ...directionData,
      0x00,
      ...distanceData,
      0x00,
      ...speedData,
      0x00,
    ];

    final data = <int>[0x0A, part.length + 2, ...part];
    _seqId = (_seqId + 1) % 256;
    return Uint8List.fromList(data);
  }

  List<Uint8List> _buildPrimaryImageCommands(List<int> image, List<int> overlay) {
    const partType2 = 0x02;
    final combinedBits = [...image, ...overlay];
    final imageBytes = _runLengthEncode(combinedBits);

    const maxLength = 185;
    final chunks = _chunkList(imageBytes, maxLength);
    final packetCount = chunks.length;

    final result = <Uint8List>[];
    for (int i = 0; i < chunks.length; i++) {
      final packetNum = i + 1;
      final part = <int>[
        0x00,
        _seqId,
        partType2,
        packetCount,
        0x00,
        packetNum,
        0x00,
        ...chunks[i],
      ];
      _seqId = (_seqId + 1) % 256;
      result.add(Uint8List.fromList([0x0A, part.length + 2, ...part]));
    }

    return result;
  }

  List<Uint8List> _buildSecondaryImageCommands(List<int> image, List<int> overlay) {
    const partType3 = 0x03;
    final imageBytes = [...image, ...overlay];

    const maxLength = 185;
    final chunks = _chunkList(imageBytes, maxLength);
    final packetCount = chunks.length;

    final result = <Uint8List>[];
    for (int i = 0; i < chunks.length; i++) {
      final packetNum = i + 1;
      final part = <int>[
        0x00,
        _seqId,
        partType3,
        packetCount,
        0x00,
        packetNum,
        0x00,
        0x00,
        ...chunks[i],
      ];
      _seqId = (_seqId + 1) % 256;
      result.add(Uint8List.fromList([0x0A, part.length + 2, ...part]));
    }

    return result;
  }

  Uint8List _buildPollerCommand() {
    const partType4 = 0x04;
    final part = <int>[0x00, _seqId, partType4, _pollerSeqId];
    _seqId = (_seqId + 1) % 256;
    _pollerSeqId = (_pollerSeqId + 1) % 256;
    return Uint8List.fromList([0x0A, part.length + 2, ...part]);
  }

  Uint8List _buildEndCommand() {
    const partType5 = 0x05;
    final part = <int>[0x00, _seqId, partType5, 0x01];
    _seqId = (_seqId + 1) % 256;
    return Uint8List.fromList([0x0A, part.length + 2, ...part]);
  }

  List<int> _stringToBytes(String str) {
    return str.codeUnits;
  }

  List<int> _runLengthEncode(List<int> bits) {
    if (bits.isEmpty) return [];

    final result = <int>[];
    int currentBit = bits[0];
    int count = 1;

    for (int i = 1; i < bits.length; i++) {
      if (bits[i] == currentBit && count < 255) {
        count++;
      } else {
        result.add(count);
        result.add(currentBit);
        currentBit = bits[i];
        count = 1;
      }
    }
    result.add(count);
    result.add(currentBit);

    return result;
  }

  List<List<int>> _chunkList(List<int> list, int chunkSize) {
    final chunks = <List<int>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize > list.length) ? list.length : i + chunkSize;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}
