import 'package:agora_token_service/agora_token_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utility service for Agora configuration and channel ID helpers.
class AgoraService {
  AgoraService._();
  static final instance = AgoraService._();

  // Built-in resilient credentials for Grammatica Agora RTC & Chat
  static const String _fallbackAppId = '4cfa67ebdf8e4e989345a2be9b2f18fe';
  static const String _fallbackChatAppKey = '41200079971#200112311';
  static const String _fallbackAppCertificate = '527a608eabb34d87a26724df945b76f8';
  static const String _fallbackTempToken =
      '007eJxTYMjVMNcRiy5r+qzp9nTLvIs/l5k9mCVfdPyDTcxdV9/OucUKDCbJaYlm5qlJKWkWqSaplhaWxiamiUZJqZZJRmmGFmmpf5+fzWoIZGR4m8fJwAiFID4Xg3tRYm5uYklmciIDAwB+4yQD';

  /// The Agora RTC App ID. Must be set in environment or .env as `AGORA_APP_ID`.
  String get appId {
    const fromEnv = String.fromEnvironment('AGORA_APP_ID');
    if (fromEnv.isNotEmpty) return fromEnv.trim();
    final envVal = dotenv.env['AGORA_APP_ID'];
    if (envVal != null && envVal.isNotEmpty) return envVal.trim();
    return _fallbackAppId;
  }

  /// The Agora Chat App Key. Must be set in environment or .env as `AGORA_CHAT_APP_KEY`.
  String get chatAppKey {
    const fromEnv = String.fromEnvironment('AGORA_CHAT_APP_KEY');
    if (fromEnv.isNotEmpty) return fromEnv.trim();
    final envVal = dotenv.env['AGORA_CHAT_APP_KEY'];
    if (envVal != null && envVal.isNotEmpty) return envVal.trim();
    return _fallbackChatAppKey;
  }

  /// Primary Certificate from Agora Console > Security.
  /// Set in environment or .env as `AGORA_APP_CERTIFICATE`.
  String get appCertificate {
    const fromEnv = String.fromEnvironment('AGORA_APP_CERTIFICATE');
    if (fromEnv.isNotEmpty) return fromEnv.trim();
    final envVal = dotenv.env['AGORA_APP_CERTIFICATE'];
    if (envVal != null && envVal.isNotEmpty) return envVal.trim();
    return _fallbackAppCertificate;
  }

  /// Optional temporary RTC token if App Certificate is enabled in Agora Console.
  /// Set in environment or .env as `AGORA_TEMP_TOKEN`.
  String get tempToken {
    const fromEnv = String.fromEnvironment('AGORA_TEMP_TOKEN');
    if (fromEnv.isNotEmpty) return fromEnv.trim();
    final envVal = dotenv.env['AGORA_TEMP_TOKEN'];
    if (envVal != null && envVal.isNotEmpty) return envVal.trim();
    return _fallbackTempToken;
  }

  bool get isConfigured => appId.isNotEmpty;
  bool get isChatConfigured => chatAppKey.isNotEmpty;

  /// Generates a deterministic Agora channel name from a Firestore session ID.
  ///
  /// Agora channel names must be ≤64 bytes and only contain [a-z A-Z 0-9 ! # $ % & ( ) + - : ; < = . > ? @ [ ] ^ _ { | } ~ , space].
  /// We simply use the first 32 chars of the session doc ID (which is alphanumeric).
  String channelFromSessionId(String sessionId) {
    // Firestore doc IDs are already safe characters; just limit length.
    return sessionId.length > 32 ? sessionId.substring(0, 32) : sessionId;
  }

  /// Called when joining a channel. Returns the token to use.
  ///
  /// - Automatically generates a dynamic 24-hour RTC token if [appCertificate] is set in .env.
  /// - Falls back to [tempToken] if provided.
  /// - Falls back to empty string (Testing mode without App Certificate).
  Future<String> fetchToken({
    required String channelName,
    dynamic uid = 0,
  }) async {
    // 1. If App Certificate is provided, generate a fresh dynamic token for this channel
    if (appCertificate.isNotEmpty && appId.isNotEmpty) {
      try {
        final expireTimestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + (24 * 3600);
        // In Agora AccessToken (006), numeric wildcard uid == 0 is represented
        // as empty string "" yielding crc_uid = 0. Passing "0" generates CRC32('0')
        // which Agora server rejects with error 110 (invalid token).
        final String tokenUid;
        if (uid is int) {
          tokenUid = uid == 0 ? '' : uid.toString();
        } else if (uid is String) {
          tokenUid = (uid == '0' || uid.isEmpty) ? '' : uid;
        } else {
          tokenUid = '';
        }

        final token = RtcTokenBuilder.build(
          appId: appId,
          appCertificate: appCertificate,
          channelName: channelName,
          uid: tokenUid,
          role: RtcRole.publisher,
          expireTimestamp: expireTimestamp,
        );
        debugPrint('[Agora] Generated dynamic RTC token for channel: $channelName (tokenUid: "$tokenUid")');
        return token;
      } catch (e) {
        debugPrint('[Agora] Dynamic token generation failed: $e');
      }
    }

    // 2. Fallback to AGORA_TEMP_TOKEN from .env
    if (tempToken.isNotEmpty) {
      debugPrint('[Agora] Using AGORA_TEMP_TOKEN from .env for channel: $channelName');
      return tempToken;
    }

    // 3. Fallback to null/empty token (Testing mode)
    debugPrint('[Agora] Using null/empty token for channel: $channelName');
    return '';
  }
}
