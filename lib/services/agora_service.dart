import 'package:agora_token_service/agora_token_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utility service for Agora configuration and channel ID helpers.
class AgoraService {
  AgoraService._();
  static final instance = AgoraService._();

  /// The Agora RTC App ID. Must be set in .env as `AGORA_APP_ID`.
  String get appId => dotenv.env['AGORA_APP_ID'] ?? '';

  /// The Agora Chat App Key. Must be set in .env as `AGORA_CHAT_APP_KEY`.
  String get chatAppKey => dotenv.env['AGORA_CHAT_APP_KEY'] ?? '';

  /// Primary Certificate from Agora Console > Security.
  /// Set in .env as `AGORA_APP_CERTIFICATE`.
  String get appCertificate => dotenv.env['AGORA_APP_CERTIFICATE'] ?? '';

  /// Optional temporary RTC token if App Certificate is enabled in Agora Console.
  /// Set in .env as `AGORA_TEMP_TOKEN`.
  String get tempToken => dotenv.env['AGORA_TEMP_TOKEN'] ?? '';

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
    required String uid,
  }) async {
    // 1. If App Certificate is provided, generate a fresh dynamic token for this channel
    if (appCertificate.isNotEmpty && appId.isNotEmpty) {
      try {
        final expireTimestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + (24 * 3600);
        final token = RtcTokenBuilder.build(
          appId: appId,
          appCertificate: appCertificate,
          channelName: channelName,
          uid: '0', // 0 = wildcard, matches uid: 0 passed to joinChannel
          role: RtcRole.publisher,
          expireTimestamp: expireTimestamp,
        );
        debugPrint('[Agora] Generated dynamic RTC token for channel: $channelName');
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
