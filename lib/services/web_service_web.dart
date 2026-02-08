import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'web_service.dart';

@JS('webkitSpeechRecognition')
extension type SpeechRecognition._(JSObject _) implements JSObject {
  external SpeechRecognition();
  external set continuous(bool value);
  external set interimResults(bool value);
  external set lang(String value);
  external set onresult(JSFunction value);
  external set onerror(JSFunction value);
  external set onend(JSFunction value);
  external void start();
  external void stop();
}

class WebServiceWeb implements WebService {
  @override
  Future<Uint8List?> fetchBlobAsBytes(String url) async {
    try {
      final response = await web.window.fetch(url.toJS).toDart;
      final blob = await response.blob().toDart;
      final arrayBuffer = await blob.arrayBuffer().toDart;
      return arrayBuffer.toDart.asUint8List();
    } catch (e) {
      return null;
    }
  }

  @override
  dynamic createSpeechRecognition() {
    try {
      return SpeechRecognition();
    } catch (e) {
      return null;
    }
  }

  @override
  void startSpeechRecognition(dynamic recognition) {
    // Cast to expected type as check is not supported for JS interop types
    (recognition as SpeechRecognition).start();
  }

  @override
  void stopSpeechRecognition(dynamic recognition) {
    (recognition as SpeechRecognition).stop();
  }

  @override
  void configureSpeechRecognition({
    required dynamic recognition,
    required void Function(String transcript, bool isFinal) onResult,
    required void Function(dynamic error) onError,
    required void Function() onEnd,
  }) {
    // No check possible for JS interop type
    // if (recognition is! SpeechRecognition) return;

    recognition.continuous = false;
    recognition.interimResults = true;
    recognition.lang = 'en-US';

    recognition.onresult = (web.SpeechRecognitionEvent event) {
      final results = event.results;
      if (results.length > 0) {
        final result = results.item(results.length - 1);
        final transcript = result.item(0).transcript;
        onResult(transcript, result.isFinal);
      }
    }.toJS;

    recognition.onerror = (JSObject error) {
      onError(error);
    }.toJS;

    recognition.onend = () {
      onEnd();
    }.toJS;
  }

  @override
  void speak(String text) {
    try {
      final utterance = web.SpeechSynthesisUtterance(text);
      utterance.lang = 'en-US';
      utterance.rate = 0.8;
      web.window.speechSynthesis.speak(utterance);
    } catch (e) {
      debugPrint('Web speech synthesis error: $e');
    }
  }
}

WebService getWebService() => WebServiceWeb();
