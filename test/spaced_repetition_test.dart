import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/models/flashcard_models.dart';
import 'package:grammatica/services/spaced_repetition_service.dart';

void main() {
  group('SM-2 Algorithm Logic', () {
    test('Initial progress state starts with defaults', () {
      final initial = FlashcardProgress.initial(cardId: 'c1', deckId: 'd1');
      expect(initial.cardId, 'c1');
      expect(initial.deckId, 'd1');
      expect(initial.easeFactor, 2.5);
      expect(initial.repetitions, 0);
      expect(initial.interval, 0);
      expect(initial.isNew, isTrue);
      expect(initial.isMastered, isFalse);
    });

    test('Flashcard deck JSON serialization and deserialization roundtrip', () {
      final now = DateTime.now();
      final deck = FlashcardDeck(
        id: 'deck_test',
        notebookId: 'nb_1',
        title: 'Cell Biology',
        description: 'Mitochondria and organelles',
        cards: const [
          Flashcard(
            id: 'c1',
            front: 'What is the powerhouse of the cell?',
            back: 'Mitochondria',
            hint: 'Generates ATP',
            tags: ['Biology', 'Organelles'],
          ),
        ],
        createdAt: now,
      );

      final json = deck.toJson();
      final roundtrip = FlashcardDeck.fromJson(json);

      expect(roundtrip.id, 'deck_test');
      expect(roundtrip.notebookId, 'nb_1');
      expect(roundtrip.title, 'Cell Biology');
      expect(roundtrip.totalCards, 1);
      expect(roundtrip.cards.first.front, 'What is the powerhouse of the cell?');
      expect(roundtrip.cards.first.back, 'Mitochondria');
      expect(roundtrip.cards.first.hint, 'Generates ATP');
      expect(roundtrip.cards.first.tags, ['Biology', 'Organelles']);
    });

    test('Converts deck to NotebookOutput and back seamlessly', () {
      final deck = FlashcardDeck(
        id: 'deck_output_test',
        notebookId: 'nb_2',
        title: 'Vocabulary Deck',
        cards: const [
          Flashcard(id: 'c1', front: 'Serendipity', back: 'A pleasant surprise'),
        ],
        createdAt: DateTime.now(),
      );

      final output = deck.toNotebookOutput(
        sourceIds: ['s1', 's2'],
        isShared: true,
        sharedTo: ['all_subscribers'],
      );

      expect(output.id, 'deck_output_test');
      expect(output.notebookId, 'nb_2');
      expect(output.isShared, isTrue);
      expect(output.sharedTo, ['all_subscribers']);
      expect(output.sourceIds, ['s1', 's2']);

      final restoredDeck = FlashcardDeck.fromNotebookOutput(output);
      expect(restoredDeck.id, 'deck_output_test');
      expect(restoredDeck.cards.length, 1);
      expect(restoredDeck.cards.first.front, 'Serendipity');
    });

    test('SM-2 interval and ease factor sequence over consecutive sessions', () {
      final t0 = DateTime(2026, 1, 1, 10);

      // Repetition 1: Quality 4 (Good)
      final r1 = SpacedRepetitionService.computeNextProgress(
        cardId: 'c1',
        deckId: 'd1',
        quality: 4,
        currentProgress: null,
        now: t0,
      );
      expect(r1.repetitions, 1);
      expect(r1.interval, 1);
      expect(r1.nextReviewDate, t0.add(const Duration(days: 1)));
      expect(r1.easeFactor, 2.5); // 2.5 + (0.1 - 1 * (0.08 + 0.02)) = 2.5

      // Repetition 2: Quality 4 (Good)
      final t1 = t0.add(const Duration(days: 1));
      final r2 = SpacedRepetitionService.computeNextProgress(
        cardId: 'c1',
        deckId: 'd1',
        quality: 4,
        currentProgress: r1,
        now: t1,
      );
      expect(r2.repetitions, 2);
      expect(r2.interval, 6);
      expect(r2.nextReviewDate, t1.add(const Duration(days: 6)));
      expect(r2.easeFactor, 2.5);

      // Repetition 3: Quality 5 (Easy)
      final t2 = t1.add(const Duration(days: 6));
      final r3 = SpacedRepetitionService.computeNextProgress(
        cardId: 'c1',
        deckId: 'd1',
        quality: 5,
        currentProgress: r2,
        now: t2,
      );
      expect(r3.repetitions, 3);
      expect(r3.interval, (6 * 2.5).round()); // 15
      expect(r3.nextReviewDate, t2.add(const Duration(days: 15)));
      expect(r3.easeFactor, 2.6); // 2.5 + (0.1 - 0) = 2.6

      // Failure: Quality 1 (Again) -> Resets reps to 0 and interval to 1
      final t3 = t2.add(const Duration(days: 15));
      final r4 = SpacedRepetitionService.computeNextProgress(
        cardId: 'c1',
        deckId: 'd1',
        quality: 1,
        currentProgress: r3,
        now: t3,
      );
      expect(r4.repetitions, 0);
      expect(r4.interval, 1);
      expect(r4.nextReviewDate, t3.add(const Duration(days: 1)));
    });
  });
}
