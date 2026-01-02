
/// Collects and manages voice data chunks from the G1 microphone.
///
/// Audio from the G1 glasses is sent in sequential chunks that need to be
/// reassembled into complete audio data for processing.
class VoiceDataCollector {
  final Map<int, List<int>> _chunks = {};
  int _seqAdd = 0;
  bool _isRecording = false;

  /// Whether collection is currently active.
  bool get isRecording => _isRecording;
  set isRecording(bool value) => _isRecording = value;

  /// Add a chunk of audio data.
  ///
  /// [seq] - Sequence number (0-255, wraps around)
  /// [data] - Raw audio data
  void addChunk(int seq, List<int> data) {
    if (seq == 255) {
      _seqAdd += 255;
    }
    _chunks[_seqAdd + seq] = data;
  }

  /// Get all collected audio data in sequence order.
  List<int> getAllData() {
    final complete = <int>[];
    final keys = _chunks.keys.toList()..sort();

    for (final key in keys) {
      complete.addAll(_chunks[key]!);
    }

    return complete;
  }

  /// Get all collected data and reset the collector.
  List<int> getAllDataAndReset() {
    final data = getAllData();
    reset();
    return data;
  }

  /// Reset the collector.
  void reset() {
    _chunks.clear();
    _seqAdd = 0;
  }

  /// Get the current number of chunks.
  int get chunkCount => _chunks.length;

  /// Get the total bytes collected.
  int get totalBytes {
    int total = 0;
    for (final chunk in _chunks.values) {
      total += chunk.length;
    }
    return total;
  }
}
