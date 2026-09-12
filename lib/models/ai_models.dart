/// Dart domain models mirroring the Python Pydantic schemas in
/// `ai_backend/models/schemas.py`.
///
/// These represent the structured JSON that Gemini returns for
/// generated lessons and quizzes.
library;

import '../services/database_service.dart';
import 'notebook_models.dart';

// ---------------------------------------------------------------------------
// Content blocks
// ---------------------------------------------------------------------------

/// The type of a content block inside a lesson or quiz question.
enum ContentBlockType {
  text,
  image,
  table,
  list;

  factory ContentBlockType.fromString(String value) {
    switch (value) {
      case 'text':
        return ContentBlockType.text;
      case 'image':
        return ContentBlockType.image;
      case 'table':
        return ContentBlockType.table;
      case 'list':
        return ContentBlockType.list;
      default:
        return ContentBlockType.text;
    }
  }
}

/// A single content block.
///
/// Depending on [type]:
/// - **text** / **image**: [data] is a `String`
/// - **list**: [data] is a `List<String>`
/// - **table**: [data] is a `List<Map<String, dynamic>>` where each map is a
///   row and the keys are column headers.
class ContentBlock {
  final ContentBlockType type;
  final dynamic data;

  const ContentBlock({required this.type, required this.data});

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: ContentBlockType.fromString(json['type'] as String? ?? 'text'),
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'data': data,
      };
}

// ---------------------------------------------------------------------------
// Lesson
// ---------------------------------------------------------------------------

class AILessonResponse {
  final String title;
  final List<ContentBlock> content;

  const AILessonResponse({required this.title, required this.content});

  factory AILessonResponse.fromJson(Map<String, dynamic> json) {
    final blocks = (json['content'] as List<dynamic>?)
            ?.map((b) => ContentBlock.fromJson(Map<String, dynamic>.from(b)))
            .toList() ??
        [];
    return AILessonResponse(
      title: json['title'] as String? ?? 'Untitled Lesson',
      content: blocks,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content.map((b) => b.toJson()).toList(),
      };

  NotebookOutput toNotebookOutput({
    required String id,
    required String notebookId,
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
    String? publishedId,
    String? publishedCollection,
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.lesson,
      title: title,
      data: toJson(),
      generatedAt: DateTime.now(),
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
      publishedId: publishedId,
      publishedCollection: publishedCollection,
    );
  }

  factory AILessonResponse.fromNotebookOutput(NotebookOutput output) {
    return AILessonResponse.fromJson(output.data);
  }

  /// Converts all structured content blocks into markdown for saving to the Lesson prompt.
  String toMarkdownContent() {
    final buffer = StringBuffer();
    for (final b in content) {
      switch (b.type) {
        case ContentBlockType.text:
          buffer.writeln(b.data.toString());
          buffer.writeln();
          break;
        case ContentBlockType.list:
          if (b.data is List) {
            for (final item in b.data as List) {
              buffer.writeln('• $item');
            }
          } else {
            buffer.writeln(b.data.toString());
          }
          buffer.writeln();
          break;
        case ContentBlockType.table:
          if (b.data is List && (b.data as List).isNotEmpty) {
            final rows = b.data as List;
            final headers = (rows.first as Map<String, dynamic>).keys.toList();
            buffer.writeln('| ${headers.join(' | ')} |');
            buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');
            for (final row in rows) {
              final r = row as Map<String, dynamic>;
              buffer.writeln('| ${headers.map((h) => r[h]?.toString() ?? '').join(' | ')} |');
            }
          }
          buffer.writeln();
          break;
        case ContentBlockType.image:
          buffer.writeln('[Image Placeholder: ${b.data}]');
          buffer.writeln();
          break;
      }
    }
    return buffer.toString().trim();
  }
}

// ---------------------------------------------------------------------------
// Quiz
// ---------------------------------------------------------------------------

enum QuizQuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  fillInTheBlank,
  matching,
  passage;

  factory QuizQuestionType.fromString(String value) {
    switch (value) {
      case 'multiple_choice':
        return QuizQuestionType.multipleChoice;
      case 'true_false':
        return QuizQuestionType.trueFalse;
      case 'short_answer':
        return QuizQuestionType.shortAnswer;
      case 'fill_in_the_blank':
        return QuizQuestionType.fillInTheBlank;
      case 'matching':
        return QuizQuestionType.matching;
      case 'passage':
        return QuizQuestionType.passage;
      default:
        return QuizQuestionType.multipleChoice;
    }
  }

