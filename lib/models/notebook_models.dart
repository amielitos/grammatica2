import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported types of sources that can be ingested into a Notebook.
enum SourceType {
  pdf,
  text,
  url,
  audio,
  video;

  static SourceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pdf':
        return SourceType.pdf;
      case 'text':
        return SourceType.text;
      case 'url':
        return SourceType.url;
      case 'audio':
        return SourceType.audio;
      case 'video':
        return SourceType.video;
      default:
        return SourceType.text;
    }
  }

  String get displayName {
    switch (this) {
      case SourceType.pdf:
        return 'PDF Document';
      case SourceType.text:
        return 'Text Note';
      case SourceType.url:
        return 'Web Link';
      case SourceType.audio:
        return 'Audio Recording';
      case SourceType.video:
        return 'Video File';
    }
  }
}

/// Status of source ingestion and text extraction.
enum SourceProcessingStatus {
  pending,
  processing,
  ready,
  error;

  static SourceProcessingStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return SourceProcessingStatus.pending;
      case 'processing':
        return SourceProcessingStatus.processing;
      case 'ready':
        return SourceProcessingStatus.ready;
      case 'error':
        return SourceProcessingStatus.error;
      default:
        return SourceProcessingStatus.pending;
    }
  }
}

/// A single source ingested into a Notebook.
class NotebookSource {
  final String id;
  final String notebookId;
  final SourceType type;
  final String title;
  final String rawContent;
  final String? originalUrl;
  final String? storageUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final SourceProcessingStatus processingStatus;
  final String? errorMessage;

  NotebookSource({
    required this.id,
    required this.notebookId,
    required this.type,
    required this.title,
    this.rawContent = '',
    this.originalUrl,
    this.storageUrl,
    this.metadata = const {},
    required this.createdAt,
    this.processingStatus = SourceProcessingStatus.pending,
    this.errorMessage,
  });

  int get wordCount {
    if (rawContent.isEmpty) return 0;
    return rawContent.trim().split(RegExp(r'\s+')).length;
  }

