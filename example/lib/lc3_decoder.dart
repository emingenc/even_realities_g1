// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Thin MethodChannel wrapper around the native LC3 decoder.
class Lc3Decoder {
  static final MethodChannel _channel = MethodChannel('dev.even.g1/lc3');

  /// Decode LC3 payloads (10 ms @ 16 kHz, 20-byte frames) into PCM16.
  static Future<Uint8List> decode(Uint8List lc3Data) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('LC3 decode is only available on Android');
    }

    final result = await _channel.invokeMethod<List<int>>('decodeLC3', {
      'data': lc3Data,
    });

    if (result == null) {
      throw PlatformException(
        code: 'lc3_null',
        message: 'Decoder returned null',
      );
    }

    return Uint8List.fromList(result);
  }
}
