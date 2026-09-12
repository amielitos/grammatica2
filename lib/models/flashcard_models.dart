import 'package:cloud_firestore/cloud_firestore.dart';
import 'notebook_models.dart';

/// A single flashcard within a deck.
class Flashcard {
  final String id;
  final String front;
  final String back;
  final String? hint;
  final List<String> tags;

  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
    this.tags = const [],
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String? ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      hint: json['hint'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        if (hint != null) 'hint': hint,
        'tags': tags,
      };

  Flashcard copyWith({
    String? id,
    String? front,
    String? back,
    String? hint,
    List<String>? tags,
  }) {
    return Flashcard(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      tags: tags ?? this.tags,
    );
  }
}

/// A collection of flashcards generated from notebook sources.
class FlashcardDeck {
  final String id;
  final String notebookId;
  final String title;
  final String description;
  final List<Flashcard> cards;
  final DateTime createdAt;

  const FlashcardDeck({
    required this.id,
    required this.notebookId,
    required this.title,
    this.description = '',
    required this.cards,
    required this.createdAt,
  });

  int get totalCards => cards.length;

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawCards = json['cards'] as List<dynamic>? ?? [];
    return FlashcardDeck(
      id: json['id'] as String? ?? '',
      notebookId: json['notebookId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Deck',
      description: json['description'] as String? ?? '',
      cards: rawCards
          .map((c) => Flashcard.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notebookId': notebookId,
        'title': title,
        'description': description,
        'cards': cards.map((c) => c.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  /// Converts this deck into a generic [NotebookOutput] suitable for Firestore persistence.
  NotebookOutput toNotebookOutput({
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.flashcards,
      title: title,
      data: toJson(),
      generatedAt: createdAt,
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
    );
  }

  factory FlashcardDeck.fromNotebookOutput(NotebookOutput output) {
    return FlashcardDeck.fromJson(output.data);
  }
}

/// Per-user review progress for an individual flashcard, using the SM-2 algorithm.
class FlashcardProgress {
  final String cardId;
  final String deckId;
  final double easeFactor; // Default 2.5
  final int interval; // Days until next review
  final int repetitions; // Successful repetitions in a row
  final DateTime nextReviewDate;
  final DateTime? lastReviewDate;
  final int quality; // Last review quality (0-5)

  const FlashcardProgress({
    required this.cardId,
    required this.deckId,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    required this.nextReviewDate,
    this.lastReviewDate,
    this.quality = 0,
  });

  bool get isDue => DateTime.now().isAfter(nextReviewDate);
  bool get isMastered => repetitions >= 4 && easeFactor >= 2.3;
  bool get isLearning => repetitions > 0 && !isMastered;
  bool get isNew => repetitions == 0;

  factory FlashcardProgress.initial({
    required String cardId,
    required String deckId,
  }) {
    return FlashcardProgress(
      cardId: cardId,
      deckId: deckId,
      easeFactor: 2.5,
      interval: 0,
      repetitions: 0,
      nextReviewDate: DateTime.now(),
      quality: 0,
    );
  }

  factory FlashcardProgress.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return FlashcardProgress(
      cardId: map['cardId'] as String? ?? '',
      deckId: map['deckId'] as String? ?? '',
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: (map['interval'] as num?)?.toInt() ?? 0,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      nextReviewDate: parseDate(map['nextReviewDate']),
      lastReviewDate: map['lastReviewDate'] != null
          ? parseDate(map['lastReviewDate'])
          : null,
      quality: (map['quality'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'cardId': cardId,
        'deckId': deckId,
        'easeFactor': easeFactor,
        'interval': interval,
        'repetitions': repetitions,
        'nextReviewDate': Timestamp.fromDate(nextReviewDate),
        if (lastReviewDate != null)
          'lastReviewDate': Timestamp.fromDate(lastReviewDate!),
        'quality': quality,
      };

  FlashcardProgress copyWith({
    String? cardId,
    String? deckId,
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    int? quality,
  }) {
    return FlashcardProgress(
      cardId: cardId ?? this.cardId,
      deckId: deckId ?? this.deckId,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      quality: quality ?? this.quality,
    );
  }
}

/// A log of a completed study session for analytics and streak calculation.
class StudySession {
  final String id;
  final String deckId;
  final String userId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int cardsStudied;
  final int cardsCorrect;
  final double averageQuality;

  const StudySession({
    required this.id,
    required this.deckId,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
    required this.cardsStudied,
    required this.cardsCorrect,
    required this.averageQuality,
  });

  Duration get duration => endedAt.difference(startedAt);

  factory StudySession.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return StudySession(
      id: id,
      deckId: map['deckId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      startedAt: parseDate(map['startedAt']),
      endedAt: parseDate(map['endedAt']),
      cardsStudied: (map['cardsStudied'] as num?)?.toInt() ?? 0,
      cardsCorrect: (map['cardsCorrect'] as num?)?.toInt() ?? 0,
      averageQuality: (map['averageQuality'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'deckId': deckId,
        'userId': userId,
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': Timestamp.fromDate(endedAt),
        'cardsStudied': cardsStudied,
        'cardsCorrect': cardsCorrect,
        'averageQuality': averageQuality,
      };
}
