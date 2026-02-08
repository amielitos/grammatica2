import 'dart:math';
import 'package:english_words/english_words.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spelling_word.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  static AIService get instance => _instance;
  AIService._internal();

  Future<List<SpellingWord>> generateWords({
    required int count,
    required SpellingDifficulty difficulty,
    String? topic, // Ignored for local generation
  }) async {
    // 1. Get all nouns from english_words
    // 2. Filter by difficulty (length)
    // 3. Shuffle and take 'count'

    final random = Random();
    List<String> candidates = nouns;

    // Filter based on difficulty (approximate mapping)
    switch (difficulty) {
      case SpellingDifficulty.novice:
        // Short words: 3-4 letters
        candidates = candidates
            .where((w) => w.length >= 3 && w.length <= 4)
            .toList();
        break;
      case SpellingDifficulty.amateur:
        // Medium words: 5-7 letters
        candidates = candidates
            .where((w) => w.length >= 5 && w.length <= 7)
            .toList();
        break;
      case SpellingDifficulty.professional:
        // Long words: 8+ letters
        candidates = candidates.where((w) => w.length >= 8).toList();
        break;
    }

    if (candidates.isEmpty) {
      // Fallback if strict filtering fails (shouldn't happen with standard dict)
      candidates = nouns;
    }

    // Shuffle to get random words
    candidates.shuffle(random);
    final selectedWords = candidates.take(count).toList();

    return selectedWords.map((word) {
      return SpellingWord(
        id:
            DateTime.now().microsecondsSinceEpoch.toString() +
            random.nextInt(1000).toString(),
        word: word, // english_words are usually lowercase
        difficulty: difficulty,
        createdAt: Timestamp.now(),
        createdByUid: 'auto_generated',
        audioUrl: null,
      );
    }).toList();
  }
}
