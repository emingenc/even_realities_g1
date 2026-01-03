import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lc3_decoder.dart';
import 'whisper_service_full.dart';

void main() {
  runApp(const G1ExampleApp());
}

class G1ExampleApp extends StatelessWidget {
  const G1ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G1 Glasses Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const G1ExampleHome(),
    );
  }
}

class G1ExampleHome extends StatefulWidget {
  const G1ExampleHome({super.key});

  @override
  State<G1ExampleHome> createState() => _G1ExampleHomeState();
}

class _G1ExampleHomeState extends State<G1ExampleHome> {
  final G1Manager _manager = G1Manager();
  G1ConnectionState _connectionState = G1ConnectionState.disconnected;
  String _status = 'Not connected';
  int _messageId = 0;
  bool _silentMode = false;
  int _brightness = 3;
  bool _autoBrightness = false;
  int _headUpAngle = 15;
  final List<String> _whisperModels = const [
    'tiny',
    'tiny.en',
    'base',
    'base.en',
    'small',
    'small.en',
    'medium',
    'large',
  ];
  final List<String> _whisperLanguages = const [
    'en',
    'es',
    'fr',
    'de',
    'it',
    'pt',
    'nl',
    'ru',
    'zh',
    'ja',
    'ko',
    'ar',
    'hi',
    'bn',
    'ur',
    'ta',
    'te',
    'mr',
    'gu',
    'kn',
    'ml',
    'pa',
    'th',
    'vi',
    'tl',
    'tr',
    'fa',
    'he',
    'sw',
  ];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _manager.onConnectionChanged = (state, side) {
      setState(() {
        _connectionState = state;
        _status = _getStatusText(state);
      });
    };

    _manager.microphone.onWakeWordStart = () {
      setState(() => _status = 'Wake word detected');
    };
    _manager.microphone.onWakeWordStop = () {
      setState(() => _status = 'Wake word stopped');
    };

    // Even AI session callbacks (triggered by long-press on touchbar)
    _manager.microphone.onAISessionStart = () {
      debugPrint('Even AI session started (long-press detected)');
      _voiceCollector.reset();
      setState(() {
        _isRecording = true;
        _status = 'Even AI Recording...';
      });
    };

    _manager.microphone.onAISessionEnd = (audioData) async {
      debugPrint('Even AI session ended with ${audioData.length} bytes');
      setState(() {
        _isRecording = false;
        _status = 'Processing audio (${audioData.length} LC3 bytes)...';
      });
      await _processAudioData(audioData);
    };

