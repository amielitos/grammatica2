import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'web_service_stub.dart'
    if (dart.library.js_interop) 'web_service_web.dart';

abstract class WebService {
  static final WebService instance = getWebService();

  Future<Uint8List?> fetchBlobAsBytes(String url);

  // Method to get a speech recognition instance (only works on web)
  dynamic createSpeechRecognition();

  void startSpeechRecognition(dynamic recognition);
  void stopSpeechRecognition(dynamic recognition);
  void configureSpeechRecognition({
    required dynamic recognition,
    required void Function(String transcript, bool isFinal) onResult,
    required void Function(dynamic error) onError,
    required void Function() onEnd,
  });

  void speak(String text);
}
