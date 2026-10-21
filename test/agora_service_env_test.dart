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

  test('AgoraService generates valid tokens for wildcard 0 and string accounts', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: 'assets/env');

    final agora = AgoraService.instance;
    final tokenWildcard = await agora.fetchToken(channelName: 'testChannel', uid: 0);
    expect(tokenWildcard.isNotEmpty, isTrue);
    expect(tokenWildcard.startsWith('006'), isTrue);

    final tokenString = await agora.fetchToken(channelName: 'testChannel', uid: 'user123');
    expect(tokenString.isNotEmpty, isTrue);
    expect(tokenString.startsWith('006'), isTrue);

    // Channel names derived from session id are limited to <=32 chars
    final derived = agora.channelFromSessionId('a' * 50);
    expect(derived.length, 32);
  });
}