    // Tap callbacks
    _manager.microphone.onLeftTap = () {
      debugPrint('Left tap detected');
      setState(() => _status = 'Left tap (page up)');
    };
    _manager.microphone.onRightTap = () {
      debugPrint('Right tap detected');
      setState(() => _status = 'Right tap (page down)');
    };
    _manager.microphone.onDoubleTap = () {
      debugPrint('Double tap detected');
      setState(() => _status = 'Double tap (exit to dashboard)');
    };
  }

  String _getStatusText(G1ConnectionState state) {
    switch (state) {
      case G1ConnectionState.disconnected:
        return 'Disconnected';
      case G1ConnectionState.scanning:
        return 'Scanning for glasses...';
      case G1ConnectionState.connecting:
        return 'Connecting...';
      case G1ConnectionState.connected:
        return _manager.isBothConnected
            ? 'Both glasses connected'
            : 'One glass connected';
      case G1ConnectionState.error:
        return 'Connection error';
    }
  }

  Future<void> _scan() async {
    setState(() {
      _connectionState = G1ConnectionState.scanning;
      _status = 'Scanning for glasses...';
    });
    
    try {
      await _manager.startScan(
        onUpdate: (message) {
          setState(() {
            _status = message;
          });
        },
        onGlassesFound: (left, right) {
          setState(() {
            _status = 'Found: $left, $right';
          });
        },
        onConnected: () {
          setState(() {
            _connectionState = G1ConnectionState.connected;
            _status = 'Both glasses connected';
          });
        },
      );
    } catch (e) {
      setState(() {
        _connectionState = G1ConnectionState.error;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await _manager.disconnect();
  }

  Future<void> _sendNotification() async {
    if (!_manager.isConnected) return;

    await _manager.notifications.send(
      G1NotificationModel(
        messageId: _messageId++,
        appIdentifier: 'org.telegram.messenger',
        displayName: 'Telegram',
        title: 'New Message',
        message: 'Hey! This is a test message from Telegram.',
      ),
    );
  }

  Future<void> _showText() async {
    if (!_manager.isConnected) return;

    await _manager.display.showText(
      'Welcome to Even Realities G1!\n\n'
      'This library provides full control over your smart glasses.',
    );
  }

  Future<void> _syncTimeWeather() async {
    if (!_manager.isConnected) return;

    // Sync with OpenWeatherMap (requires API key)
    // await _manager.timeWeather.syncFromOpenWeatherMap(
    //   latitude: 52.52,
    //   longitude: 13.405,
    //   apiKey: 'YOUR_API_KEY',
    // );

    // Or sync manually
    await _manager.timeWeather.sync(
      weatherIcon: G1WeatherIcon.sunny,
      temperatureInCelsius: 22,
    );
  }

  Future<void> _showDashboard() async {
    if (!_manager.isConnected) return;

    await _manager.dashboard.showCalendar(
      G1CalendarModel(
        name: 'Team Meeting',
        time: '14:00',
        location: 'Room 101',
      ),
    );
  }

  Future<void> _showNotesDashboard() async {
    if (!_manager.isConnected) return;

    // First add some notes
    await _manager.notes.add(
      noteNumber: 1,
      name: 'Todo',
      text: 'Review pull requests',
    );
    await _manager.notes.add(
      noteNumber: 2,
      name: 'Shopping',
      text: 'Milk, eggs, bread',
    );

    // Then switch dashboard to notes pane
    await _manager.dashboard.showNotesPane();
    setState(() => _status = 'Showing notes pane');
  }

  Future<void> _setDoubleTapAction(G1DoubleTapActionType action, String label) async {
    if (!_manager.isConnected) return;
    await _manager.settings.setDoubleTapAction(action);
    setState(() => _status = 'Double-tap set: $label');
  }

  Future<void> _setLongPressEnabled(bool enabled) async {
    if (!_manager.isConnected) return;
    await _manager.settings.setLongPressEnabled(enabled);
    setState(() => _status = 'Long-press ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<void> _toggleHeadLiftMic() async {
    if (!_manager.isConnected) return;

    // Toggle head lift mic
    await _manager.settings.setHeadLiftMicEnabled(true);
    setState(() => _status = 'Head-lift mic enabled');
  }

  Future<void> _addQuickNote() async {
    if (!_manager.isConnected) return;

    await _manager.notes.add(
      noteNumber: 1,
      name: 'Reminder',
      text: 'Remember to buy groceries',
    );
  }

  Future<void> _startNavigation() async {
    if (!_manager.isConnected) return;

    // First initialize navigation
    await _manager.navigation.start();

    // Then show directions
    await _manager.navigation.showDirections(G1NavigationModel(
      turn: G1NavigationTurn.left,  // Uses correct code 0x04
      direction: 'Turn left',
      distance: '500m',
      speed: '30 km/h',
      totalDuration: '15 min',
      totalDistance: '5.2 km',
    ));
  }

  Future<void> _stopNavigation() async {
    if (!_manager.isConnected) return;

    await _manager.navigation.stop();
  }

  // ===== DEMO FEATURES =====

  Future<void> _toggleSilentMode() async {
    if (!_manager.isConnected) return;

    _silentMode = !_silentMode;
    await _manager.settings.setSilentMode(_silentMode);
    setState(() => _status = 'Silent mode: ${_silentMode ? "ON" : "OFF"}');
  }

  Future<void> _showBrightnessDialog() async {
    if (!_manager.isConnected) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Brightness'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Auto Brightness'),
                  value: _autoBrightness,
                  onChanged: (v) async {
                    setStateDialog(() => _autoBrightness = v);
                    await _manager.settings.setBrightness(
                      v ? G1Brightness.auto : G1Brightness.values[_brightness],
                    );
                  },
                ),
                if (!_autoBrightness) ...[
                  Text('Level: $_brightness'),
                  Slider(
                    value: _brightness.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: 'Level $_brightness',
                    onChanged: (v) async {
                      final level = v.round();
                      setStateDialog(() => _brightness = level);
                      await _manager.settings.setBrightness(
                        G1Brightness.values[level],
                      );
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        });
      },
    );
    setState(() => _status = 'Brightness: ${_autoBrightness ? "Auto" : "Level $_brightness"}');
  }

  Future<void> _showHeadUpAngleDialog() async {
    if (!_manager.isConnected) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Head-Up Angle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Angle: $_headUpAngle°'),
                Slider(
                  value: _headUpAngle.toDouble(),
                  min: 0,
                  max: 60,
                  divisions: 12,
                  label: '$_headUpAngle°',
                  onChanged: (v) async {
                    final angle = v.round();
                    setStateDialog(() => _headUpAngle = angle);
                    await _manager.settings.setHeadUpAngle(angle);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        });
      },
    );
    setState(() => _status = 'Head-up angle: $_headUpAngle°');
  }

  Future<void> _showDashboardToggle() async {
    if (!_manager.isConnected) return;

    await _manager.dashboard.show();
    setState(() => _status = 'Dashboard shown');
  }

  Future<void> _hideDashboard() async {
    if (!_manager.isConnected) return;

    await _manager.dashboard.hide();
    setState(() => _status = 'Dashboard hidden');
  }

  Future<void> _deleteNote() async {
    if (!_manager.isConnected) return;

    await _manager.notes.delete(1);
    setState(() => _status = 'Note 1 deleted');
  }

  Future<void> _sendRSVPText() async {
    if (!_manager.isConnected) return;

    // RSVP (Rapid Serial Visual Presentation) - show text word by word
    const text = 'Welcome to Even Realities G1! This is a demo of the RSVP feature. '
        'Text is displayed in rapid succession for quick reading.';
    
    final words = text.split(' ');
    const wordsPerGroup = 4;
    
    for (int i = 0; i < words.length; i += wordsPerGroup) {
      final end = (i + wordsPerGroup).clamp(0, words.length);
      final group = words.sublist(i, end).join(' ');
      await _manager.display.showText(group, duration: const Duration(milliseconds: 500), clearOnComplete: false);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    await Future.delayed(const Duration(seconds: 1));
    await _manager.clearScreen();
    setState(() => _status = 'RSVP complete');
  }

  Future<void> _sendSampleBitmap() async {
    if (!_manager.isConnected) return;

    // Create a simple 1-bit BMP pattern (heart icon)
    // This is a minimal monochrome BMP for demo purposes
    final bmpData = _createSampleBmp();
    
    await _manager.bitmap.send(bmpData);
    setState(() => _status = 'Bitmap sent');
  }

  Uint8List _createSampleBmp() {
    // Create a simple 48x48 1-bit monochrome BMP
    const width = 48;
    const height = 48;
    const rowBytes = ((width + 31) ~/ 32) * 4; // Row must be 4-byte aligned
    const pixelDataSize = rowBytes * height;
    const headerSize = 62; // 14 (file) + 40 (info) + 8 (palette)
    const fileSize = headerSize + pixelDataSize;

    final bmp = Uint8List(fileSize);
    final data = ByteData.view(bmp.buffer);

    // BMP File Header (14 bytes)
    bmp[0] = 0x42; // 'B'
    bmp[1] = 0x4D; // 'M'
    data.setUint32(2, fileSize, Endian.little);
    data.setUint32(10, headerSize, Endian.little);

    // DIB Header (40 bytes)
    data.setUint32(14, 40, Endian.little); // Header size
    data.setInt32(18, width, Endian.little);
    data.setInt32(22, -height, Endian.little); // Negative = top-down
    data.setUint16(26, 1, Endian.little); // Planes
    data.setUint16(28, 1, Endian.little); // Bits per pixel
    data.setUint32(30, 0, Endian.little); // No compression
    data.setUint32(34, pixelDataSize, Endian.little);

    // Color palette (8 bytes) - Black and White
    data.setUint32(54, 0x00000000, Endian.little); // Black
    data.setUint32(58, 0x00FFFFFF, Endian.little); // White

    // Draw a simple smiley face pattern
    final pixelOffset = headerSize;
    for (int y = 0; y < height; y++) {
      for (int byteX = 0; byteX < rowBytes; byteX++) {
        int byte = 0xFF; // Default white
        for (int bit = 0; bit < 8; bit++) {
          final x = byteX * 8 + bit;
          if (x < width) {
            // Draw eyes (two dots)
            final isLeftEye = (x >= 14 && x <= 18 && y >= 12 && y <= 18);
            final isRightEye = (x >= 30 && x <= 34 && y >= 12 && y <= 18);
            // Draw smile (arc)
            final centerX = 24, centerY = 24;
            final dx = x - centerX, dy = y - centerY;
            final dist = (dx * dx + dy * dy);
            final isSmile = dist >= 144 && dist <= 225 && y > 24;
            // Draw face outline
            final isOutline = dist >= 484 && dist <= 576;
            
            if (isLeftEye || isRightEye || isSmile || isOutline) {
              byte &= ~(0x80 >> bit); // Set pixel to black
            }
          }
        }
        bmp[pixelOffset + y * rowBytes + byteX] = byte;
      }
    }

    return bmp;
  }

  Future<void> _showAllNotesDemo() async {
    if (!_manager.isConnected) return;

    // Add 4 demo notes
    await _manager.notes.add(noteNumber: 1, name: 'Todo', text: 'Review PR #123');
    await _manager.notes.add(noteNumber: 2, name: 'Meeting', text: 'Team sync at 3pm');
    await _manager.notes.add(noteNumber: 3, name: 'Shopping', text: 'Milk, Eggs, Bread');
    await _manager.notes.add(noteNumber: 4, name: 'Ideas', text: 'New feature concept');
    
    await _manager.dashboard.showNotesPane();
    setState(() => _status = '4 notes added');
  }

  Future<void> _clearAllNotes() async {
    if (!_manager.isConnected) return;

    for (int i = 1; i <= 4; i++) {
      await _manager.notes.delete(i);
    }
    setState(() => _status = 'All notes cleared');
  }

  bool _isRecording = false;
  final VoiceDataCollector _voiceCollector = VoiceDataCollector();
  final VoiceDataCollector _liveCollector = VoiceDataCollector();
  String _lastTranscription = '';
  StreamSubscription? _audioPacketSub;
  WhisperServiceFull? _whisper;

  // Live transcription state
  bool _isLiveTranscribing = false;
  StreamSubscription? _liveAudioSub;
  Timer? _liveTimer;
  StreamController<Uint8List>? _liveLc3Controller;
  StreamController<String>? _liveTextController;
  String _liveTranscript = '';

  Future<String?> _writeAudioDebug(List<int> bytes) async {
    try {
      final file = File(
        '${Directory.systemTemp.path}/g1_audio_${DateTime.now().millisecondsSinceEpoch}.bin',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Process audio data from Even AI session or manual recording
  Future<void> _processAudioData(List<int> lc3Bytes) async {
    if (lc3Bytes.isEmpty) {
      setState(() {
        _status = 'No audio captured';
        _lastTranscription = '';
      });
      await _manager.display.showText('No audio captured.');
      return;
    }

    // Step 1: Decode LC3 to PCM
    Uint8List pcmData;
    try {
      setState(() => _status = 'Decoding LC3 audio...');
      pcmData = await Lc3Decoder.decode(Uint8List.fromList(lc3Bytes));
      debugPrint('Decoded ${lc3Bytes.length} LC3 bytes to ${pcmData.length} PCM bytes');
    } catch (e) {
      debugPrint('LC3 decode failed: $e');
      final savedPath = await _writeAudioDebug(lc3Bytes);
      setState(() {
        _lastTranscription = 'LC3 decode failed: $e. Saved raw audio to: $savedPath';
        _status = 'LC3 decode failed';
      });
      await _manager.display.showText('LC3 decode failed');
      return;
    }

    if (pcmData.isEmpty) {
      setState(() {
        _status = 'No PCM audio after decode';
        _lastTranscription = 'LC3 decoded but empty';
      });
      await _manager.display.showText('No audio after decode.');
      return;
    }

    // Step 2: Transcribe PCM with Whisper
    _whisper ??= await WhisperServiceFull.service();

    String transcript = '';
    try {
      setState(() => _status = 'Transcribing with Whisper...');
      transcript = await _whisper!.transcribe(pcmData);
    } catch (e) {
      debugPrint('Transcription error: $e');
      transcript = 'Transcription failed: $e';
    }

    if (transcript.isEmpty) {
      transcript = '(No speech detected)';
    }

    setState(() {
      _lastTranscription = transcript;
      _status = 'Transcription complete';
    });

    await _manager.display.showText(transcript);
  }

  Future<void> _startWhisperTest() async {
    if (!_manager.isConnected) return;
    if (_isLiveTranscribing) return; // avoid conflicts

    if (_isRecording) {
      // Stop recording and process audio
      await _manager.microphone.disable();
      await _audioPacketSub?.cancel();
      _audioPacketSub = null;

      final lc3Bytes = _voiceCollector.getAllDataAndReset();
      setState(() {
        _isRecording = false;
        _status = 'Processing audio (${lc3Bytes.length} LC3 bytes)...';
      });

      String transcript = '';
      String? savedPath;

      if (lc3Bytes.isEmpty) {
        setState(() {
          _status = 'No audio captured';
          _lastTranscription = '';
        });
        await _manager.display.showText('No audio captured.');
        return;
      }

      // Step 1: Decode LC3 to PCM
      Uint8List pcmData;
      try {
        setState(() => _status = 'Decoding LC3 audio...');
        pcmData = await Lc3Decoder.decode(Uint8List.fromList(lc3Bytes));
        debugPrint('Decoded ${lc3Bytes.length} LC3 bytes to ${pcmData.length} PCM bytes');
      } catch (e) {
        debugPrint('LC3 decode failed: $e');
        // Fallback: save raw LC3 bytes for debugging
        savedPath = await _writeAudioDebug(lc3Bytes);
        setState(() {
          _lastTranscription = 'LC3 decode failed: $e. Saved raw audio to: $savedPath';
          _status = 'LC3 decode failed';
        });
        await _manager.display.showText('LC3 decode failed');
        return;
      }

      if (pcmData.isEmpty) {
        setState(() {
          _status = 'No PCM audio after decode';
          _lastTranscription = 'LC3 decoded but empty';
        });
        await _manager.display.showText('No audio after decode.');
        return;
      }

      // Step 2: Transcribe PCM with Whisper
      _whisper ??= await WhisperServiceFull.service();
      
      try {
        setState(() => _status = 'Transcribing with Whisper...');
        transcript = await _whisper!.transcribe(pcmData);
      } catch (e) {
        debugPrint('Transcription error: $e');
        transcript = 'Transcription failed: $e';
      }

      if (transcript.isEmpty) {
        transcript = '(No speech detected)';
      }

      setState(() {
        _lastTranscription = transcript;
        _status = 'Transcription complete';
      });

      await _manager.display.showText(transcript);
    } else {
      // Start recording

      _voiceCollector.reset();
      await _audioPacketSub?.cancel();
      
      // Listen for audio packets and reassemble by sequence
      _audioPacketSub = _manager.microphone.audioPacketStream.listen((pkt) {
        _voiceCollector.addChunk(pkt.seq, pkt.data);
      });
      
      await _manager.microphone.enable();
      setState(() {
        _isRecording = true;
        _status = 'Recording... Tap again to stop';
        _lastTranscription = '';
      });

      // Try to explicitly start wake-word detection where supported
      try {
        await _manager.settings.startWakeWordDetection();
      } catch (_) {
        // Ignore if device rejects
      }
    }
  }

  Future<void> _toggleLiveTranscription() async {
    if (_isLiveTranscribing) {
      await _stopLiveTranscription();
    } else {
      await _startLiveTranscription();
    }
  }

  Future<void> _startLiveTranscription() async {
    if (!_manager.isConnected) return;
    if (_isRecording || _isLiveTranscribing) return;

    _whisper ??= await WhisperServiceFull.service();

    _liveCollector.reset();
    _liveLc3Controller = StreamController<Uint8List>();
    _liveTextController = StreamController<String>();

    _liveTextController!.stream.listen((text) {
      setState(() {
        _liveTranscript = text;
        _status = 'Live transcribing';
      });
      // Also show on glasses
      _manager.display.showText(text, clearOnComplete: false);
    });

    _liveAudioSub = _manager.microphone.audioPacketStream.listen((pkt) {
      _liveCollector.addChunk(pkt.seq, pkt.data);
    });

    // Decode LC3 chunks to PCM before sending to whisper
    _liveTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final lc3Chunk = _liveCollector.getAllDataAndReset();
      if (lc3Chunk.isNotEmpty) {
        try {
          final pcmChunk = await Lc3Decoder.decode(Uint8List.fromList(lc3Chunk));
          if (pcmChunk.isNotEmpty) {
            _liveLc3Controller?.add(pcmChunk);
          }
        } catch (e) {
          debugPrint('Live LC3 decode error: $e');
        }
      }
    });

    await _manager.microphone.enable();

    setState(() {
      _isLiveTranscribing = true;
      _status = 'Live transcription running';
    });

    // Kick off transcription (does its own loop until stream closes)
    unawaited(
      _whisper!.transcribeLive(
        _liveLc3Controller!.stream,
        _liveTextController!,
        finalOnly: false,
      ),
    );
  }

  Future<void> _stopLiveTranscription() async {
    if (!_isLiveTranscribing) return;

    await _manager.microphone.disable();
    await _liveAudioSub?.cancel();
    _liveTimer?.cancel();
    await _liveLc3Controller?.close();
    await _liveTextController?.close();

    _liveAudioSub = null;
    _liveTimer = null;
    _liveLc3Controller = null;
    _liveTextController = null;
    _liveCollector.reset();

    setState(() {
      _isLiveTranscribing = false;
      _status = 'Live transcription stopped';
    });
  }

  Future<void> _openWhisperSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    String mode = prefs.getString('whisper_mode') ?? 'local';
    String model = prefs.getString('whisper_model') ?? 'base.en';
    String language = prefs.getString('whisper_language') ?? 'en';
    final urlCtrl = TextEditingController(text: prefs.getString('whisper_api_url') ?? '');
    final keyCtrl = TextEditingController(text: prefs.getString('whisper_api_key') ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Whisper Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: mode,
                    decoration: const InputDecoration(labelText: 'Mode'),
                    items: const [
                      DropdownMenuItem(value: 'local', child: Text('Local')), 
                      DropdownMenuItem(value: 'remote', child: Text('Remote (HTTP)')),
                    ],
                    onChanged: (v) => setStateDialog(() => mode = v ?? 'local'),
                  ),
                  DropdownButtonFormField<String>(
                    value: model,
                    decoration: const InputDecoration(labelText: 'Model'),
                    items: _whisperModels
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => model = v ?? 'base.en'),
                  ),
                  DropdownButtonFormField<String>(
                    value: language,
                    decoration: const InputDecoration(labelText: 'Language'),
                    items: _whisperLanguages
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => language = v ?? 'en'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remote API URL',
                      hintText: 'https://example.com/transcribe',
                    ),
                  ),
                  TextField(
                    controller: keyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Key (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await prefs.setString('whisper_mode', mode);
                  await prefs.setString('whisper_model', model);
                  await prefs.setString('whisper_language', language);
                  await prefs.setString('whisper_api_url', urlCtrl.text);
                  await prefs.setString('whisper_api_key', keyCtrl.text);
                  // Force refresh of service next use
                  setState(() {
                    _whisper = null;
                  });
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionState == G1ConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('G1 Glasses Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      size: 48,
                      color: isConnected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_lastTranscription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lastTranscription,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_liveTranscript.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _liveTranscript,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _connectionState == G1ConnectionState.scanning
                              ? null
                              : _scan,
                          icon: const Icon(Icons.search),
                          label: const Text('Scan'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: isConnected ? _disconnect : null,
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Features
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
                children: [
                  // === CORE FEATURES ===
                  _FeatureButton(
                    icon: Icons.notifications,
                    label: 'Notification',
                    onPressed: isConnected ? _sendNotification : null,
                  ),
                  _FeatureButton(
                    icon: Icons.text_fields,
                    label: 'Show Text',
                    onPressed: isConnected ? _showText : null,
                  ),
                  _FeatureButton(
                    icon: Icons.speed,
                    label: 'RSVP Text',
                    onPressed: isConnected ? _sendRSVPText : null,
                  ),
                  _FeatureButton(
                    icon: Icons.image,
                    label: 'Send Bitmap',
                    onPressed: isConnected ? _sendSampleBitmap : null,
                  ),
                  
                  // === SETTINGS ===
                  _FeatureButton(
                    icon: _silentMode ? Icons.volume_off : Icons.volume_up,
                    label: 'Silent Mode',
                    onPressed: isConnected ? _toggleSilentMode : null,
                  ),
                  _FeatureButton(
                    icon: Icons.brightness_6,
                    label: 'Brightness',
                    onPressed: isConnected ? _showBrightnessDialog : null,
                  ),
                  _FeatureButton(
                    icon: Icons.straighten,
                    label: 'Head-Up Angle',
                    onPressed: isConnected ? _showHeadUpAngleDialog : null,
                  ),
                  
                  // === DASHBOARD ===
                  _FeatureButton(
                    icon: Icons.dashboard,
                    label: 'Show Dashboard',
                    onPressed: isConnected ? _showDashboardToggle : null,
                  ),
                  _FeatureButton(
                    icon: Icons.dashboard_outlined,
                    label: 'Hide Dashboard',
                    onPressed: isConnected ? _hideDashboard : null,
                  ),
                  _FeatureButton(
                    icon: Icons.calendar_month,
                    label: 'Calendar',
                    onPressed: isConnected ? _showDashboard : null,
                  ),
                  
                  // === NOTES ===
                  _FeatureButton(
                    icon: Icons.note_add,
                    label: 'Add Notes',
                    onPressed: isConnected ? _showAllNotesDemo : null,
                  ),
                  _FeatureButton(
                    icon: Icons.sticky_note_2,
                    label: 'Notes Pane',
                    onPressed: isConnected ? _showNotesDashboard : null,
                  ),
                  _FeatureButton(
                    icon: Icons.delete_sweep,
                    label: 'Clear Notes',
                    onPressed: isConnected ? _clearAllNotes : null,
                  ),
                  
                  // === NAVIGATION ===
                  _FeatureButton(
                    icon: Icons.navigation,
                    label: 'Start Nav',
                    onPressed: isConnected ? _startNavigation : null,
                  ),
                  _FeatureButton(
                    icon: Icons.navigation_outlined,
                    label: 'Stop Nav',
                    onPressed: isConnected ? _stopNavigation : null,
                  ),
                  
                  // === WEATHER ===
                  _FeatureButton(
                    icon: Icons.cloud,
                    label: 'Weather',
                    onPressed: isConnected ? _syncTimeWeather : null,
                  ),
                  
                  // === VOICE ===
                  _FeatureButton(
                    icon: _isRecording ? Icons.stop : Icons.mic,
                    label: _isRecording ? 'Stop Rec' : 'Whisper',
                    onPressed: isConnected ? _startWhisperTest : null,
                  ),
                  _FeatureButton(
                    icon: _isLiveTranscribing ? Icons.stop : Icons.hearing,
                    label: _isLiveTranscribing ? 'Stop Live' : 'Live Transc',
                    onPressed:
                        isConnected ? _toggleLiveTranscription : null,
                  ),
                  _FeatureButton(
                    icon: Icons.record_voice_over,
                    label: 'Start WakeWord',
                    onPressed: isConnected
                        ? () => _manager.settings.startWakeWordDetection()
                        : null,
                  ),
                  _FeatureButton(
                    icon: Icons.voice_over_off,
                    label: 'Stop WakeWord',
                    onPressed: isConnected
                        ? () => _manager.settings.stopWakeWordDetection()
                        : null,
                  ),
                  
                  // === GESTURES ===
                  _FeatureButton(
                    icon: Icons.touch_app,
                    label: 'DblTap Dashboard',
                    onPressed: isConnected
                        ? () => _setDoubleTapAction(
                              G1DoubleTapActionType.dashboard,
                              'Dashboard',
                            )
                        : null,
                  ),
                  _FeatureButton(
                    icon: Icons.translate,
                    label: 'DblTap Translate',
                    onPressed: isConnected
                        ? () => _setDoubleTapAction(
                              G1DoubleTapActionType.translate,
                              'Translate',
                            )
                        : null,
                  ),
                  _FeatureButton(
                    icon: Icons.subtitles,
                    label: 'DblTap Transcribe',
                    onPressed: isConnected
                        ? () => _setDoubleTapAction(
                              G1DoubleTapActionType.transcribe,
                              'Transcribe',
                            )
                        : null,
                  ),
                  _FeatureButton(
                    icon: Icons.mic_external_on,
                    label: 'HeadLift Mic',
                    onPressed: isConnected ? _toggleHeadLiftMic : null,
                  ),
                  
                  // === SETTINGS ===
                  _FeatureButton(
                    icon: Icons.settings_voice,
                    label: 'Whisper Settings',
                    onPressed: _openWhisperSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manager.dispose();
    _audioPacketSub?.cancel();
    _liveAudioSub?.cancel();
    _liveTimer?.cancel();
    _liveLc3Controller?.close();
    _liveTextController?.close();
    super.dispose();
  }
}

class _FeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _FeatureButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onPressed != null ? 1.0 : 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
