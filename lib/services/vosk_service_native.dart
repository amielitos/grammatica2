import 'package:vosk_flutter_2/vosk_flutter_2.dart' as vosk;

class VoskService {
  static Future<void> init() async {
    // ignore: unused_local_variable
    final plugin = vosk.VoskFlutterPlugin.instance();
  }

  static void stop() {
    // Implement as needed
  }
}
