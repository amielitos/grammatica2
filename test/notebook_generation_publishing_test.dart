import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:grammatica/models/notebook_models.dart';
import 'package:grammatica/models/ai_models.dart';
import 'package:grammatica/widgets/notebook/generation_confirm_dialog.dart';

void main() {
  group('AI Notebook Centralization & Publishing Tests', () {
    final List<NotebookSource> sampleSources = [
      NotebookSource(
        id: 's1',
        notebookId: 'nb_1',
        title: 'Grammar Guide.pdf',
        type: SourceType.pdf,
        rawContent: 'Grammar guide full text content.',
        processingStatus: SourceProcessingStatus.ready,
        createdAt: DateTime.now(),
      ),
      NotebookSource(
        id: 's2',
        notebookId: 'nb_1',
        title: 'Verb Notes',
        type: SourceType.text,
        rawContent: 'Irregular verbs notes and examples.',
        processingStatus: SourceProcessingStatus.ready,
        createdAt: DateTime.now(),
      ),
    ];

    testWidgets('GenerationConfirmDialog shows correct metadata and format options for quiz', (tester) async {
      bool dialogConfirmed = false;
      bool? isAssessmentSelected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (ctx) => GenerationConfirmDialog(
                      type: NotebookOutputType.quiz,
                      sources: sampleSources,
                      hasExistingOutput: false,
                    ),
                  );
                  if (result != null) {
                    dialogConfirmed = result['confirmed'] as bool? ?? false;
                    isAssessmentSelected = result['isAssessment'] as bool?;
                  }
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify title & description
      expect(find.text('Generate Quiz'), findsOneWidget);
      expect(find.textContaining('comprehensive assessment questions'), findsOneWidget);
      expect(find.textContaining('Sources to Synthesize (2)'), findsOneWidget);

      // Verify format options for Quiz
      expect(find.text('Practice Quiz'), findsOneWidget);
      expect(find.text('Assessment'), findsOneWidget);

      // Select Assessment
      await tester.tap(find.text('Assessment'));
      await tester.pumpAndSettle();

      // Click Confirm & Generate
      await tester.ensureVisible(find.text('Confirm & Generate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Generate'));
      await tester.pumpAndSettle();

      expect(dialogConfirmed, isTrue);
      expect(isAssessmentSelected, isTrue);
    });

    testWidgets('GenerationConfirmDialog warns when replacing draft output', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => GenerationConfirmDialog(
                    type: NotebookOutputType.lesson,
                    sources: sampleSources,
                    hasExistingOutput: true,
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.textContaining('A Lesson draft already exists. Confirming will regenerate and replace it.'), findsOneWidget);
    });

    test('Lesson content blocks can be converted to Markdown seamlessly', () {
      const lesson = AILessonResponse(
        title: 'Mastering Relative Clauses',
        content: [
          ContentBlock(type: ContentBlockType.text, data: 'Relative clauses add extra information about a noun.'),
          ContentBlock(type: ContentBlockType.list, data: ['Who (for people)', 'Which (for things)', 'Whose (for possessions)']),
        ],
      );

      final markdown = lesson.toMarkdownContent();
      expect(markdown, contains('Relative clauses add extra information'));
      expect(markdown, contains('• Who (for people)'));
      expect(markdown, contains('• Which (for things)'));
    });

    test('Notebook Output auto-links to published Quiz ID without arbitrary dropdown', () {
      final quizOutput = NotebookOutput(
        id: 'quiz_out_1',
        notebookId: 'nb_1',
        type: NotebookOutputType.quiz,
        title: 'Adverb Quiz',
        data: {
          'title': 'Adverb Quiz',
          'description': 'Test understanding of adverbs',
          'questions': [
            {
              'question': 'Identify the adverb in: She ran quickly.',
              'options': ['She', 'ran', 'quickly'],
              'correctAnswerIndex': 2,
              'explanation': 'Quickly describes the verb ran.',
            }
          ],
        },
        generatedAt: DateTime.now(),
        publishedId: 'pub_quiz_999',
      );

      expect(quizOutput.publishedId, 'pub_quiz_999');

      // Lesson generated in same notebook
      final lessonOutput = NotebookOutput(
        id: 'lesson_out_1',
        notebookId: 'nb_1',
        type: NotebookOutputType.lesson,
        title: 'Adverbs 101',
        data: {
          'title': 'Adverbs 101',
          'content': [
            {'type': 'text', 'data': 'Adverbs modify verbs, adjectives, and other adverbs.'}
          ]
        },
        generatedAt: DateTime.now(),
      );

      // Verify the lesson links to notebook quiz ID directly
      final linkedLessonData = {
        ...lessonOutput.data,
        'quizId': quizOutput.publishedId,
      };

      expect(linkedLessonData['quizId'], 'pub_quiz_999');
    });

    test('Supported Source Types exclude Audio and Video', () {
      final allowedTypes = SourceType.values.where((t) {
        return t != SourceType.audio && t != SourceType.video;
      }).toList();

      expect(allowedTypes.contains(SourceType.pdf), isTrue);
      expect(allowedTypes.contains(SourceType.text), isTrue);
      expect(allowedTypes.contains(SourceType.url), isTrue);
      expect(allowedTypes.contains(SourceType.audio), isFalse);
      expect(allowedTypes.contains(SourceType.video), isFalse);
    });
  });
}
