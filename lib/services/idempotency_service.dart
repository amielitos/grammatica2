import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Idempotency Engine for Grammatica.
///
/// Provides:
/// 1. RFC 4122 v4 UUID & semantic deterministic key generators.
/// 2. In-flight request deduplication (Single-Flight/Future coalescing).
/// 3. Persistent local cache for completed operations (preventing duplicate client actions).
/// 4. Standardized HTTP header propagation for Payment, AI, and Email requests.
class IdempotencyService {
  IdempotencyService._();
  static final IdempotencyService instance = IdempotencyService._();

  final Random _random = Random.secure();
  final Map<String, Future<dynamic>> _inFlightTasks = {};

  static const String _prefPrefix = 'grammatica_idempotency_';
  static const int defaultTtlSeconds = 86400; // 24 hours

  // ── 1. Key Generators ───────────────────────────────────────────────────────

  /// Generates a cryptographically secure RFC 4122 v4 UUID string.
  String generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Set version to 0100 (v4)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to 10xx (RFC 4122)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String toHex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    final hexList = bytes.map(toHex).toList();
    return '${hexList.sublist(0, 4).join()}-'
        '${hexList.sublist(4, 6).join()}-'
        '${hexList.sublist(6, 8).join()}-'
        '${hexList.sublist(8, 10).join()}-'
        '${hexList.sublist(10, 16).join()}';
  }

  /// Generates a deterministic payment idempotency key for an educator subscription.
  /// Formatted as: `pay_<learnerUid>_<educatorUid>_<tier>_<sessionTimestamp>`
  String generatePaymentKey({
    required String learnerUid,
    required String educatorUid,
    required String tier,
    String? sessionSalt,
  }) {
    final salt = sessionSalt ?? DateTime.now().millisecondsSinceEpoch.toString();
    final cleanTier = tier.trim().toLowerCase();
    return 'pay_${learnerUid}_${educatorUid}_${cleanTier}_$salt';
  }

  /// Generates a deterministic key for scheduling mentorship sessions.
  String generateMentorshipKey({
    required String educatorUid,
    required String studentUid,
    required DateTime startTime,
  }) {
    return 'mentor_${educatorUid}_${studentUid}_${startTime.millisecondsSinceEpoch}';
  }

  /// Generates a deterministic key for AI generation tasks.
  String generateAiKey({
    required String action,
    required String contentSnippet,
  }) {
    final hash = contentSnippet.hashCode.abs().toRadixString(16);
    return 'ai_${action}_$hash';
  }

  /// Generates a deterministic key for email receipts.
  String generateEmailReceiptKey({
    required String recipientEmail,
    required String referenceNumber,
  }) {
    return 'email_rcpt_${recipientEmail.trim().toLowerCase()}_${referenceNumber.trim()}';
  }

  // ── 2. In-Flight Single-Flight Request Deduplication ────────────────────────

  /// Executes [action] with in-flight deduplication.
  ///
  /// If a task with the exact same [key] is currently executing, this returns
  /// the active [Future] rather than spawning a duplicate network request or
  /// database operation.
  Future<T> executeDeduplicated<T>({
    required String key,
    required Future<T> Function() action,
  }) async {
    final existing = _inFlightTasks[key];
    if (existing != null) {
      debugPrint('[Idempotency] Request with key "$key" is ALREADY IN FLIGHT. Joining existing task.');
      return await existing as T;
    }

    final completer = Completer<T>();
    _inFlightTasks[key] = completer.future;

    try {
      final result = await action();
      completer.complete(result);
      return result;
    } catch (e, stack) {
      completer.completeError(e, stack);
      rethrow;
    } finally {
      _inFlightTasks.remove(key);
    }
  }

  // ── 3. Persistent Local Store for Completed Operations ─────────────────────

  /// Checks if a key has already been completed locally within the TTL.
  Future<bool> isCompletedLocally(String key, {int ttlSeconds = defaultTtlSeconds}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefPrefix$key');
      if (raw == null) return false;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if ((now - timestamp) > (ttlSeconds * 1000)) {
        // Expired
        await prefs.remove('$_prefPrefix$key');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[Idempotency] Error checking local cache: $e');
      return false;
    }
  }

  /// Marks an operation as completed locally with optional metadata.
  Future<void> markCompletedLocally(
    String key, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final record = {
        'key': key,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'metadata': metadata ?? {},
      };
      await prefs.setString('$_prefPrefix$key', jsonEncode(record));
    } catch (e) {
      debugPrint('[Idempotency] Error recording local completion: $e');
    }
  }

  // ── 4. Standard HTTP Headers ────────────────────────────────────────────────

  /// Builds standard headers containing the `Idempotency-Key` and `X-Idempotency-Key`.
  Map<String, String> buildHeaders({
    String? key,
    Map<String, String>? baseHeaders,
  }) {
    final headers = <String, String>{};
    if (baseHeaders != null) {
      headers.addAll(baseHeaders);
    }
    final effectiveKey = key ?? generateUuidV4();
    headers['Idempotency-Key'] = effectiveKey;
    headers['X-Idempotency-Key'] = effectiveKey;
    return headers;
  }
}