  String toJsonString() {
    switch (this) {
      case QuizQuestionType.multipleChoice:
        return 'multiple_choice';
      case QuizQuestionType.trueFalse:
        return 'true_false';
      case QuizQuestionType.shortAnswer:
        return 'short_answer';
      case QuizQuestionType.fillInTheBlank:
        return 'fill_in_the_blank';
      case QuizQuestionType.matching:
        return 'matching';
      case QuizQuestionType.passage:
        return 'passage';
    }
  }
}

class AIQuizQuestion {
  final QuizQuestionType questionType;
  final List<ContentBlock> content;
  final List<String> options;
  final String correctAnswer;
  final String? hint;
  final String? explanation;

  const AIQuizQuestion({
    required this.questionType,
    required this.content,
    required this.options,
    required this.correctAnswer,
    this.hint,
    this.explanation,
  });

  factory AIQuizQuestion.fromJson(Map<String, dynamic> json) {
    // Build content blocks from the structured 'content' array (preferred format).
    var blocks = (json['content'] as List<dynamic>?)
            ?.map((b) => ContentBlock.fromJson(Map<String, dynamic>.from(b)))
            .toList() ??
        [];

    // Fallback: Gemini sometimes returns a plain 'question' string instead of
    // the structured 'content' array. Wrap it in a text block so the UI renders correctly.
    if (blocks.isEmpty) {
      final questionStr = json['question'] as String?;
      if (questionStr != null && questionStr.isNotEmpty) {
        blocks = [ContentBlock(type: ContentBlockType.text, data: questionStr)];
      }
    }

    final options = (json['options'] as List<dynamic>?)
            ?.map((o) => o.toString())
            .toList() ??
        [];
    return AIQuizQuestion(
      questionType: QuizQuestionType.fromString(
          json['questionType'] as String? ?? 'multiple_choice'),
      content: blocks,
      options: options,
      correctAnswer: json['correctAnswer'] as String? ?? '',
      hint: json['hint'] as String?,
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'questionType': questionType.toJsonString(),
        'content': content.map((b) => b.toJson()).toList(),
        'options': options,
        'correctAnswer': correctAnswer,
        if (hint != null) 'hint': hint,
        if (explanation != null) 'explanation': explanation,
      };
}

class AIQuizResponse {
  final String? title;
  final String? description;
  final List<AIQuizQuestion> questions;
  final int? durationMinutes;
  final bool isAssessment;

  const AIQuizResponse({
    this.title,
    this.description,
    required this.questions,
    this.durationMinutes,
    this.isAssessment = false,
  });

  factory AIQuizResponse.fromJson(Map<String, dynamic> json) {
    final qs = (json['questions'] as List<dynamic>?)
            ?.map((q) => AIQuizQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList() ??
        [];
    return AIQuizResponse(
      title: json['title'] as String?,
      description: json['description'] as String?,
      questions: qs,
      durationMinutes: json['durationMinutes'] as int?,
      isAssessment: json['isAssessment'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        'questions': questions.map((q) => q.toJson()).toList(),
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'isAssessment': isAssessment,
      };

  NotebookOutput toNotebookOutput({
    required String id,
    required String notebookId,
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
    String? publishedId,
    String? publishedCollection,
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.quiz,
      title: title ?? 'Generated Quiz',
      data: toJson(),
      generatedAt: DateTime.now(),
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
      publishedId: publishedId,
      publishedCollection: publishedCollection,
    );
  }

  factory AIQuizResponse.fromNotebookOutput(NotebookOutput output) {
    return AIQuizResponse.fromJson(output.data);
  }

  /// Maps AI quiz questions into native DatabaseService QuizQuestion objects.
  List<QuizQuestion> toQuizQuestions() {
    return questions.map((q) {
      final qText = q.content
          .where((b) => b.type == ContentBlockType.text)
          .map((b) => b.data.toString())
          .join('\n');
      return QuizQuestion(
        question: qText.isEmpty ? 'Question' : qText,
        answer: q.correctAnswer,
        type: q.questionType.toJsonString(),
        options: q.options.isNotEmpty ? q.options : null,
        hint: q.hint,
        explanation: q.explanation,
      );
    }).toList();
  }
}
