import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:grammatica/services/agora_service.dart';

void main() {
  test('AgoraService reads credentials from dotenv or environment', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: 'assets/env');

    final agora = AgoraService.instance;
    expect(agora.appId.isNotEmpty, isTrue);
    expect(agora.isConfigured, isTrue);
    expect(agora.chatAppKey.isNotEmpty, isTrue);
    expect(agora.appCertificate.isNotEmpty, isTrue);
  });
}
