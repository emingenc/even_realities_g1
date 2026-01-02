import 'dart:async';

import '../bluetooth/g1_connection_state.dart';
import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';

/// G1 Microphone feature for voice control and audio streaming.
class G1Microphone {
  final G1Manager _manager;

  /// Stream controller for raw audio data
  final _audioStreamController = StreamController<List<int>>.broadcast();

  /// Whether the microphone is currently active
  bool _isActive = false;

  /// Callback when Even AI session starts
  void Function()? onAISessionStart;

  /// Callback when Even AI session ends with audio data
  void Function(List<int> audioData)? onAISessionEnd;

  /// Callback when wake word detection starts
  void Function()? onWakeWordStart;

  /// Callback when wake word detection stops
  void Function()? onWakeWordStop;

  /// Callback for page control events
  void Function(bool isUp)? onPageControl;

  /// Callback when user exits to dashboard
  void Function()? onExitToDashboard;

  G1Microphone(this._manager);

  /// Stream of raw LC3 audio data from the microphone.
  Stream<List<int>> get audioStream => _audioStreamController.stream;

  /// Whether the microphone is currently active.
  bool get isActive => _isActive;

  /// Enable the microphone on the glasses.
  Future<void> enable() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Send open mic command to right glass only (per original implementation)
    await _manager.rightGlass?.sendData([G1Commands.openMic, 0x01]);
    _isActive = true;
  }

  /// Disable the microphone on the glasses.
  Future<void> disable() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Send close mic command to right glass only
    await _manager.rightGlass?.sendData([G1Commands.openMic, 0x00]);
    _isActive = false;
  }

  /// Handle incoming data from glasses related to voice/mic.
  Future<void> handleData(GlassSide side, List<int> data) async {
    if (data.isEmpty) return;

    final command = data[0];

    switch (command) {
      case G1Commands.startAI:
        if (data.length >= 2) {
          _handleAICommand(side, data[1]);
        }
        break;

      case G1Commands.micResponse:
        if (data.length >= 3) {
          _handleMicResponse(side, data[1], data[2]);
        }
        break;

      case G1Commands.receiveMicData:
        if (data.length >= 2) {
          final seq = data[1];
          final audioData = data.sublist(2);
          _handleVoiceData(side, seq, audioData);
        }
        break;
    }
  }

  void _handleAICommand(GlassSide side, int subCommand) {
    switch (subCommand) {
      case G1AISubCommands.exitToDashboard:
        _isActive = false;
        onExitToDashboard?.call();
        break;

      case G1AISubCommands.pageControl:
        onPageControl?.call(side == GlassSide.left);
        break;

      case G1AISubCommands.startWakeWord:
        onWakeWordStart?.call();
        break;

      case G1AISubCommands.stopWakeWord:
        onWakeWordStop?.call();
        break;

      case G1AISubCommands.startRecording:
        _isActive = true;
        onAISessionStart?.call();
        break;

      case G1AISubCommands.stopRecording:
        _isActive = false;
        // Audio data will be collected via the stream
        break;
    }
  }

  void _handleMicResponse(GlassSide side, int status, int enable) {
    if (status == G1ResponseStatus.success) {
      _isActive = enable == 1;
    } else if (status == G1ResponseStatus.failure) {
      // Retry
      if (enable == 1) {
        this.enable();
      } else {
        disable();
      }
    }
  }

  void _handleVoiceData(GlassSide side, int seq, List<int> audioData) {
    if (!_isActive) return;
    
    _audioStreamController.add(audioData);
  }

  /// Dispose of resources.
  void dispose() {
    _audioStreamController.close();
  }
}
