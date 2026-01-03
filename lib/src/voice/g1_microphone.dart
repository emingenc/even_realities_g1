import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bluetooth/g1_connection_state.dart';
import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';
import 'voice_data_collector.dart';

/// A single microphone audio packet from the glasses.
class G1AudioPacket {
  final int seq;
  final List<int> data;

  const G1AudioPacket({required this.seq, required this.data});
}

/// G1 Microphone feature for voice control and audio streaming.
class G1Microphone {
  final G1Manager _manager;

  final VoiceDataCollector _aiSessionCollector = VoiceDataCollector();

  /// Stream controller for raw audio data
  final _audioStreamController = StreamController<List<int>>.broadcast();

  /// Stream controller for sequenced audio packets
  final _audioPacketStreamController =
      StreamController<G1AudioPacket>.broadcast();

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

  /// Callback for page control events (legacy, use onLeftTap/onRightTap instead)
  void Function(bool isUp)? onPageControl;

  /// Callback when left touchbar is tapped (page up in Even AI mode)
  void Function()? onLeftTap;

  /// Callback when right touchbar is tapped (page down in Even AI mode)
  void Function()? onRightTap;

  /// Callback for double-tap on touchbar (exits Even AI to dashboard)
  void Function()? onDoubleTap;

  /// Callback when user exits to dashboard
  void Function()? onExitToDashboard;

  G1Microphone(this._manager);

  /// Stream of raw LC3 audio data from the microphone.
  Stream<List<int>> get audioStream => _audioStreamController.stream;

  /// Stream of audio packets including the device sequence number.
  Stream<G1AudioPacket> get audioPacketStream =>
      _audioPacketStreamController.stream;

  /// Whether the microphone is currently active.
  bool get isActive => _isActive;

  /// Enable the microphone on the glasses.
  Future<void> enable() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Set active BEFORE sending command to avoid race condition where
    // audio packets arrive before _isActive is set
    _isActive = true;
    
    // Send open mic command to right glass only (per original implementation)
    await _manager.rightGlass?.sendData([G1Commands.openMic, 0x01]);
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
        onDoubleTap?.call();
        onExitToDashboard?.call();
        break;

      case G1AISubCommands.pageControl:
        // Left touchbar = page up, Right touchbar = page down
        final isUp = side == GlassSide.left;
        if (isUp) {
          onLeftTap?.call();
        } else {
          onRightTap?.call();
        }
        onPageControl?.call(isUp);
        break;

      case G1AISubCommands.startWakeWord:
        onWakeWordStart?.call();
        break;

      case G1AISubCommands.stopWakeWord:
        onWakeWordStop?.call();
        break;

      case G1AISubCommands.startRecording:
        // Even AI started (long press on touchbar)
        // Must enable the microphone to receive audio data
        _isActive = true;
        _aiSessionCollector.isRecording = true;
        _aiSessionCollector.reset();
        // Enable mic in response to glasses request
        _manager.rightGlass?.sendData([G1Commands.openMic, 0x01]);
        onAISessionStart?.call();
        break;

      case G1AISubCommands.stopRecording:
        // Even AI stopped (user released touchbar)
        _isActive = false;
        _aiSessionCollector.isRecording = false;
        // Disable mic
        _manager.rightGlass?.sendData([G1Commands.openMic, 0x00]);
        final audioData = _aiSessionCollector.getAllDataAndReset();
        if (audioData.isNotEmpty) {
          onAISessionEnd?.call(audioData);
        }
        break;
    }
  }

  void _handleMicResponse(GlassSide side, int status, int enable) {
    if (status == G1ResponseStatus.success) {
      // Don't overwrite _isActive if we're in an AI session
      // The AI session manages its own recording state
      if (!_aiSessionCollector.isRecording) {
        _isActive = enable == 1;
      }
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
    // Accept audio if either _isActive OR if we're in an AI recording session
    if (!_isActive && !_aiSessionCollector.isRecording) {
      debugPrint('[G1Microphone] Dropping audio packet - mic not active');
      return;
    }

    _aiSessionCollector.addChunk(seq, audioData);

    _audioPacketStreamController.add(G1AudioPacket(seq: seq, data: audioData));
    _audioStreamController.add(audioData);
  }

  /// Dispose of resources.
  void dispose() {
    _audioStreamController.close();
    _audioPacketStreamController.close();
  }
}
