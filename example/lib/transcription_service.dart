import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Simple remote transcription client.
/// Posts LC3 (or PCM) audio bytes to a configurable endpoint.
class TranscriptionService {
  TranscriptionService({required this.endpoint, this.apiKey, this.contentType});

  /// Full URL of the transcription endpoint.
  final String endpoint;

  /// Optional API key header (sent as `Authorization: Bearer <apiKey>`).
  final String? apiKey;

  /// Content type of the payload. Defaults to `application/octet-stream`.
  final String? contentType;

  /// Sends audio bytes to the remote endpoint and expects a JSON with `text`.
  Future<String> transcribe(Uint8List audioBytes) async {
    final headers = <String, String>{
      'Content-Type': contentType ?? 'application/octet-stream',
    };
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: audioBytes,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (json['text'] ?? json['transcript'] ?? '').toString();
        if (text.isNotEmpty) return text;
        throw Exception('Empty transcript');
      } catch (e) {
        throw Exception('Failed to parse transcript: $e');
      }
    }

    throw Exception('Transcription failed: ${response.statusCode} ${response.body}');
  }
}
