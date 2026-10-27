import 'package:cloud_firestore/cloud_firestore.dart';

enum SpellingDifficulty { novice, amateur, professional }

class SpellingWord {
  final String id;
  final String word;
  final String? description;
  final SpellingDifficulty difficulty;
  final Timestamp? createdAt;
  final String? createdByUid;
  final String? audioUrl;

  SpellingWord({
    required this.id,
    required this.word,
    this.description,
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
      description: data['description'] as String?,
      difficulty: _difficultyFromString(data['difficulty'] as String?),
      createdAt: data['createdAt'] as Timestamp?,
      createdByUid: data['createdByUid'] as String?,
      audioUrl: data['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      if (description != null) 'description': description,
      'difficulty': difficulty.name.toUpperCase(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'audioUrl': audioUrl,
    };
  }

  static SpellingDifficulty _difficultyFromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PROFESSIONAL':
      case 'ADVANCED':
        return SpellingDifficulty.professional;
      case 'AMATEUR':
      case 'INTERMEDIATE':
        return SpellingDifficulty.amateur;
      case 'NOVICE':
      case 'BEGINNER':
      default:
        return SpellingDifficulty.novice;
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case SpellingDifficulty.novice:
        return 'Beginner';
      case SpellingDifficulty.amateur:
        return 'Intermediate';
      case SpellingDifficulty.professional:
        return 'Advanced';
    }
  }
}
