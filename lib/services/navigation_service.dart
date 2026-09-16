import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/published_content_item.dart';
import '../pages/content_viewer_page.dart';
import '../pages/lesson_page.dart';
import '../pages/quiz_detail_page.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// Centralized navigation service for all learning content.
///
/// Ensures user identity continuity by always resolving [AuthService.liveUser]
/// at navigation time, preventing stale auth tokens and "temporary user" issues.
class NavigationService {
  static final NavigationService instance = NavigationService._();
  NavigationService._();

  /// Resolves the live, token-refreshed Firebase user.
  User get _liveUser => AuthService.liveUser;

  /// Navigate to a lesson with identity preservation.
  Future<void> goToLesson(
    BuildContext context,
    Lesson lesson, {
    bool replace = false,
    bool previewMode = false,
  }) async {
    final page = LessonPage(
      user: _liveUser,
      lesson: lesson,
      previewMode: previewMode,
    );

    if (replace) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  /// Navigate to a quiz with identity preservation and linked metadata.
  Future<void> goToQuiz(
    BuildContext context,
    Quiz quiz, {
    String? notebookId,
    Lesson? lesson,
    bool replace = false,
    bool previewMode = false,
  }) async {
    final page = QuizDetailPage(
      user: _liveUser,
      quiz: quiz,
      notebookId: notebookId ?? quiz.notebookId,
      lesson: lesson,
      previewMode: previewMode,
    );

    if (replace) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  /// Navigate to a published companion content item (flashcards, mind map, study guide, etc.)
  Future<void> goToContent(
    BuildContext context,
    PublishedContentItem item, {
    bool replace = false,
  }) async {
    final page = ContentViewerPage(
      user: _liveUser,
      item: item,
    );

    if (replace) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  /// Navigate to a companion item from within a linked bundle toolbar.
  /// Replaces the current content viewer while keeping the entry route (folder/home) in the stack.
  Future<void> switchBundleContent({
    required BuildContext context,
    Lesson? lesson,
    Quiz? quiz,
    PublishedContentItem? publishedItem,
    String? notebookId,
  }) async {
    if (lesson != null) {
      await goToLesson(context, lesson, replace: true);
    } else if (quiz != null) {
      await goToQuiz(context, quiz, notebookId: notebookId, lesson: lesson, replace: true);
    } else if (publishedItem != null) {
      await goToContent(context, publishedItem, replace: true);
    }
  }
}
