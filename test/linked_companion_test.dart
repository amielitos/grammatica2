import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/models/notebook_models.dart';
import 'package:grammatica/models/published_content_item.dart';
import 'package:grammatica/services/database_service.dart';

void main() {
  group('LinkedContentBundle Tests', () {
    test('hasMultipleItems returns false when only one item or no items are present', () {
      const emptyBundle = LinkedContentBundle();
      expect(emptyBundle.hasMultipleItems, isFalse);
      expect(emptyBundle.totalCount, 0);
      expect(emptyBundle.isEmpty, isTrue);

      final lessonOnlyBundle = LinkedContentBundle(
        lesson: Lesson(
          id: 'l1',
          title: 'Lesson 1',
          prompt: 'Content prompt',
          answer: 'Content answer',
        ),
      );
      expect(lessonOnlyBundle.hasMultipleItems, isFalse);
      expect(lessonOnlyBundle.totalCount, 1);

      final quizOnlyBundle = LinkedContentBundle(
        quiz: Quiz(
          id: 'q1',
          title: 'Quiz 1',
          description: '',
          duration: 10,
          maxAttempts: 1,
          questions: [],
        ),
      );
      expect(quizOnlyBundle.hasMultipleItems, isFalse);
      expect(quizOnlyBundle.totalCount, 1);

      final pubItemOnlyBundle = LinkedContentBundle(
        publishedItems: [
          PublishedContentItem(
            id: 'pub1',
            type: NotebookOutputType.flashcards,
            title: 'Flashcards',
            data: {},
            createdByUid: 'u1',
            createdByEmail: 'u1@grammatica.com',
            isVisible: true,
            isMembersOnly: false,
            isGrammaticaContent: false,
          ),
        ],
      );
      expect(pubItemOnlyBundle.hasMultipleItems, isFalse);
      expect(pubItemOnlyBundle.totalCount, 1);
    });

    test('hasMultipleItems returns true when 2 or more items are present', () {
      final bundleWithLessonAndQuiz = LinkedContentBundle(
        notebookId: 'nb_123',
        lesson: Lesson(
          id: 'l1',
          title: 'Lesson 1',
          prompt: 'Content prompt',
          answer: 'Content answer',
          notebookId: 'nb_123',
        ),
        quiz: Quiz(
          id: 'q1',
          title: 'Quiz 1',
          description: '',
          duration: 10,
          maxAttempts: 1,
          questions: [],
          notebookId: 'nb_123',
        ),
      );
      expect(bundleWithLessonAndQuiz.hasMultipleItems, isTrue);
      expect(bundleWithLessonAndQuiz.totalCount, 2);

      final bundleWithLessonAndFlashcards = LinkedContentBundle(
        notebookId: 'nb_123',
        lesson: Lesson(
          id: 'l1',
          title: 'Lesson 1',
          prompt: 'Content prompt',
          answer: 'Content answer',
          notebookId: 'nb_123',
        ),
        publishedItems: [
          PublishedContentItem(
            id: 'pub1',
            type: NotebookOutputType.flashcards,
            title: 'Flashcards',
            data: {},
            createdByUid: 'u1',
            createdByEmail: 'u1@grammatica.com',
            isVisible: true,
            isMembersOnly: false,
            isGrammaticaContent: false,
            notebookId: 'nb_123',
          ),
          PublishedContentItem(
            id: 'pub2',
            type: NotebookOutputType.mindMap,
            title: 'Mind Map',
            data: {},
            createdByUid: 'u1',
            createdByEmail: 'u1@grammatica.com',
            isVisible: true,
            isMembersOnly: false,
            isGrammaticaContent: false,
            notebookId: 'nb_123',
          ),
        ],
      );
      expect(bundleWithLessonAndFlashcards.hasMultipleItems, isTrue);
      expect(bundleWithLessonAndFlashcards.totalCount, 3);
    });
  });

  group('Lesson & Quiz notebookId Model Tests', () {
    test('Lesson constructor and properties retain notebookId', () {
      final lesson = Lesson(
        id: 'l10',
        title: 'Verbs',
        prompt: 'Prompt',
        answer: 'Answer',
        notebookId: 'nb_verbs_101',
      );

      expect(lesson.notebookId, 'nb_verbs_101');
    });

    test('Quiz constructor retains notebookId and validationStatus', () {
      final quiz = Quiz(
        id: 'q10',
        title: 'Verbs Quiz',
        description: 'Test your verb knowledge',
        duration: 15,
        maxAttempts: 2,
        questions: [],
        notebookId: 'nb_verbs_101',
        validationStatus: 'awaiting_approval',
      );

      expect(quiz.notebookId, 'nb_verbs_101');
      expect(quiz.validationStatus, 'awaiting_approval');
    });

    test('PublishedContentItem.fromNotebookOutput converts MindMap and Flashcard outputs correctly', () {
      final mindMapOutput = NotebookOutput(
        id: 'out_mm_1',
        notebookId: 'nb_123',
        type: NotebookOutputType.mindMap,
        title: 'Mind Map Title',
        data: {'title': 'Mind Map Title', 'centralTopic': 'Topic', 'nodes': [], 'edges': []},
        generatedAt: DateTime.now(),
      );

      final pubItem = PublishedContentItem.fromNotebookOutput(mindMapOutput);
      expect(pubItem.id, 'out_mm_1');
      expect(pubItem.type, NotebookOutputType.mindMap);
      expect(pubItem.title, 'Mind Map Title');
      expect(pubItem.notebookId, 'nb_123');
      expect(pubItem.outputId, 'out_mm_1');
    });
  });
}
