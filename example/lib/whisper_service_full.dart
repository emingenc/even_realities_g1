import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// Whisper transcription service with local and remote modes
abstract class WhisperServiceFull {
  static Future<WhisperServiceFull> service() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('whisper_mode') ?? 'local';
    
    if (mode == 'local') {
      debugPrint('Using local whisper service (whisper.cpp)');
      return WhisperLocalService();
    }
    
    debugPrint('Using remote whisper service');
    return WhisperRemoteService();
  }

  Future<String> transcribe(Uint8List voiceData);
  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out,
      {bool finalOnly = false});
}

/// Local on-device Whisper transcription using whisper.cpp
class WhisperLocalService implements WhisperServiceFull {
  Whisper? _whisper;
  bool _initializing = false;
  
  Future<Whisper> _getWhisper() async {
    if (_whisper != null) return _whisper!;
    
    if (_initializing) {
      // Wait for initialization
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _whisper!;
    }
    
    _initializing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final modelName = prefs.getString('whisper_model') ?? 'base';
      
      WhisperModel model;
      switch (modelName) {
        case 'tiny':
          model = WhisperModel.tiny;
          break;
        case 'small':
          model = WhisperModel.small;
          break;
        case 'medium':
          model = WhisperModel.medium;
          break;
        case 'large':
          model = WhisperModel.largeV1;
          break;
        default:
          model = WhisperModel.base;
      }
      
      debugPrint('Initializing whisper with model: $modelName');
      _whisper = Whisper(
        model: model,
        downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
      );
      
      debugPrint('Whisper initialized successfully');
      return _whisper!;
    } finally {
      _initializing = false;
    }
  }

  @override
  Future<String> transcribe(Uint8List voiceData) async {
    try {
      final whisper = await _getWhisper();
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('whisper_language') ?? 'en';
      
      // Create WAV file from PCM data
      final wavData = _createWavFile(voiceData);
      
      // Save to temp file (whisper.cpp needs file path)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/whisper_input_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavData);
      
      try {
        debugPrint('Transcribing audio: ${tempFile.path} (${wavData.length} bytes)');
        
        final transcription = await whisper.transcribe(
          transcribeRequest: TranscribeRequest(
            audio: tempFile.path,
            isTranslate: false,
            isNoTimestamps: true,
            splitOnWord: true,
          ),
        );
        
        debugPrint('Transcription result: ${transcription.text}');
        return transcription.text.trim();
      } finally {
        // Clean up temp file
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    } catch (e, stack) {
      debugPrint('Error in local transcription: $e');
      debugPrint('Stack: $stack');
      return '';
    }
  }

  @override
  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out,
      {bool finalOnly = false}) async {
    final int sampleRate = 16000;
    final int bytesPerSample = 2;
    final int chunkDurationSeconds = 5;
    final int chunkSizeBytes = sampleRate * bytesPerSample * chunkDurationSeconds;

    List<int> audioBuffer = [];
    String accumulatedTranscription = '';

    await for (final data in voiceData) {
      audioBuffer.addAll(data);

      if (audioBuffer.length >= chunkSizeBytes) {
        try {
          final transcription = await transcribe(Uint8List.fromList(audioBuffer));
          if (transcription.isNotEmpty) {
            accumulatedTranscription += ' ' + transcription;
            accumulatedTranscription = accumulatedTranscription.trim();

            // Limit length
            if (accumulatedTranscription.length > 500) {
              accumulatedTranscription = accumulatedTranscription.substring(
                  accumulatedTranscription.length - 400);
            }

            out.add(accumulatedTranscription);
          }
        } catch (e) {
          debugPrint('Error in live transcription: $e');
        }
        audioBuffer.clear();
      }
    }

    // Process remaining audio
    if (audioBuffer.isNotEmpty) {
      try {
        final transcription = await transcribe(Uint8List.fromList(audioBuffer));
        if (transcription.isNotEmpty) {
          accumulatedTranscription += ' ' + transcription;
          out.add(accumulatedTranscription.trim());
        }
      } catch (e) {
        debugPrint('Error in final live transcription: $e');
      }
    }
  }

  Uint8List _createWavFile(Uint8List pcmData) {
    final int sampleRate = 16000;
    final int numChannels = 1;
    final int byteRate = sampleRate * numChannels * 2;
    final int blockAlign = numChannels * 2;
    final int bitsPerSample = 16;
    final int dataSize = pcmData.length;
    final int chunkSize = 36 + dataSize;

    final List<int> header = [
      ...ascii.encode('RIFF'),
      chunkSize & 0xff, (chunkSize >> 8) & 0xff, (chunkSize >> 16) & 0xff, (chunkSize >> 24) & 0xff,
      ...ascii.encode('WAVE'),
      ...ascii.encode('fmt '),
      16, 0, 0, 0,
      1, 0,
      numChannels, 0,
      sampleRate & 0xff, (sampleRate >> 8) & 0xff, (sampleRate >> 16) & 0xff, (sampleRate >> 24) & 0xff,
      byteRate & 0xff, (byteRate >> 8) & 0xff, (byteRate >> 16) & 0xff, (byteRate >> 24) & 0xff,
      blockAlign, 0,
      bitsPerSample, 0,
      ...ascii.encode('data'),
      dataSize & 0xff, (dataSize >> 8) & 0xff, (dataSize >> 16) & 0xff, (dataSize >> 24) & 0xff,
    ];

    return Uint8List.fromList([...header, ...pcmData]);
  }
}

