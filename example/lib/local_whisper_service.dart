// ignore_for_file: prefer_const_declarations

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'lc3_decoder.dart';

/// Simple LC3 -> PCM16 -> Whisper transcription service for the example app.
class LocalWhisperService {
  /// Decodes LC3 audio into PCM16 and runs Whisper locally.
  /// Returns human-readable transcription text.
  Future<String> transcribeLc3(Uint8List lc3Bytes) async {
    // 1) Decode LC3 to PCM16 (16 kHz, mono)
    final pcmBytes = await Lc3Decoder.decode(lc3Bytes);

    // 2) Write a temporary WAV so whisper_ggml can read it
    final wavPath = await _writeWav(pcmBytes, sampleRate: 16000, channels: 1);

    try {
      final whisper = WhisperController();
      // Default to small English model for a balance of size/speed.
      final result = await whisper.transcribe(
        model: WhisperModel.baseEn,
        audioPath: wavPath,
        lang: 'en',
      );

      return result?.transcription.text ?? '';
    } finally {
      // Clean up temp file
      try {
        final f = File(wavPath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // ignore best-effort cleanup
      }
    }
  }

  Future<String> _writeWav(Uint8List pcm,
      {required int sampleRate, required int channels}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/g1_pcm_${DateTime.now().millisecondsSinceEpoch}.wav');

    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final bitsPerSample = 16;
    final dataSize = pcm.length;
    final chunkSize = 36 + dataSize;

    final header = <int>[
      ...ascii.encode('RIFF'),
      chunkSize & 0xff,
      (chunkSize >> 8) & 0xff,
      (chunkSize >> 16) & 0xff,
      (chunkSize >> 24) & 0xff,
      ...ascii.encode('WAVE'),
      ...ascii.encode('fmt '),
      16, 0, 0, 0,
      1, 0,
      channels, 0,
      sampleRate & 0xff,
      (sampleRate >> 8) & 0xff,
      (sampleRate >> 16) & 0xff,
      (sampleRate >> 24) & 0xff,
      byteRate & 0xff,
      (byteRate >> 8) & 0xff,
      (byteRate >> 16) & 0xff,
      (byteRate >> 24) & 0xff,
      blockAlign, 0,
      bitsPerSample, 0,
      ...ascii.encode('data'),
      dataSize & 0xff,
      (dataSize >> 8) & 0xff,
      (dataSize >> 16) & 0xff,
      (dataSize >> 24) & 0xff,
    ];

    header.addAll(pcm);
    await file.writeAsBytes(header, flush: true);
    return file.path;
  }
}
