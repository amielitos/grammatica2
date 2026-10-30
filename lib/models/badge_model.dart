import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final String criteriaType;
  final int threshold;
  final String tier;
  final String iconAsset;
  final bool isActive;
  final int order;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.criteriaType,
    required this.threshold,
    required this.tier,
    required this.iconAsset,
    required this.isActive,
    required this.order,
  });

  factory BadgeModel.fromMap(String id, Map<String, dynamic> data) {
    return BadgeModel(
      id: id,
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      criteriaType: (data['criteriaType'] as String?) ?? '',
      threshold: (data['threshold'] as num?)?.toInt() ?? 1,
      tier: (data['tier'] as String?) ?? 'bronze',
      iconAsset: (data['iconAsset'] as String?) ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'criteriaType': criteriaType,
      'threshold': threshold,
      'tier': tier,
      'iconAsset': iconAsset,
      'isActive': isActive,
      'order': order,
    };
  }
}

class EarnedBadge {
  final String badgeId;
  final DateTime? earnedAt;

  const EarnedBadge({
    required this.badgeId,
    this.earnedAt,
  });

  factory EarnedBadge.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? earned;
    final rawTs = data['earnedAt'];
    if (rawTs is Timestamp) {
      earned = rawTs.toDate();
    } else if (rawTs is String) {
      earned = DateTime.tryParse(rawTs);
    }
    return EarnedBadge(
      badgeId: doc.id,
      earnedAt: earned,
    );
  }
}

class UserBadgeStats {
  final int lessonsCompleted;
  final int perfectQuizzes;
  final int flashcardsReviewed;
  final int spellingCorrect;
  final int currentStreak;
  final int longestStreak;
  final String? lastActiveDate;

  const UserBadgeStats({
    this.lessonsCompleted = 0,
    this.perfectQuizzes = 0,
    this.flashcardsReviewed = 0,
    this.spellingCorrect = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
  });

  factory UserBadgeStats.fromMap(Map<String, dynamic> data) {
    final current = (data['currentStreak'] as num?)?.toInt() ??
        (data['current_streak'] as num?)?.toInt() ??
        (data['studyStreakDays'] as num?)?.toInt() ??
        0;
    final longest = (data['longestStreak'] as num?)?.toInt() ??
        (data['longest_streak'] as num?)?.toInt() ??
        current;
    return UserBadgeStats(
      lessonsCompleted: (data['lessons_completed'] as num?)?.toInt() ??
          (data['totalLessonsCompleted'] as num?)?.toInt() ??
          0,
      perfectQuizzes: (data['perfect_quizzes'] as num?)?.toInt() ?? 0,
      flashcardsReviewed: (data['flashcards_reviewed'] as num?)?.toInt() ??
          (data['flashcardsReviewed'] as num?)?.toInt() ??
          0,
      spellingCorrect: (data['spelling_correct'] as num?)?.toInt() ?? 0,
      currentStreak: current,
      longestStreak: longest < current ? current : longest,
      lastActiveDate: (data['lastActiveDate'] as String?) ??
          (data['last_active_date'] as String?),
    );
  }

  int getStat(String criteriaType) {
    switch (criteriaType) {
      case 'lessons_completed':
        return lessonsCompleted;
      case 'perfect_quizzes':
        return perfectQuizzes;
      case 'flashcards_reviewed':
        return flashcardsReviewed;
      case 'spelling_correct':
        return spellingCorrect;
      case 'current_streak':
        return currentStreak;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'lessons_completed': lessonsCompleted,
      'perfect_quizzes': perfectQuizzes,
      'flashcards_reviewed': flashcardsReviewed,
      'spelling_correct': spellingCorrect,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_active_date': lastActiveDate,
      // Compatibility fields for existing dashboard
      'totalLessonsCompleted': lessonsCompleted,
      'flashcardsReviewed': flashcardsReviewed,
      'studyStreakDays': currentStreak,
    };
  }
}
