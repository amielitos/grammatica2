import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_visibility.dart';
import '../models/notebook_models.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'role_service.dart';

/// Central service managing Notebooks, multi-format sources, and AI outputs.
///
/// **Session-First Architecture:**
/// Notebooks, sources, and draft outputs are stored locally on a session
/// (in-memory with SharedPreferences persistence), ensuring fast, private,
/// zero-cost drafting.
///
/// Content is **ONLY uploaded to Firestore when the educator clicks "Publish to Curriculum"**
/// (or shares flashcard decks with students).
class NotebookService {
  NotebookService._() {
    _loadFromLocalSession();
  }
  static final NotebookService instance = NotebookService._();
  factory NotebookService() => instance;

  static const String _prefKeyNotebooks = 'grammatica_session_notebooks';
  static const String _prefKeySources = 'grammatica_session_sources';
  static const String _prefKeyOutputs = 'grammatica_session_outputs';

  // In-memory local session state
  final Map<String, Notebook> _localNotebooks = {};
  final Map<String, List<NotebookSource>> _localSources = {};
  final Map<String, List<NotebookOutput>> _localOutputs = {};
  bool _isLoaded = false;

  // Reactive Stream Controllers for Local Session State
  final StreamController<List<Notebook>> _notebooksController =
      StreamController<List<Notebook>>.broadcast();
  final Map<String, StreamController<Notebook?>> _notebookControllers = {};
  final Map<String, StreamController<List<NotebookSource>>> _sourcesControllers =
      {};
  final Map<String, StreamController<List<NotebookOutput>>> _outputsControllers =
      {};


  // ---------------------------------------------------------------------------
  // Local Session Persistence (SharedPreferences)
  // ---------------------------------------------------------------------------

  Future<void> _loadFromLocalSession() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Notebooks
      final nbString = prefs.getString(_prefKeyNotebooks);
      if (nbString != null && nbString.isNotEmpty) {
        final List<dynamic> list = jsonDecode(nbString);
        for (final item in list) {
          final map = Map<String, dynamic>.from(item as Map);
          final nb = Notebook.fromMap(map['id'] as String? ?? '', map);
          _localNotebooks[nb.id] = nb;
        }
      }

      // Load Sources
      final srcString = prefs.getString(_prefKeySources);
      if (srcString != null && srcString.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(srcString);
        map.forEach((nbId, sourcesList) {
          _localSources[nbId] = (sourcesList as List<dynamic>)
              .map((s) => NotebookSource.fromMap(
                    (s as Map)['id'] as String? ?? '',
                    Map<String, dynamic>.from(s),
                  ))
              .toList();
        });
      }

      // Load Outputs
      final outString = prefs.getString(_prefKeyOutputs);
      if (outString != null && outString.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(outString);
        map.forEach((nbId, outputsList) {
          _localOutputs[nbId] = (outputsList as List<dynamic>)
              .map((o) => NotebookOutput.fromMap(
                    (o as Map)['id'] as String? ?? '',
                    Map<String, dynamic>.from(o),
                  ))
              .toList();
        });
      }

