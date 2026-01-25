import 'package:cloud_firestore/cloud_firestore.dart';

enum SpellingDifficulty { novice, amateur, professional }

class SpellingWord {
  final String id;
  final String word;
  final SpellingDifficulty difficulty;
  final Timestamp? createdAt;
  final String? createdByUid;
  final String? audioUrl;

  SpellingWord({
    required this.id,
    required this.word,
    required this.difficulty,
    this.createdAt,
    this.createdByUid,
    this.audioUrl,
  });

  factory SpellingWord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SpellingWord(
      id: doc.id,
      word: (data['word'] ?? '').toString(),
      difficulty: _difficultyFromString(data['difficulty'] as String?),
      createdAt: data['createdAt'] as Timestamp?,
      createdByUid: data['createdByUid'] as String?,
      audioUrl: data['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'difficulty': difficulty.name.toUpperCase(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'audioUrl': audioUrl,
    };
  }

  static SpellingDifficulty _difficultyFromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PROFESSIONAL':
        return SpellingDifficulty.professional;
      case 'AMATEUR':
        return SpellingDifficulty.amateur;
      case 'NOVICE':
      default:
        return SpellingDifficulty.novice;
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case SpellingDifficulty.novice:
        return 'Novice';
      case SpellingDifficulty.amateur:
        return 'Amateur';
      case SpellingDifficulty.professional:
        return 'Professional';
    }
  }
}