/// Remote HTTP-based Whisper transcription service
class WhisperRemoteService implements WhisperServiceFull {
  Future<String?> _getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_api_url');
  }

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_api_key');
  }

  Future<String> _getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whisper_language') ?? 'en';
  }

  @override
  Future<String> transcribe(Uint8List voiceData) async {
    final apiUrl = await _getApiUrl();
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('Whisper API URL not configured. Set whisper_api_url in settings.');
    }

    final apiKey = await _getApiKey();
    final language = await _getLanguage();

    // Create WAV data from PCM
    final wavData = _createWavFile(voiceData);

    // Create multipart request
    final uri = Uri.parse(apiUrl);
    final request = http.MultipartRequest('POST', uri);

    if (apiKey != null && apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      wavData,
      filename: 'audio.wav',
    ));
    request.fields['language'] = language;

    try {
      debugPrint('Sending audio to whisper API: $apiUrl');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] ?? '';
      } else {
        debugPrint('Whisper API error: ${response.statusCode} - ${response.body}');
        return '';
      }
    } catch (e) {
      debugPrint('Error calling whisper API: $e');
      return '';
    }
  }

  @override
  Future<void> transcribeLive(
      Stream<Uint8List> voiceData, StreamController<String> out,
      {bool finalOnly = false}) async {
    final int sampleRate = 16000;
    final int bytesPerSample = 2;
    final int chunkDurationSeconds = 5;
    final int chunkSizeBytes = sampleRate * bytesPerSample * chunkDurationSeconds;

    List<int> audioBuffer = [];
    String accumulatedTranscription = '';

    await for (final data in voiceData) {
      audioBuffer.addAll(data);

      if (audioBuffer.length >= chunkSizeBytes) {
        try {
          final transcription = await transcribe(Uint8List.fromList(audioBuffer));
          if (transcription.isNotEmpty) {
            accumulatedTranscription += ' ' + transcription;
            accumulatedTranscription = accumulatedTranscription.trim();

            // Limit length
            if (accumulatedTranscription.length > 500) {
              accumulatedTranscription = accumulatedTranscription.substring(
                  accumulatedTranscription.length - 400);
            }

            out.add(accumulatedTranscription);
          }
        } catch (e) {
          debugPrint('Error in live transcription: $e');
        }
        audioBuffer.clear();
      }
    }

    // Process remaining audio
    if (audioBuffer.isNotEmpty) {
      try {
        final transcription = await transcribe(Uint8List.fromList(audioBuffer));
        if (transcription.isNotEmpty) {
          accumulatedTranscription += ' ' + transcription;
          out.add(accumulatedTranscription.trim());
        }
      } catch (e) {
        debugPrint('Error in final live transcription: $e');
      }
    }
  }

  Uint8List _createWavFile(Uint8List pcmData) {
    final int sampleRate = 16000;
    final int numChannels = 1;
    final int byteRate = sampleRate * numChannels * 2;
    final int blockAlign = numChannels * 2;
    final int bitsPerSample = 16;
    final int dataSize = pcmData.length;
    final int chunkSize = 36 + dataSize;

    final List<int> header = [
      ...ascii.encode('RIFF'),
      chunkSize & 0xff, (chunkSize >> 8) & 0xff, (chunkSize >> 16) & 0xff, (chunkSize >> 24) & 0xff,
      ...ascii.encode('WAVE'),
      ...ascii.encode('fmt '),
      16, 0, 0, 0,
      1, 0,
      numChannels, 0,
      sampleRate & 0xff, (sampleRate >> 8) & 0xff, (sampleRate >> 16) & 0xff, (sampleRate >> 24) & 0xff,
      byteRate & 0xff, (byteRate >> 8) & 0xff, (byteRate >> 16) & 0xff, (byteRate >> 24) & 0xff,
      blockAlign, 0,
      bitsPerSample, 0,
      ...ascii.encode('data'),
      dataSize & 0xff, (dataSize >> 8) & 0xff, (dataSize >> 16) & 0xff, (dataSize >> 24) & 0xff,
    ];

    return Uint8List.fromList([...header, ...pcmData]);
  }
}