      _isLoaded = true;
      _emitAllUpdates();
    } catch (e) {
      debugPrint('Error loading local notebook session: $e');
    }
  }

  Future<void> _saveToLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save Notebooks
      final nbList = _localNotebooks.values.map((n) => n.toJsonMap()).toList();
      await prefs.setString(_prefKeyNotebooks, jsonEncode(nbList));

      // Save Sources
      final srcMap = <String, dynamic>{};
      _localSources.forEach((nbId, list) {
        srcMap[nbId] = list.map((s) => s.toJsonMap()).toList();
      });
      await prefs.setString(_prefKeySources, jsonEncode(srcMap));

      // Save Outputs
      final outMap = <String, dynamic>{};
      _localOutputs.forEach((nbId, list) {
        outMap[nbId] = list.map((o) => o.toJsonMap()).toList();
      });
      await prefs.setString(_prefKeyOutputs, jsonEncode(outMap));
    } catch (e) {
      debugPrint('Error saving local notebook session: $e');
    }
  }

  void _emitAllUpdates() {
    _notebooksController.add(_localNotebooks.values.toList());
    _notebookControllers.forEach((id, ctrl) {
      if (!ctrl.isClosed) ctrl.add(_localNotebooks[id]);
    });
    _sourcesControllers.forEach((id, ctrl) {
      if (!ctrl.isClosed) ctrl.add(List.unmodifiable(_localSources[id] ?? []));
    });
    _outputsControllers.forEach((id, ctrl) {
      if (!ctrl.isClosed) ctrl.add(List.unmodifiable(_localOutputs[id] ?? []));
    });
  }

  void _emitNotebookUpdate(String id) {
    if (_notebookControllers.containsKey(id) &&
        !_notebookControllers[id]!.isClosed) {
      _notebookControllers[id]!.add(_localNotebooks[id]);
    }
    _notebooksController.add(_localNotebooks.values.toList());
  }

  void _emitSourcesUpdate(String id) {
    if (_sourcesControllers.containsKey(id) &&
        !_sourcesControllers[id]!.isClosed) {
      _sourcesControllers[id]!.add(List.unmodifiable(_localSources[id] ?? []));
    }
  }

  void _emitOutputsUpdate(String id) {
    if (_outputsControllers.containsKey(id) &&
        !_outputsControllers[id]!.isClosed) {
      _outputsControllers[id]!.add(List.unmodifiable(_localOutputs[id] ?? []));
    }
  }

  // ---------------------------------------------------------------------------
  // Notebook CRUD Operations (Local Session)
  // ---------------------------------------------------------------------------

  /// Creates a new notebook stored locally in the session.
  Future<Notebook> createNotebook({
    required String title,
    String description = '',
    required String createdBy,
    String? coverImageUrl,
    List<String> tags = const [],
  }) async {
    await _loadFromLocalSession();
    final now = DateTime.now();
    final id = 'nb_${now.millisecondsSinceEpoch}';

    final notebook = Notebook(
      id: id,
      title: title.trim(),
      description: description.trim(),
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      sourceIds: const [],
      outputIds: const [],
      coverImageUrl: coverImageUrl,
      tags: tags,
    );

    _localNotebooks[id] = notebook;
    _localSources[id] = [];
    _localOutputs[id] = [];

    await _saveToLocalSession();
    _emitNotebookUpdate(id);
    return notebook;
  }

  /// Updates a notebook's top-level metadata in the local session.
  Future<void> updateNotebook(Notebook notebook) async {
    await _loadFromLocalSession();
    final updated = notebook.copyWith(updatedAt: DateTime.now());
    _localNotebooks[notebook.id] = updated;
    await _saveToLocalSession();
    _emitNotebookUpdate(notebook.id);
  }

  /// Deletes a notebook and its nested local session data.
  Future<void> deleteNotebook(String notebookId) async {
    await _loadFromLocalSession();
    _localNotebooks.remove(notebookId);
    _localSources.remove(notebookId);
    _localOutputs.remove(notebookId);

    await _saveToLocalSession();
    _emitNotebookUpdate(notebookId);
  }

  /// Fetches a notebook by ID synchronously if loaded, or async.
  Future<Notebook?> getNotebook(String notebookId) async {
    await _loadFromLocalSession();
    return _localNotebooks[notebookId];
  }

  /// Synchronous getter for all local notebooks for dialogs and pickers.
  List<Notebook> getLocalNotebooks(String userId) {
    return _localNotebooks.values
        .where((n) => n.createdBy == userId || userId.isEmpty)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Synchronous getter for outputs of a notebook.
  List<NotebookOutput> getOutputsForNotebook(String notebookId) {
    return List.unmodifiable(_localOutputs[notebookId] ?? []);
  }

  /// Finds the notebookId for a published lesson if one exists in local session.
  String? findNotebookIdForLesson(String lessonId) {
    for (final entry in _localOutputs.entries) {
      if (entry.value.any((o) => o.publishedId == lessonId || o.id == lessonId)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Streams a single notebook from local session.
  Stream<Notebook?> streamNotebook(String notebookId) {
    _loadFromLocalSession();
    if (!_notebookControllers.containsKey(notebookId) ||
        _notebookControllers[notebookId]!.isClosed) {
      _notebookControllers[notebookId] =
          StreamController<Notebook?>.broadcast();
    }
    // Seed current value
    Timer.run(() {
      if (_notebookControllers.containsKey(notebookId) &&
          !_notebookControllers[notebookId]!.isClosed) {
        _notebookControllers[notebookId]!.add(_localNotebooks[notebookId]);
      }
    });
    return _notebookControllers[notebookId]!.stream;
  }

  /// Streams all notebooks for the user from local session.
  Stream<List<Notebook>> listUserNotebooks(String userId) {
    _loadFromLocalSession();
    // Seed current value
    Timer.run(() {
      final list = _localNotebooks.values
          .where((n) => n.createdBy == userId || userId.isEmpty)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _notebooksController.add(list);
    });
    return _notebooksController.stream.map((list) {
      return list
          .where((n) => n.createdBy == userId || userId.isEmpty)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  /// Convenience stream of notebooks for pickers and dialogs.
  Stream<List<Notebook>> getNotebooks([String userId = '']) => listUserNotebooks(userId);

  /// Convenience stream of outputs for pickers and dialogs.
  Stream<List<NotebookOutput>> getOutputs(String notebookId) => streamOutputs(notebookId);

  // ---------------------------------------------------------------------------
  // Source Operations (Local Session)
  // ---------------------------------------------------------------------------

  /// Adds a source document to the notebook's local session.
  Future<void> addSource(String notebookId, NotebookSource source) async {
    await _loadFromLocalSession();
    final finalId = source.id.isNotEmpty
        ? source.id
        : 'src_${DateTime.now().millisecondsSinceEpoch}';
    final finalSource = source.copyWith(id: finalId);

    final list = _localSources[notebookId] ?? [];
    list.removeWhere((s) => s.id == finalId);
    list.add(finalSource);
    _localSources[notebookId] = list;

    // Update parent notebook sourceIds
    final nb = _localNotebooks[notebookId];
    if (nb != null) {
      final sIds = List<String>.from(nb.sourceIds);
      if (!sIds.contains(finalId)) sIds.add(finalId);
      _localNotebooks[notebookId] = nb.copyWith(
        sourceIds: sIds,
        updatedAt: DateTime.now(),
      );
      _emitNotebookUpdate(notebookId);
    }

    await _saveToLocalSession();
    _emitSourcesUpdate(notebookId);
  }

  /// Updates an existing source in local session.
  Future<void> updateSource(String notebookId, NotebookSource source) async {
    await _loadFromLocalSession();
    final list = _localSources[notebookId] ?? [];
    final idx = list.indexWhere((s) => s.id == source.id);
    if (idx != -1) {
      list[idx] = source;
      _localSources[notebookId] = list;
      await _saveToLocalSession();
      _emitSourcesUpdate(notebookId);
    }
  }

  /// Deletes a source from the local session.
  Future<void> deleteSource(String notebookId, String sourceId) async {
    await _loadFromLocalSession();
    final list = _localSources[notebookId] ?? [];
    list.removeWhere((s) => s.id == sourceId);
    _localSources[notebookId] = list;

    final nb = _localNotebooks[notebookId];
    if (nb != null) {
      final sIds = List<String>.from(nb.sourceIds)..remove(sourceId);
      _localNotebooks[notebookId] = nb.copyWith(
        sourceIds: sIds,
        updatedAt: DateTime.now(),
      );
      _emitNotebookUpdate(notebookId);
    }

    await _saveToLocalSession();
    _emitSourcesUpdate(notebookId);
  }

  /// Streams sources for a notebook.
  Stream<List<NotebookSource>> streamSources(String notebookId) {
    _loadFromLocalSession();
    if (!_sourcesControllers.containsKey(notebookId) ||
        _sourcesControllers[notebookId]!.isClosed) {
      _sourcesControllers[notebookId] =
          StreamController<List<NotebookSource>>.broadcast();
    }
    Timer.run(() {
      if (_sourcesControllers.containsKey(notebookId) &&
          !_sourcesControllers[notebookId]!.isClosed) {
        _sourcesControllers[notebookId]!
            .add(List.unmodifiable(_localSources[notebookId] ?? []));
      }
    });
    return _sourcesControllers[notebookId]!.stream;
  }

  // ---------------------------------------------------------------------------
  // Output Operations (Local Session)
  // ---------------------------------------------------------------------------

  /// Adds a generated AI output to a notebook's local session.
  Future<void> addOutput(String notebookId, NotebookOutput output) async {
    await _loadFromLocalSession();
    final finalId = output.id.isNotEmpty
        ? output.id
        : 'out_${DateTime.now().millisecondsSinceEpoch}';
    final finalOutput = output.copyWith(id: finalId);

    final list = _localOutputs[notebookId] ?? [];
    list.removeWhere((o) => o.id == finalId);
    list.insert(0, finalOutput);
    _localOutputs[notebookId] = list;

    // Update parent notebook outputIds
    final nb = _localNotebooks[notebookId];
    if (nb != null) {
      final oIds = List<String>.from(nb.outputIds);
      if (!oIds.contains(finalId)) oIds.add(finalId);
      _localNotebooks[notebookId] = nb.copyWith(
        outputIds: oIds,
        updatedAt: DateTime.now(),
      );
      _emitNotebookUpdate(notebookId);
    }

    await _saveToLocalSession();
    _emitOutputsUpdate(notebookId);
  }

  /// Updates an output in local session.
  Future<void> updateOutput(String notebookId, NotebookOutput output) async {
    await _loadFromLocalSession();
    final list = _localOutputs[notebookId] ?? [];
    final idx = list.indexWhere((o) => o.id == output.id);
    if (idx != -1) {
      list[idx] = output;
      _localOutputs[notebookId] = list;
      await _saveToLocalSession();
      _emitOutputsUpdate(notebookId);
    }
  }

  /// Deletes an output from local session.
  Future<void> deleteOutput(String notebookId, String outputId) async {
    await _loadFromLocalSession();
    final list = _localOutputs[notebookId] ?? [];
    list.removeWhere((o) => o.id == outputId);
    _localOutputs[notebookId] = list;

    final nb = _localNotebooks[notebookId];
    if (nb != null) {
      final oIds = List<String>.from(nb.outputIds)..remove(outputId);
      _localNotebooks[notebookId] = nb.copyWith(
        outputIds: oIds,
        updatedAt: DateTime.now(),
      );
      _emitNotebookUpdate(notebookId);
    }

    await _saveToLocalSession();
    _emitOutputsUpdate(notebookId);
  }

  /// Streams outputs for a notebook.
  Stream<List<NotebookOutput>> streamOutputs(String notebookId) {
    _loadFromLocalSession();
    if (!_outputsControllers.containsKey(notebookId) ||
        _outputsControllers[notebookId]!.isClosed) {
      _outputsControllers[notebookId] =
          StreamController<List<NotebookOutput>>.broadcast();
    }
    Timer.run(() {
      if (_outputsControllers.containsKey(notebookId) &&
          !_outputsControllers[notebookId]!.isClosed) {
        _outputsControllers[notebookId]!
            .add(List.unmodifiable(_localOutputs[notebookId] ?? []));
      }
    });
    return _outputsControllers[notebookId]!.stream;
  }

  // ---------------------------------------------------------------------------
  // Publishing to Curriculum (Firestore Uploads ONLY on User Action)
  // ---------------------------------------------------------------------------

  /// Publishes a generated Lesson to the live Firestore `lessons` collection.
  Future<String> publishLesson({
    required String notebookId,
    required String outputId,
    required String title,
    required String prompt,
    ContentVisibility visibility = ContentVisibility.public,
    List<String> visibleTo = const [],
    String? quizId,
  }) async {
    await _loadFromLocalSession();
    final outputs = _localOutputs[notebookId] ?? [];
    final existingOutput = outputs.firstWhere((o) => o.id == outputId);

    final isVisible = visibility != ContentVisibility.certainUsers;
    final isMembersOnly = visibility == ContentVisibility.membersOnly;
    final user = AuthService.instance.currentUser;
    final role = user != null
        ? await RoleService.instance.getRole(user.uid)
        : UserRole.learner;
    final isGrammaticaLesson =
        role == UserRole.admin || role == UserRole.superadmin;

    String lessonId;
    if (existingOutput.publishedId != null &&
        existingOutput.publishedId!.isNotEmpty) {
      lessonId = existingOutput.publishedId!;
      await DatabaseService.instance.updateLesson(
        id: lessonId,
        title: title.trim(),
        prompt: prompt.trim(),
        answer: '',
        isVisible: isVisible,
        visibleTo: visibleTo,
        isMembersOnly: isMembersOnly,
        isGrammaticaLesson: isGrammaticaLesson,
        quizId: quizId,
        notebookId: notebookId,
      );
    } else {
      lessonId = await DatabaseService.instance.createLesson(
        title: title.trim(),
        prompt: prompt.trim(),
        answer: '',
        isVisible: isVisible,
        visibleTo: visibleTo,
        isMembersOnly: isMembersOnly,
        isGrammaticaLesson: isGrammaticaLesson,
        quizId: quizId,
        notebookId: notebookId,
      );
    }

    // Update local output with published reference
    final updatedOutput = existingOutput.copyWith(
      title: title.trim(),
      publishedId: lessonId,
      publishedCollection: 'lessons',
      publishMetadata: {
        'visibility': visibility.name,
        'visibleTo': visibleTo,
        'quizId': quizId,
        'publishedAt': DateTime.now().toIso8601String(),
      },
    );

    await updateOutput(notebookId, updatedOutput);
    return lessonId;
  }

  /// Publishes a generated Quiz to the live Firestore `quizzes` collection.
  Future<String> publishQuiz({
    required String notebookId,
    required String outputId,
    required String title,
    required String description,
    required List<QuizQuestion> questions,
    int durationMinutes = 30,
    int maxAttempts = 1,
    ContentVisibility visibility = ContentVisibility.public,
    List<String> visibleTo = const [],
    bool isAssessment = false,
  }) async {
    await _loadFromLocalSession();
    final outputs = _localOutputs[notebookId] ?? [];
    final existingOutput = outputs.firstWhere((o) => o.id == outputId);

    final isVisible = visibility != ContentVisibility.certainUsers;
    final isMembersOnly = visibility == ContentVisibility.membersOnly;
    final user = AuthService.instance.currentUser;
    final role = user != null
        ? await RoleService.instance.getRole(user.uid)
        : UserRole.learner;
    final isGrammaticaQuiz =
        role == UserRole.admin || role == UserRole.superadmin;

    String quizId;
    if (existingOutput.publishedId != null &&
        existingOutput.publishedId!.isNotEmpty) {
      quizId = existingOutput.publishedId!;
      await DatabaseService.instance.updateQuiz(
        id: quizId,
        title: title.trim(),
        description: description.trim(),
        questions: questions,
        duration: durationMinutes,
        maxAttempts: maxAttempts,
        isVisible: isVisible,
        visibleTo: visibleTo,
        isMembersOnly: isMembersOnly,
        isGrammaticaQuiz: isGrammaticaQuiz,
        isAssessment: isAssessment,
        notebookId: notebookId,
      );
    } else {
      quizId = await DatabaseService.instance.createQuiz(
        title: title.trim(),
        description: description.trim(),
        questions: questions,
        duration: durationMinutes,
        maxAttempts: maxAttempts,
        isVisible: isVisible,
        visibleTo: visibleTo,
        isMembersOnly: isMembersOnly,
        isGrammaticaQuiz: isGrammaticaQuiz,
        isAssessment: isAssessment,
        notebookId: notebookId,
      );
    }

    final updatedOutput = existingOutput.copyWith(
      title: title.trim(),
      publishedId: quizId,
      publishedCollection: 'quizzes',
      publishMetadata: {
        'durationMinutes': durationMinutes,
        'maxAttempts': maxAttempts,
        'visibility': visibility.name,
        'visibleTo': visibleTo,
        'isAssessment': isAssessment,
        'publishedAt': DateTime.now().toIso8601String(),
      },
    );

    await updateOutput(notebookId, updatedOutput);
    return quizId;
  }

  /// Links a published quiz to a published lesson.
  Future<void> linkLessonAndQuiz({
    required String notebookId,
    required String lessonOutputId,
    required String quizId,
  }) async {
    final outputs = _localOutputs[notebookId] ?? [];
    final lessonOut = outputs.firstWhere((o) => o.id == lessonOutputId);
    if (lessonOut.publishedId != null) {
      await DatabaseService.instance.updateLesson(
        id: lessonOut.publishedId!,
        title: lessonOut.title,
        prompt: lessonOut.data['prompt']?.toString() ?? '',
        answer: '',
        quizId: quizId,
      );
    }
  }

  /// Publishes any non-lesson/non-quiz output (e.g. Flashcards, Mind Map, Study Guide, Timeline, Briefing, FAQ)
  /// directly to the Firestore `published_content` collection.
  Future<String> publishContent({
    required String notebookId,
    required String outputId,
    required NotebookOutputType type,
    required String title,
    required Map<String, dynamic> data,
    ContentVisibility visibility = ContentVisibility.public,
    List<String> visibleTo = const [],
  }) async {
    await _loadFromLocalSession();
    final outputs = _localOutputs[notebookId] ?? [];
    final existingOutput = outputs.firstWhere((o) => o.id == outputId);

    final isVisible = visibility != ContentVisibility.certainUsers;
    final isMembersOnly = visibility == ContentVisibility.membersOnly;
    final user = AuthService.instance.currentUser;
    final role = user != null
        ? await RoleService.instance.getRole(user.uid)
        : UserRole.learner;
    final isGrammaticaContent =
        role == UserRole.admin || role == UserRole.superadmin;

    String publishedId;
    if (existingOutput.publishedId != null &&
        existingOutput.publishedId!.isNotEmpty) {
      publishedId = existingOutput.publishedId!;
      await DatabaseService.instance.updatePublishedContent(
        id: publishedId,
        title: title.trim(),
        data: data,
        isVisible: isVisible,
        visibleTo: visibleTo,
        isMembersOnly: isMembersOnly,
        isGrammaticaContent: isGrammaticaContent,
        notebookId: notebookId,
        outputId: outputId,
      );
    } else {
      publishedId = await DatabaseService.instance.createPublishedContent(
        type: type,
        title: title.trim(),
        data: data,
        createdByUid: user?.uid,
        createdByEmail: user?.email,
        isVisible: isVisible,
        visibleTo: visibleTo,
        isMembersOnly: isMembersOnly,
        isGrammaticaContent: isGrammaticaContent,
        notebookId: notebookId,
        outputId: outputId,
      );
    }

    final updatedOutput = existingOutput.copyWith(
      title: title.trim(),
      publishedId: publishedId,
      publishedCollection: 'published_content',
      publishMetadata: {
        'visibility': visibility.name,
        'visibleTo': visibleTo,
        'isMembersOnly': isMembersOnly,
        'isGrammaticaContent': isGrammaticaContent,
        'publishedAt': DateTime.now().toIso8601String(),
      },
    );

    await updateOutput(notebookId, updatedOutput);
    return publishedId;
  }

  /// Unpublishes an output, deleting it from Firestore `published_content`.
  Future<void> unpublishContent({
    required String notebookId,
    required String outputId,
  }) async {
    await _loadFromLocalSession();
    final outputs = _localOutputs[notebookId] ?? [];
    final existingOutput = outputs.firstWhere((o) => o.id == outputId);

    if (existingOutput.publishedId != null && existingOutput.publishedId!.isNotEmpty) {
      await DatabaseService.instance.deletePublishedContent(existingOutput.publishedId!);
    }

    final updatedOutput = existingOutput.copyWith(
      publishedId: null,
      publishedCollection: null,
      publishMetadata: null,
    );

    await updateOutput(notebookId, updatedOutput);
  }

  /// Backward compatible wrapper: routes shareOutput to publishContent.
  Future<void> shareOutput({
    required String notebookId,
    required String outputId,
    List<String> sharedTo = const ['all_subscribers'],
  }) async {
    await _loadFromLocalSession();
    final outputs = _localOutputs[notebookId] ?? [];
    final existingOutput = outputs.firstWhere((o) => o.id == outputId);

    await publishContent(
      notebookId: notebookId,
      outputId: outputId,
      type: existingOutput.type,
      title: existingOutput.title,
      data: existingOutput.data,
      visibility: ContentVisibility.public,
    );
  }

  /// Backward compatible wrapper: routes unshareOutput to unpublishContent.
  Future<void> unshareOutput({
    required String notebookId,
    required String outputId,
  }) async {
    await unpublishContent(
      notebookId: notebookId,
      outputId: outputId,
    );
  }

  /// Streams published flashcard decks for learner practice.
  Stream<List<NotebookOutput>> streamSharedFlashcardDecks(String userId) {
    return DatabaseService.instance
        .streamPublishedContent(userId: userId, type: NotebookOutputType.flashcards)
        .map((items) => items.map((i) => i.toNotebookOutput()).toList());
  }

  /// Streams all published outputs for a student from Firestore.
  Stream<List<NotebookOutput>> streamSharedOutputsForUser(String userId) {
    return DatabaseService.instance
        .streamPublishedContent(userId: userId)
        .map((items) => items.map((i) => i.toNotebookOutput()).toList());
  }
}
