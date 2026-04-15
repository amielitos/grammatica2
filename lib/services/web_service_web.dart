import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:typed_data';
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

// AudioContext JS interop
@JS('AudioContext')
extension type AudioContext._(JSObject _) implements JSObject {
  external AudioContext();
  external AnalyserNode createAnalyser();
  external MediaStreamAudioSourceNode createMediaStreamSource(
      web.MediaStream stream);
  external JSObject get destination;
  external JSPromise<JSAny?> close();
}

// AnalyserNode JS interop
@JS()
extension type AnalyserNode._(JSObject _) implements JSObject {
  external set fftSize(int value);
  external int get frequencyBinCount;
  external void getByteFrequencyData(JSUint8Array array);
  external void connect(JSObject destination);
  external void disconnect();
}

// MediaStreamAudioSourceNode JS interop
@JS()
extension type MediaStreamAudioSourceNode._(JSObject _) implements JSObject {
  external void connect(JSObject destination);
  external void disconnect();
}

class WebServiceWeb implements WebService {
  AudioContext? _audioContext;
  AnalyserNode? _analyser;
  MediaStreamAudioSourceNode? _micSource;
  MediaStreamAudioSourceNode? _monitorSource;
  JSUint8Array? _dataArray;
  web.MediaStream? _micStream;

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
    final sr = recognition as SpeechRecognition;
    sr.continuous = false;
    sr.interimResults = true;
    sr.lang = 'en-US';

    sr.onresult = (web.SpeechRecognitionEvent event) {
      final results = event.results;
      if (results.length > 0) {
        final result = results.item(results.length - 1);
        final transcript = result.item(0).transcript;
        onResult(transcript, result.isFinal);
      }
    }.toJS;

    sr.onerror = (JSObject error) {
      onError(error);
    }.toJS;

    sr.onend = () {
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

  /// Starts mic capture, sets up AnalyserNode for volume and optionally
  /// routes mic → speaker so the user can hear themselves.
  @override
  Future<void> startMicMonitor({bool enableMonitoring = true}) async {
    try {
      // Request mic access using the existing web package MediaDevices
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(audio: true.toJS, video: false.toJS),
          )
          .toDart;
      _micStream = stream;

      _audioContext = AudioContext();
      _analyser = _audioContext!.createAnalyser();
      _analyser!.fftSize = 256;

      final bufferLength = _analyser!.frequencyBinCount;
      // Create a Uint8List-backed JSUint8Array
      final dartBuffer = Uint8List(bufferLength);
      _dataArray = dartBuffer.toJS;

      // Mic source → analyser (for volume reading)
      _micSource = _audioContext!.createMediaStreamSource(stream);
      _micSource!.connect(_analyser!);

      if (enableMonitoring) {
        // Also route a separate source → destination so the user can hear themselves
        _monitorSource = _audioContext!.createMediaStreamSource(stream);
        _monitorSource!.connect(_audioContext!.destination);
      }
    } catch (e) {
      debugPrint('startMicMonitor error: $e');
    }
  }

  /// Returns current mic volume as a value between 0.0 and 1.0.
  @override
  double getMicVolume() {
    if (_analyser == null || _dataArray == null) return 0.0;
    try {
      _analyser!.getByteFrequencyData(_dataArray!);
      final data = _dataArray!.toDart;
      if (data.isEmpty) return 0.0;
      double sum = 0;
      for (final v in data) {
        sum += v;
      }
      return (sum / data.length) / 255.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Stops mic capture and tears down AudioContext.
  @override
  void stopMicMonitor() {
    try {
      _micSource?.disconnect();
      _monitorSource?.disconnect();
      _analyser?.disconnect();
      _micSource = null;
      _monitorSource = null;
      _analyser = null;
      _dataArray = null;

      // Stop all mic tracks
      if (_micStream != null) {
        final tracks = _micStream!.getTracks().toDart;
        for (final track in tracks) {
          track.stop();
        }
        _micStream = null;
      }
      _audioContext?.close();
      _audioContext = null;
    } catch (e) {
      debugPrint('stopMicMonitor error: $e');
    }
  }
}

WebService getWebService() => WebServiceWeb();
