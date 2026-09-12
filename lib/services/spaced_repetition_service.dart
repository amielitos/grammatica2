import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard_models.dart';

/// Service implementing the SuperMemo 2 (SM-2) Spaced Repetition algorithm
/// along with offline caching and progress synchronization.
class SpacedRepetitionService {
  SpacedRepetitionService._();
  static final SpacedRepetitionService instance = SpacedRepetitionService._();
  factory SpacedRepetitionService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userProgressCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('flashcard_progress');

  CollectionReference<Map<String, dynamic>> _userSessionsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('study_sessions');

  // ---------------------------------------------------------------------------
  // SM-2 Review Computation & Persistence
  // ---------------------------------------------------------------------------

  /// Pure SM-2 calculation method for determining next interval, ease factor, and repetition count.
  static FlashcardProgress computeNextProgress({
    required String cardId,
    required String deckId,
    required int quality,
    FlashcardProgress? currentProgress,
    DateTime? now,
  }) {
    assert(quality >= 0 && quality <= 5, 'Quality score must be between 0 and 5');

    int reps = currentProgress?.repetitions ?? 0;
    double easeFactor = currentProgress?.easeFactor ?? 2.5;
    int interval = currentProgress?.interval ?? 0;

    if (quality >= 3) {
      if (reps == 0) {
        interval = 1;
      } else if (reps == 1) {
        interval = 6;
      } else {
        interval = (interval * easeFactor).round();
      }
      reps++;
    } else {
      reps = 0;
      interval = 1;
    }

    // Ease Factor calculation formula
    easeFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (easeFactor < 1.3) {
      easeFactor = 1.3;
    }

    final reviewTime = now ?? DateTime.now();
    final nextReviewDate = reviewTime.add(Duration(days: interval));

    return FlashcardProgress(
      cardId: cardId,
      deckId: deckId,
      easeFactor: double.parse(easeFactor.toStringAsFixed(2)),
      interval: interval,
      repetitions: reps,
      nextReviewDate: nextReviewDate,
      lastReviewDate: reviewTime,
      quality: quality,
    );
  }

  /// Calculates the next review date, interval, and ease factor using the SM-2 algorithm,
  /// saves to Firestore and updates local SharedPreferences cache.
  Future<FlashcardProgress> reviewCard({
    required String cardId,
    required String deckId,
    required String userId,
    required int quality, // 0 = complete blackout, 5 = perfect recall
    FlashcardProgress? currentProgress,
  }) async {
    final updated = computeNextProgress(
      cardId: cardId,
      deckId: deckId,
      quality: quality,
      currentProgress: currentProgress,
    );

    // Save to Firestore
    final docId = '${deckId}_$cardId';
    await _userProgressCol(userId).doc(docId).set(updated.toMap());

    // Cache locally
    await _cacheProgress(userId, deckId, cardId, updated);

    return updated;
  }

  // ---------------------------------------------------------------------------
  // Progress Querying
  // ---------------------------------------------------------------------------

  /// Retrieves progress for all cards in a given deck for the specified user.
  Future<Map<String, FlashcardProgress>> getDeckProgress(
    String userId,
    String deckId,
  ) async {
    try {
      final snap = await _userProgressCol(userId)
          .where('deckId', isEqualTo: deckId)
          .get();

      final result = <String, FlashcardProgress>{};
      for (final doc in snap.docs) {
        final prog = FlashcardProgress.fromMap(doc.data());
        result[prog.cardId] = prog;
      }
      return result;
    } catch (e) {
      // Fallback to local cache if offline
      return _getLocalCachedDeckProgress(userId, deckId);
    }
  }

  /// Streams card progress for a given deck.
  Stream<Map<String, FlashcardProgress>> streamDeckProgress(
    String userId,
    String deckId,
  ) {
    return _userProgressCol(userId)
        .where('deckId', isEqualTo: deckId)
        .snapshots()
        .map((snap) {
      final map = <String, FlashcardProgress>{};
      for (final doc in snap.docs) {
        final prog = FlashcardProgress.fromMap(doc.data());
        map[prog.cardId] = prog;
      }
      return map;
    });
  }

  // ---------------------------------------------------------------------------
  // Session Logging
  // ---------------------------------------------------------------------------

  /// Logs a finished study session to Firestore and calculates streak.
  Future<void> logStudySession(StudySession session) async {
    final docRef = _userSessionsCol(session.userId).doc(session.id);
    await docRef.set(session.toMap());
  }

  // ---------------------------------------------------------------------------
  // Local Caching Helpers
  // ---------------------------------------------------------------------------

  String _cacheKey(String userId, String deckId, String cardId) =>
      'fc_prog_${userId}_${deckId}_$cardId';

  Future<void> _cacheProgress(
    String userId,
    String deckId,
    String cardId,
    FlashcardProgress prog,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(userId, deckId, cardId);
      final jsonStr = jsonEncode({
        'cardId': prog.cardId,
        'deckId': prog.deckId,
        'easeFactor': prog.easeFactor,
        'interval': prog.interval,
        'repetitions': prog.repetitions,
        'nextReviewDate': prog.nextReviewDate.toIso8601String(),
        'lastReviewDate': prog.lastReviewDate?.toIso8601String(),
        'quality': prog.quality,
      });
      await prefs.setString(key, jsonStr);
    } catch (_) {}
  }

  Future<Map<String, FlashcardProgress>> _getLocalCachedDeckProgress(
    String userId,
    String deckId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'fc_prog_${userId}_${deckId}_';
      final result = <String, FlashcardProgress>{};

      for (final key in prefs.getKeys()) {
        if (key.startsWith(prefix)) {
          final str = prefs.getString(key);
          if (str != null) {
            final data = jsonDecode(str) as Map<String, dynamic>;
            final prog = FlashcardProgress.fromMap(data);
            result[prog.cardId] = prog;
          }
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}