  factory NotebookSource.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return NotebookSource.fromMap(doc.id, data);
  }

  factory NotebookSource.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NotebookSource(
      id: id,
      notebookId: data['notebookId'] as String? ?? '',
      type: SourceType.fromString(data['type'] as String? ?? 'text'),
      title: data['title'] as String? ?? 'Untitled Source',
      rawContent: data['rawContent'] as String? ?? '',
      originalUrl: data['originalUrl'] as String?,
      storageUrl: data['storageUrl'] as String?,
      metadata: Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
      createdAt: parseDate(data['createdAt']),
      processingStatus: SourceProcessingStatus.fromString(
        data['processingStatus'] as String? ?? 'pending',
      ),
      errorMessage: data['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notebookId': notebookId,
      'type': type.name,
      'title': title,
      'rawContent': rawContent,
      'originalUrl': originalUrl,
      'storageUrl': storageUrl,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'processingStatus': processingStatus.name,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'notebookId': notebookId,
      'type': type.name,
      'title': title,
      'rawContent': rawContent,
      'originalUrl': originalUrl,
      'storageUrl': storageUrl,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'processingStatus': processingStatus.name,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  NotebookSource copyWith({
    String? id,
    String? notebookId,
    SourceType? type,
    String? title,
    String? rawContent,
    String? originalUrl,
    String? storageUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    SourceProcessingStatus? processingStatus,
    String? errorMessage,
  }) {
    return NotebookSource(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      type: type ?? this.type,
      title: title ?? this.title,
      rawContent: rawContent ?? this.rawContent,
      originalUrl: originalUrl ?? this.originalUrl,
      storageUrl: storageUrl ?? this.storageUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      processingStatus: processingStatus ?? this.processingStatus,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// The various AI generated output types supported in the Notebook.
enum NotebookOutputType {
  lesson,
  flashcards,
  quiz,
  studyGuide,
  timeline,
  briefing,
  faq,
  mindMap;

  static NotebookOutputType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'lesson':
        return NotebookOutputType.lesson;
      case 'flashcards':
        return NotebookOutputType.flashcards;
      case 'quiz':
        return NotebookOutputType.quiz;
      case 'study_guide':
      case 'studyguide':
        return NotebookOutputType.studyGuide;
      case 'timeline':
        return NotebookOutputType.timeline;
      case 'briefing':
        return NotebookOutputType.briefing;
      case 'faq':
        return NotebookOutputType.faq;
      case 'mind_map':
      case 'mindmap':
        return NotebookOutputType.mindMap;
      default:
        return NotebookOutputType.studyGuide;
    }
  }

  String get displayName {
    switch (this) {
      case NotebookOutputType.lesson:
        return 'Lesson';
      case NotebookOutputType.flashcards:
        return 'Flashcards';
      case NotebookOutputType.quiz:
        return 'Quiz';
      case NotebookOutputType.studyGuide:
        return 'Study Guide';
      case NotebookOutputType.timeline:
        return 'Timeline';
      case NotebookOutputType.briefing:
        return 'Briefing Doc';
      case NotebookOutputType.faq:
        return 'FAQ';
      case NotebookOutputType.mindMap:
        return 'Mind Map';
    }
  }

  String get serialName {
    switch (this) {
      case NotebookOutputType.lesson:
        return 'lesson';
      case NotebookOutputType.flashcards:
        return 'flashcards';
      case NotebookOutputType.quiz:
        return 'quiz';
      case NotebookOutputType.studyGuide:
        return 'study_guide';
      case NotebookOutputType.timeline:
        return 'timeline';
      case NotebookOutputType.briefing:
        return 'briefing';
      case NotebookOutputType.faq:
        return 'faq';
      case NotebookOutputType.mindMap:
        return 'mind_map';
    }
  }
}

/// A single AI-generated output (deck, quiz, doc, mind map, etc.) within a Notebook.
class NotebookOutput {
  final String id;
  final String notebookId;
  final NotebookOutputType type;
  final String title;
  final Map<String, dynamic> data;
  final DateTime generatedAt;
  final List<String> sourceIds;
  final bool isShared;
  final DateTime? sharedAt;
  final List<String> sharedTo; // List of user IDs or ['all_subscribers']
  final String? publishedId; // Firestore ID in 'lessons' or 'quizzes' if published
  final String? publishedCollection; // 'lessons' or 'quizzes'
  final Map<String, dynamic>? publishMetadata; // visibility, duration, attempts

  NotebookOutput({
    required this.id,
    required this.notebookId,
    required this.type,
    required this.title,
    required this.data,
    required this.generatedAt,
    this.sourceIds = const [],
    this.isShared = false,
    this.sharedAt,
    this.sharedTo = const [],
    this.publishedId,
    this.publishedCollection,
    this.publishMetadata,
  });

  bool get isPublished => publishedId != null && publishedId!.isNotEmpty;

  factory NotebookOutput.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return NotebookOutput.fromMap(doc.id, data);
  }

  factory NotebookOutput.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return NotebookOutput(
      id: id,
      notebookId: map['notebookId'] as String? ?? '',
      type: NotebookOutputType.fromString(map['type'] as String? ?? 'study_guide'),
      title: map['title'] as String? ?? 'Generated Output',
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      generatedAt: parseDate(map['generatedAt']),
      sourceIds: (map['sourceIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isShared: map['isShared'] as bool? ?? false,
      sharedAt: map['sharedAt'] != null ? parseDate(map['sharedAt']) : null,
      sharedTo: (map['sharedTo'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      publishedId: map['publishedId'] as String?,
      publishedCollection: map['publishedCollection'] as String?,
      publishMetadata: map['publishMetadata'] != null
          ? Map<String, dynamic>.from(map['publishMetadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notebookId': notebookId,
      'type': type.serialName,
      'title': title,
      'data': data,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'sourceIds': sourceIds,
      'isShared': isShared,
      if (sharedAt != null) 'sharedAt': Timestamp.fromDate(sharedAt!),
      'sharedTo': sharedTo,
      if (publishedId != null) 'publishedId': publishedId,
      if (publishedCollection != null) 'publishedCollection': publishedCollection,
      if (publishMetadata != null) 'publishMetadata': publishMetadata,
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'notebookId': notebookId,
      'type': type.serialName,
      'title': title,
      'data': data,
      'generatedAt': generatedAt.toIso8601String(),
      'sourceIds': sourceIds,
      'isShared': isShared,
      if (sharedAt != null) 'sharedAt': sharedAt!.toIso8601String(),
      'sharedTo': sharedTo,
      if (publishedId != null) 'publishedId': publishedId,
      if (publishedCollection != null) 'publishedCollection': publishedCollection,
      if (publishMetadata != null) 'publishMetadata': publishMetadata,
    };
  }

  NotebookOutput copyWith({
    String? id,
    String? notebookId,
    NotebookOutputType? type,
    String? title,
    Map<String, dynamic>? data,
    DateTime? generatedAt,
    List<String>? sourceIds,
    bool? isShared,
    DateTime? sharedAt,
    List<String>? sharedTo,
    String? publishedId,
    String? publishedCollection,
    Map<String, dynamic>? publishMetadata,
  }) {
    return NotebookOutput(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      type: type ?? this.type,
      title: title ?? this.title,
      data: data ?? this.data,
      generatedAt: generatedAt ?? this.generatedAt,
      sourceIds: sourceIds ?? this.sourceIds,
      isShared: isShared ?? this.isShared,
      sharedAt: sharedAt ?? this.sharedAt,
      sharedTo: sharedTo ?? this.sharedTo,
      publishedId: publishedId ?? this.publishedId,
      publishedCollection: publishedCollection ?? this.publishedCollection,
      publishMetadata: publishMetadata ?? this.publishMetadata,
    );
  }
}

/// Top-level Notebook model representing a unified research and generation workspace.
class Notebook {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> sourceIds;
  final List<String> outputIds;
  final String? coverImageUrl;
  final List<String> tags;

  Notebook({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.sourceIds = const [],
    this.outputIds = const [],
    this.coverImageUrl,
    this.tags = const [],
  });

  factory Notebook.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Notebook.fromMap(doc.id, data);
  }

  factory Notebook.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Notebook(
      id: id,
      title: map['title'] as String? ?? 'Untitled Notebook',
      description: map['description'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      sourceIds: (map['sourceIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      outputIds: (map['outputIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      coverImageUrl: map['coverImageUrl'] as String?,
      tags: (map['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sourceIds': sourceIds,
      'outputIds': outputIds,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      'tags': tags,
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sourceIds': sourceIds,
      'outputIds': outputIds,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      'tags': tags,
    };
  }

  Notebook copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? sourceIds,
    List<String>? outputIds,
    String? coverImageUrl,
    List<String>? tags,
  }) {
    return Notebook(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceIds: sourceIds ?? this.sourceIds,
      outputIds: outputIds ?? this.outputIds,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      tags: tags ?? this.tags,
    );
  }
}
