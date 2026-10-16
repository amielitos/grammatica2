import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'role_service.dart';

/// Exception thrown when an AI generation is blocked by rate limiting or cooldown.
class AIRateLimitException implements Exception {
  final String message;
  final bool isBurst;
  final Duration? cooldownRemaining;
  final int used;
  final int limit;
  final Duration? timeUntilReset;

  const AIRateLimitException({
    required this.message,
    this.isBurst = false,
    this.cooldownRemaining,
    this.used = 0,
    this.limit = 0,
    this.timeUntilReset,
  });

  @override
  String toString() => message;
}

/// Represents the current rate limit and quota state for a user.
class AIRateLimitStatus {
  final int used;
  final int limit;
  final String date;
  final UserRole role;
  final bool isSubscribed;

  const AIRateLimitStatus({
    required this.used,
    required this.limit,
    required this.date,
    required this.role,
    required this.isSubscribed,
  });

  bool get isUnlimited => limit < 0;

  bool get isExceeded => !isUnlimited && used >= limit;

  int get remaining => isUnlimited ? 999999 : math.max(0, limit - used);

  double get percentUsed =>
      isUnlimited || limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);

  Duration get timeUntilReset {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  String get formattedTimeUntilReset {
    final duration = timeUntilReset;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Service that coordinates AI rate limiting, burst protection, and daily quotas.
class AIRateLimitService {
  AIRateLimitService._();
  static final instance = AIRateLimitService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Quotas by Role / Tier ──────────────────────────────────────────────────
  static const int freeLearnerDailyLimit = 10;
  static const int subscribedLearnerDailyLimit = 100;
  static const int educatorDailyLimit = 200;
  static const int adminDailyLimit = -1; // -1 represents unlimited

  // ── Burst Cooldowns in Seconds ─────────────────────────────────────────────
  static const int freeLearnerBurstSeconds = 15;
  static const int subscribedLearnerBurstSeconds = 5;
  static const int educatorBurstSeconds = 3;
  static const int adminBurstSeconds = 0;

  // In-memory tracker for burst cooldowns: Map<uid, lastTimestamp>
  final Map<String, DateTime> _lastRequestTimes = {};

  String _todayDateStr() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  int getLimitForRole(UserRole role, bool isSubscribed) {
    if (role == UserRole.admin || role == UserRole.superadmin) {
      return adminDailyLimit;
    }
    if (role == UserRole.educator) {
      return educatorDailyLimit;
    }
    return isSubscribed ? subscribedLearnerDailyLimit : freeLearnerDailyLimit;
  }

  int getBurstSeconds(UserRole role, bool isSubscribed) {
    if (role == UserRole.admin || role == UserRole.superadmin) {
      return adminBurstSeconds;
    }
    if (role == UserRole.educator) {
      return educatorBurstSeconds;
    }
    return isSubscribed ? subscribedLearnerBurstSeconds : freeLearnerBurstSeconds;
  }

  /// Checks whether the user has active subscriptions or premium status.
  Future<bool> isUserSubscribed(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final status = (userDoc.data()?['subscription_status'] ?? '').toString().toUpperCase();
      if (status.isNotEmpty && status != 'NONE') {
        return true;
      }

      // Check active subscriptions subcollection
      final subSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      return subSnap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[AIRateLimit] Error checking subscription: $e');
      return false;
    }
  }

  /// Fetches the current user's AI quota status.
  Future<AIRateLimitStatus> getStatus(String uid) async {
    final role = await RoleService.instance.getRole(uid);
    final subscribed = (role == UserRole.learner) ? await isUserSubscribed(uid) : false;
    final limit = getLimitForRole(role, subscribed);

    final today = _todayDateStr();
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_usage')
        .doc('daily');

    int used = 0;
    try {
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        if (data['date'] == today) {
          used = (data['used'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (e) {
      debugPrint('[AIRateLimit] Error reading usage: $e');
    }

    return AIRateLimitStatus(
      used: used,
      limit: limit,
      date: today,
      role: role,
      isSubscribed: subscribed,
    );
  }

  /// Real-time stream of quota status for reactive UI badges.
  Stream<AIRateLimitStatus> quotaStream(String uid) {
    final today = _todayDateStr();
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_usage')
        .doc('daily');

    return docRef.snapshots().asyncMap((snap) async {
      final role = await RoleService.instance.getRole(uid);
      final subscribed = (role == UserRole.learner) ? await isUserSubscribed(uid) : false;
      final limit = getLimitForRole(role, subscribed);

      int used = 0;
      if (snap.exists) {
        final data = snap.data() ?? {};
        if (data['date'] == today) {
          used = (data['used'] as num?)?.toInt() ?? 0;
        }
      }

      return AIRateLimitStatus(
        used: used,
        limit: limit,
        date: today,
        role: role,
        isSubscribed: subscribed,
      );
    });
  }

  /// Checks burst cooldown. Throws [AIRateLimitException] if the user is clicking too quickly.
  void checkBurst(String uid, UserRole role, bool isSubscribed) {
    final cooldownSecs = getBurstSeconds(role, isSubscribed);
    if (cooldownSecs <= 0) return;

    final last = _lastRequestTimes[uid];
    if (last != null) {
      final diff = DateTime.now().difference(last);
      final remaining = Duration(seconds: cooldownSecs) - diff;
      if (!remaining.isNegative && remaining.inSeconds > 0) {
        throw AIRateLimitException(
          message: 'Please wait ${remaining.inSeconds} seconds before generating again.',
          isBurst: true,
          cooldownRemaining: remaining,
        );
      }
    }
  }

  /// Records that a request succeeded, updating both the Firestore daily counter
  /// and the in-memory burst timer.
  Future<void> recordUsage(String uid) async {
    _lastRequestTimes[uid] = DateTime.now();

    final today = _todayDateStr();
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_usage')
        .doc('daily');

    try {
      final snap = await docRef.get();
      if (!snap.exists || snap.data()?['date'] != today) {
        await docRef.set({
          'date': today,
          'used': 1,
          'lastRequestAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          'used': FieldValue.increment(1),
          'lastRequestAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[AIRateLimit] Error recording usage: $e');
    }
  }

  /// Convenience wrapper: verifies rate limit and burst cooldown before executing [action],
  /// and only records quota consumption upon successful execution.
  Future<T> runWithRateLimit<T>({
    String? uid,
    required String actionName,
    required Future<T> Function() action,
  }) async {
    final targetUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) {
      // Unauthenticated fallback: execute directly
      return await action();
    }

    final status = await getStatus(targetUid);

    // 1. Check daily quota
    if (status.isExceeded) {
      throw AIRateLimitException(
        message: 'Daily AI generation limit reached (${status.used}/${status.limit}).',
        isBurst: false,
        used: status.used,
        limit: status.limit,
        timeUntilReset: status.timeUntilReset,
      );
    }

    // 2. Check burst cooldown
    checkBurst(targetUid, status.role, status.isSubscribed);

    // 3. Execute the actual AI operation
    final result = await action();

    // 4. Upon success, consume quota
    await recordUsage(targetUid);

    return result;
  }
}
