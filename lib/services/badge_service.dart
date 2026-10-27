import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/badge_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/badge_unlocked_dialog.dart';

class BadgeService {
  BadgeService._internal();
  static final BadgeService instance = BadgeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _badgesCollection =>
      _firestore.collection('badges');

  CollectionReference<Map<String, dynamic>> _userEarnedBadges(String uid) =>
      _firestore.collection('users').doc(uid).collection('earnedBadges');

  DocumentReference<Map<String, dynamic>> _userStatsDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('stats').doc('summary');

  /// Seed badges from assets/seed/badges_seed.json into Firestore if empty
  Future<void> seedBadgesIfEmpty({bool force = false}) async {
    try {
      final snap = await _badgesCollection.limit(1).get();
      if (snap.docs.isNotEmpty && !force) {
        debugPrint('[BadgeService] Badges already seeded in Firestore.');
        return;
      }

      final jsonString =
          await rootBundle.loadString('assets/seed/badges_seed.json');
      final Map<String, dynamic> parsed = jsonDecode(jsonString);
      final List badgesList = parsed['badges'] as List? ?? [];

      final batch = _firestore.batch();
      for (final item in badgesList) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String;
        final docRef = _badgesCollection.doc(id);
        batch.set(docRef, map, SetOptions(merge: true));
      }
      await batch.commit();
      debugPrint('[BadgeService] Successfully seeded ${badgesList.length} badges.');
    } catch (e) {
      debugPrint('[BadgeService] Error seeding badges: $e');
    }
  }

  /// Streams all active badges ordered by order
  Stream<List<BadgeModel>> streamBadges() {
    return _badgesCollection
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BadgeModel.fromMap(doc.id, doc.data()))
          .where((b) => b.isActive)
          .toList();
    });
  }

  /// Streams IDs of badges earned by user
  Stream<Map<String, EarnedBadge>> streamEarnedBadges(String uid) {
    return _userEarnedBadges(uid).snapshots().map((snapshot) {
      final map = <String, EarnedBadge>{};
      for (final doc in snapshot.docs) {
        map[doc.id] = EarnedBadge.fromDoc(doc);
      }
      return map;
    });
  }

  /// Streams UserBadgeStats
  Stream<UserBadgeStats> streamUserStats(String uid) {
    return _userStatsDoc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return const UserBadgeStats();
      }
      return UserBadgeStats.fromMap(doc.data()!);
    });
  }

  /// Check and update daily activity streak
  /// (+1 if yesterday, reset to 1 if older, unchanged if today)
  Future<void> checkDailyActivity(String uid, {BuildContext? context}) async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final docRef = _userStatsDoc(uid);
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        final data = snap.data() ?? {};

        int streak = (data['current_streak'] as num?)?.toInt() ??
            (data['studyStreakDays'] as num?)?.toInt() ??
            0;
        final lastDate = (data['last_active_date'] as String?) ??
            (data['lastActiveDate'] as String?);

        if (lastDate == todayStr) {
          if (streak == 0) streak = 1;
        } else if (lastDate == yesterdayStr) {
          streak += 1;
        } else {
          streak = 1;
        }

        final update = {
          'current_streak': streak,
          'last_active_date': todayStr,
          'studyStreakDays': streak,
          'lastActiveDate': todayStr,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.set(docRef, update, SetOptions(merge: true));
      });

      await evaluateAndAwardBadges(uid);
    } catch (e) {
      debugPrint('[BadgeService] Error checking daily activity: $e');
    }
  }

  /// Record a lesson completion
  Future<void> recordLessonCompletion(String uid, {BuildContext? context}) async {
    await _incrementStat(uid, 'lessons_completed', amount: 1);
  }

  /// Record a 100% perfect quiz score
  Future<void> recordPerfectQuiz(String uid, {BuildContext? context}) async {
    await _incrementStat(uid, 'perfect_quizzes', amount: 1);
  }

  /// Record an SM-2 flashcard review
  Future<void> recordFlashcardReviewed(String uid,
      {int count = 1, BuildContext? context}) async {
    await _incrementStat(uid, 'flashcards_reviewed',
        amount: count);
  }

  /// Record a correct answer in Spelling Bee
  Future<void> recordSpellingCorrect(String uid, {BuildContext? context}) async {
    await _incrementStat(uid, 'spelling_correct', amount: 1);
  }

  /// Core helper to increment a stat and check badges
  Future<void> _incrementStat(
    String uid,
    String criteriaType, {
    int amount = 1,
  }) async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final docRef = _userStatsDoc(uid);
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        final data = snap.data() ?? {};

        int currentVal = (data[criteriaType] as num?)?.toInt() ?? 0;
        currentVal += amount;

        // Daily streak maintenance
        int streak = (data['current_streak'] as num?)?.toInt() ??
            (data['studyStreakDays'] as num?)?.toInt() ??
            0;
        final lastDate = (data['last_active_date'] as String?) ??
            (data['lastActiveDate'] as String?);

        if (lastDate == todayStr) {
          if (streak == 0) streak = 1;
        } else if (lastDate == yesterdayStr) {
          streak += 1;
        } else {
          streak = 1;
        }

        final update = <String, dynamic>{
          criteriaType: currentVal,
          'current_streak': streak,
          'last_active_date': todayStr,
          'studyStreakDays': streak,
          'lastActiveDate': todayStr,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Also sync legacy keys if applicable
        if (criteriaType == 'lessons_completed') {
          update['totalLessonsCompleted'] = currentVal;
        } else if (criteriaType == 'flashcards_reviewed') {
          update['flashcardsReviewed'] = currentVal;
        }

        transaction.set(docRef, update, SetOptions(merge: true));
      });

      await evaluateAndAwardBadges(uid);
    } catch (e) {
      debugPrint('[BadgeService] Error incrementing stat $criteriaType: $e');
    }
  }

  /// Evaluates all badges and awards any newly earned badges
  Future<List<BadgeModel>> evaluateAndAwardBadges(String uid) async {
    final awarded = <BadgeModel>[];
    try {
      // 1. Fetch current user stats
      final statsSnap = await _userStatsDoc(uid).get();
      final statsData = statsSnap.data() ?? {};
      final stats = UserBadgeStats.fromMap(statsData);

      // 2. Fetch all active badges
      final badgesSnap = await _badgesCollection.where('isActive', isEqualTo: true).get();
      if (badgesSnap.docs.isEmpty) {
        // Badges not seeded yet - auto-seed
        await seedBadgesIfEmpty();
        return evaluateAndAwardBadges(uid);
      }
      final allBadges = badgesSnap.docs
          .map((d) => BadgeModel.fromMap(d.id, d.data()))
          .toList();

      // 3. Fetch already earned badge IDs
      final earnedSnap = await _userEarnedBadges(uid).get();
      final earnedIds = earnedSnap.docs.map((d) => d.id).toSet();

      // 4. Check eligibility
      for (final badge in allBadges) {
        if (earnedIds.contains(badge.id)) continue;

        final statVal = stats.getStat(badge.criteriaType);
        if (statVal >= badge.threshold) {
          // Award badge
          await _userEarnedBadges(uid).doc(badge.id).set({
            'earnedAt': FieldValue.serverTimestamp(),
            'badgeId': badge.id,
            'name': badge.name,
            'criteriaType': badge.criteriaType,
            'threshold': badge.threshold,
          });

          awarded.add(badge);

          // In-app notification
          try {
            NotificationService.instance.sendAchievementNotification(
              uid: uid,
              title: 'Badge Unlocked: ${badge.name}!',
              message: badge.description,
            );
          } catch (_) {}
        }
      }

      // 5. Show Badge Unlocked dialog for each awarded badge
      if (awarded.isNotEmpty) {
        final ctx = AuthService.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          for (final badge in awarded) {
            BadgeUnlockedDialog.show(ctx, badge);
          }
        }
      }
    } catch (e) {
      debugPrint('[BadgeService] Error evaluating badges: $e');
    }
    return awarded;
  }
}
