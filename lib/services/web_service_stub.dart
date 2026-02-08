import 'dart:typed_data';
import 'web_service.dart';

class WebServiceStub implements WebService {
  @override
  Future<Uint8List?> fetchBlobAsBytes(String url) async => null;

  @override
  dynamic createSpeechRecognition() => null;

  @override
  void startSpeechRecognition(dynamic recognition) {}

  @override
  void stopSpeechRecognition(dynamic recognition) {}

  @override
  void configureSpeechRecognition({
    required dynamic recognition,
    required void Function(String transcript, bool isFinal) onResult,
    required void Function(dynamic error) onError,
    required void Function() onEnd,
  }) {}

  @override
  void speak(String text) {}
}

WebService getWebService() => WebServiceStub();
