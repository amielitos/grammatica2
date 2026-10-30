import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
  final Set<String> _inFlightStreakChecks = <String>{};

  /// Returns today's date string ("yyyy-MM-dd") in Philippine Time (Asia/Manila, UTC+8).
  static String getManilaTodayString([DateTime? utcTime]) {
    final manila = (utcTime ?? DateTime.now().toUtc()).toUtc().add(const Duration(hours: 8));
    return '${manila.year.toString().padLeft(4, '0')}-${manila.month.toString().padLeft(2, '0')}-${manila.day.toString().padLeft(2, '0')}';
  }

  /// Returns yesterday's date string ("yyyy-MM-dd") in Philippine Time (Asia/Manila, UTC+8).
  static String getManilaYesterdayString([DateTime? utcTime]) {
    final manila = (utcTime ?? DateTime.now().toUtc()).toUtc().add(const Duration(hours: 8));
    final yesterday = DateTime.utc(manila.year, manila.month, manila.day).subtract(const Duration(days: 1));
    return '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  /// Display the stored streak only if [lastActiveDate] is today or yesterday (Asia/Manila);
  /// otherwise display 0 until today's activity is recorded.
  static int computeEffectiveDisplayStreak(int storedStreak, String? lastActiveDate) {
    if (storedStreak <= 0 || lastActiveDate == null || lastActiveDate.trim().isEmpty) {
      return 0;
    }
    final cleanDate = lastActiveDate.trim();
    final todayStr = getManilaTodayString();
    final yesterdayStr = getManilaYesterdayString();
    if (cleanDate == todayStr || cleanDate == yesterdayStr) {
      return storedStreak;
    }
    return 0;
  }

  CollectionReference<Map<String, dynamic>> get _badgesCollection =>
      _firestore.collection('badges');

  CollectionReference<Map<String, dynamic>> _userEarnedBadges(String uid) =>
      _firestore.collection('users').doc(uid).collection('earnedBadges');

  DocumentReference<Map<String, dynamic>> _userStatsDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('stats').doc('summary');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

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

  /// Real-time count of badges earned by [uid] (`users/{uid}/earnedBadges`).
  Stream<int> streamEarnedBadgesCount(String uid) {
    return _userEarnedBadges(uid).snapshots().map((snapshot) => snapshot.docs.length);
  }

  /// Real-time Daily Streak stream combining `users/{uid}/stats/summary` and `users/{uid}`.
  /// Automatically reconciles if `lastActiveDate` is changed in Firestore while the learner is active.
  Stream<int> streamDailyStreak(String uid) {
    late StreamController<int> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? statsSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;

    Map<String, dynamic>? latestStats;
    Map<String, dynamic>? latestUser;
    bool hasStats = false;
    bool hasUser = false;

    void emitCombined() {
      if (!hasStats && !hasUser) return;
      final sData = latestStats ?? const <String, dynamic>{};
      final uData = latestUser ?? const <String, dynamic>{};
      final todayStr = getManilaTodayString();

      final sLastDate = ((sData['lastActiveDate'] as String?) ??
              (sData['last_active_date'] as String?))
          ?.trim();
      final uLastDate = ((uData['lastActiveDate'] as String?) ??
              (uData['last_active_date'] as String?))
          ?.trim();

      final sStreak = (sData['currentStreak'] as num?)?.toInt() ??
          (sData['current_streak'] as num?)?.toInt() ??
          (sData['studyStreakDays'] as num?)?.toInt() ??
          0;
      final uStreak = (uData['currentStreak'] as num?)?.toInt() ??
          (uData['current_streak'] as num?)?.toInt() ??
          (uData['studyStreakDays'] as num?)?.toInt() ??
          0;

      String? effectiveDate;
      int storedStreak;

      if (uLastDate != null && uLastDate != todayStr && sLastDate == todayStr) {
        effectiveDate = uLastDate;
        storedStreak = uStreak > 0 ? uStreak : sStreak;
      } else if (sLastDate != null && sLastDate != todayStr && uLastDate == todayStr) {
        effectiveDate = sLastDate;
        storedStreak = sStreak > 0 ? sStreak : uStreak;
      } else {
        effectiveDate = sLastDate ?? uLastDate;
        storedStreak = sStreak > 0 ? sStreak : uStreak;
      }

      final displayStreak = computeEffectiveDisplayStreak(storedStreak, effectiveDate);
      if (!controller.isClosed) {
        controller.add(displayStreak);
      }

      // If the learner has the app open and lastActiveDate is not today (e.g. first open today
      // or manually edited in Firestore for testing), trigger atomic streak update.
      if (hasStats && hasUser && effectiveDate != todayStr) {
        checkDailyActivity(uid);
      }
    }

    controller = StreamController<int>.broadcast(
      onListen: () {
        statsSub = _userStatsDoc(uid).snapshots().listen(
          (snap) {
            hasStats = true;
            latestStats = snap.data();
            emitCombined();
          },
          onError: (Object err, StackTrace st) {
            debugPrint('[BadgeService] streamDailyStreak stats error: $err');
            if (!controller.isClosed) controller.addError(err, st);
          },
        );
        userSub = _userDoc(uid).snapshots().listen(
          (snap) {
            hasUser = true;
            latestUser = snap.data();
            emitCombined();
          },
          onError: (Object err, StackTrace st) {
            debugPrint('[BadgeService] streamDailyStreak user error: $err');
            if (!controller.isClosed) controller.addError(err, st);
          },
        );
      },
      onCancel: () async {
        await statsSub?.cancel();
        await userSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Check and update daily activity streak in Asia/Manila (UTC+8) timezone:
  /// - same day: do nothing (do not write again if lastActiveDate is already today)
  /// - exactly 1 day later (yesterday): currentStreak + 1
  /// - more than 1 day later or no previous value: reset currentStreak to 1
  /// - always update longestStreak = max(longestStreak, currentStreak)
  Future<void> checkDailyActivity(String uid, {BuildContext? context}) async {
    if (uid.isEmpty || _inFlightStreakChecks.contains(uid)) return;
    _inFlightStreakChecks.add(uid);
    try {
      final todayStr = getManilaTodayString();
      final yesterdayStr = getManilaYesterdayString();

      final statsRef = _userStatsDoc(uid);
      final userRef = _userDoc(uid);
      bool didUpdate = false;

      await _firestore.runTransaction((transaction) async {
        final statsSnap = await transaction.get(statsRef);
        final userSnap = await transaction.get(userRef);
        final statsData = statsSnap.data() ?? {};
        final userData = userSnap.data() ?? {};
        final userRole = (userData['role'] as String?)?.toLowerCase();
        if (userRole != null && userRole != 'learner') {
          return; // Streaks and badges are strictly for learners
        }

        final statsLastDate = ((statsData['lastActiveDate'] as String?) ??
                (statsData['last_active_date'] as String?))
            ?.trim();
        final userLastDate = ((userData['lastActiveDate'] as String?) ??
                (userData['last_active_date'] as String?))
            ?.trim();

        final statsStreak = (statsData['currentStreak'] as num?)?.toInt() ??
            (statsData['current_streak'] as num?)?.toInt() ??
            (statsData['studyStreakDays'] as num?)?.toInt() ??
            0;
        final userStreak = (userData['currentStreak'] as num?)?.toInt() ??
            (userData['current_streak'] as num?)?.toInt() ??
            (userData['studyStreakDays'] as num?)?.toInt() ??
            0;

        final statsLongest = (statsData['longestStreak'] as num?)?.toInt() ??
            (statsData['longest_streak'] as num?)?.toInt() ??
            0;
        final userLongest = (userData['longestStreak'] as num?)?.toInt() ??
            (userData['longest_streak'] as num?)?.toInt() ??
            0;

        // Determine source of truth: if one doc was manually edited in Firestore
        // to a date other than today, prioritize that doc's date & streak.
        String? lastDate;
        int streak;
        if (userLastDate != null && userLastDate != todayStr && statsLastDate == todayStr) {
          lastDate = userLastDate;
          streak = userStreak > 0 ? userStreak : statsStreak;
        } else if (statsLastDate != null && statsLastDate != todayStr && userLastDate == todayStr) {
          lastDate = statsLastDate;
          streak = statsStreak > 0 ? statsStreak : userStreak;
        } else {
          lastDate = statsLastDate ?? userLastDate;
          streak = statsStreak > 0 ? statsStreak : userStreak;
        }

        int longestStreak = math.max(statsLongest, userLongest);

        // If lastActiveDate is already today on both documents and streak > 0, do nothing!
        if (lastDate == todayStr &&
            statsLastDate == todayStr &&
            userLastDate == todayStr &&
            streak > 0 &&
            statsStreak == userStreak) {
          return;
        }

        if (lastDate == todayStr) {
          if (streak <= 0) streak = 1;
        } else if (lastDate == yesterdayStr) {
          streak = (streak > 0 ? streak : 0) + 1;
        } else {
          streak = 1;
        }

        longestStreak = math.max(longestStreak, streak);
        didUpdate = true;

        final statsUpdate = <String, dynamic>{
          'currentStreak': streak,
          'longestStreak': longestStreak,
          'lastActiveDate': todayStr,
          'current_streak': streak,
          'longest_streak': longestStreak,
          'last_active_date': todayStr,
          'studyStreakDays': streak,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final userUpdate = <String, dynamic>{
          'currentStreak': streak,
          'longestStreak': longestStreak,
          'lastActiveDate': todayStr,
        };

        transaction.set(statsRef, statsUpdate, SetOptions(merge: true));
        transaction.set(userRef, userUpdate, SetOptions(merge: true));
      });

      if (didUpdate) {
        await evaluateAndAwardBadges(uid);
      }
    } catch (e) {
      debugPrint('[BadgeService] Error checking daily activity: $e');
    } finally {
      _inFlightStreakChecks.remove(uid);
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
      final todayStr = getManilaTodayString();
      final yesterdayStr = getManilaYesterdayString();

      final docRef = _userStatsDoc(uid);
      final userRef = _userDoc(uid);
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        final userSnap = await transaction.get(userRef);
        final data = snap.data() ?? {};
        final userData = userSnap.data() ?? {};
        final userRole = (userData['role'] as String?)?.toLowerCase();
        if (userRole != null && userRole != 'learner') {
          return; // Streaks and badges are strictly for learners
        }

        int currentVal = (data[criteriaType] as num?)?.toInt() ?? 0;
        currentVal += amount;

        // Daily streak maintenance (Asia/Manila UTC+8)
        int streak = (data['currentStreak'] as num?)?.toInt() ??
            (data['current_streak'] as num?)?.toInt() ??
            (data['studyStreakDays'] as num?)?.toInt() ??
            (userData['currentStreak'] as num?)?.toInt() ??
            0;
        int longestStreak = (data['longestStreak'] as num?)?.toInt() ??
            (data['longest_streak'] as num?)?.toInt() ??
            (userData['longestStreak'] as num?)?.toInt() ??
            0;
        final lastDate = ((data['lastActiveDate'] as String?) ??
                (data['last_active_date'] as String?) ??
                (userData['lastActiveDate'] as String?))
            ?.trim();

        if (lastDate == todayStr) {
          if (streak <= 0) streak = 1;
        } else if (lastDate == yesterdayStr) {
          streak += 1;
        } else {
          streak = 1;
        }
        longestStreak = math.max(longestStreak, streak);

        final update = <String, dynamic>{
          criteriaType: currentVal,
          'currentStreak': streak,
          'longestStreak': longestStreak,
          'lastActiveDate': todayStr,
          'current_streak': streak,
          'longest_streak': longestStreak,
          'last_active_date': todayStr,
          'studyStreakDays': streak,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Also sync legacy keys if applicable
        if (criteriaType == 'lessons_completed') {
          update['totalLessonsCompleted'] = currentVal;
        } else if (criteriaType == 'flashcards_reviewed') {
          update['flashcardsReviewed'] = currentVal;
        }

        transaction.set(docRef, update, SetOptions(merge: true));
        transaction.set(
          userRef,
          {
            'currentStreak': streak,
            'longestStreak': longestStreak,
            'lastActiveDate': todayStr,
          },
          SetOptions(merge: true),
        );
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
      // 0. Ensure user is a learner - Educators, Validators, Superadmins NEVER earn badges
      final userSnap = await _userDoc(uid).get();
      final userRole = (userSnap.data()?['role'] as String?)?.toLowerCase();
      if (userRole != null && userRole != 'learner') {
        debugPrint('[BadgeService] Skipping badge check for non-learner role ($userRole) on uid: $uid');
        return awarded;
      }

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
