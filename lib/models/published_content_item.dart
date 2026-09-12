import 'package:cloud_firestore/cloud_firestore.dart';
import 'flashcard_models.dart';
import 'notebook_models.dart';
import 'study_guide_models.dart';

/// Represents a published non-lesson/non-quiz content item in Firestore (`published_content` collection).
/// Supports mind maps, flashcards, study guides, timelines, briefings, and FAQs with full role and audience constraints.
class PublishedContentItem {
  final String id;
  final NotebookOutputType type;
  final String title;
  final Map<String, dynamic> data;
  final String? createdByUid;
  final String? createdByEmail;
  final Timestamp? createdAt;
  final bool isVisible;
  final List<String> visibleTo;
  final bool isMembersOnly;
  final bool isGrammaticaContent;
  final String validationStatus;
  final String? notebookId;
  final String? outputId;

  const PublishedContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.data,
    this.createdByUid,
    this.createdByEmail,
    this.createdAt,
    this.isVisible = true,
    this.visibleTo = const [],
    this.isMembersOnly = false,
    this.isGrammaticaContent = false,
    this.validationStatus = 'approved',
    this.notebookId,
    this.outputId,
  });

  factory PublishedContentItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return PublishedContentItem.fromMap(doc.id, map);
  }

  factory PublishedContentItem.fromMap(String id, Map<String, dynamic> map) {
    return PublishedContentItem(
      id: id,
      type: NotebookOutputType.fromString(map['type'] as String? ?? 'study_guide'),
      title: (map['title'] ?? '').toString(),
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      createdByUid: (map['createdByUid'] ?? '') == '' ? null : map['createdByUid'] as String?,
      createdByEmail: (map['createdByEmail'] ?? '') == '' ? null : map['createdByEmail'] as String?,
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] as Timestamp : null,
      isVisible: map['isVisible'] as bool? ?? true,
      visibleTo: List<String>.from(map['visibleTo'] as List? ?? []),
      isMembersOnly: map['isMembersOnly'] as bool? ?? false,
      isGrammaticaContent: map['isGrammaticaContent'] as bool? ?? false,
      validationStatus: (map['validationStatus'] ?? 'approved').toString(),
      notebookId: map['notebookId'] as String?,
      outputId: map['outputId'] as String?,
    );
  }

  factory PublishedContentItem.fromNotebookOutput(
    NotebookOutput output, {
    String? createdByUid,
    String? createdByEmail,
  }) {
    return PublishedContentItem(
      id: output.publishedId ?? output.id,
      type: output.type,
      title: output.title,
      data: output.data,
      createdByUid: createdByUid,
      createdByEmail: createdByEmail,
      createdAt: Timestamp.fromDate(output.generatedAt),
      isVisible: true,
      isMembersOnly: false,
      isGrammaticaContent: false,
      validationStatus: 'approved',
      notebookId: output.notebookId,
      outputId: output.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.serialName,
      'title': title,
      'data': data,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isVisible': isVisible,
      'visibleTo': visibleTo,
      'isMembersOnly': isMembersOnly,
      'isGrammaticaContent': isGrammaticaContent,
      'validationStatus': validationStatus,
      if (notebookId != null) 'notebookId': notebookId,
      if (outputId != null) 'outputId': outputId,
    };
  }

  // Typed model getters
  FlashcardDeck get flashcardDeck => FlashcardDeck.fromJson(data);
  MindMap get mindMap => MindMap.fromJson(data);
  StudyGuide get studyGuide => StudyGuide.fromJson(data);
  Timeline get timeline => Timeline.fromJson(data);
  Briefing get briefing => Briefing.fromJson(data);
  FAQ get faq => FAQ.fromJson(data);

  /// Converts this published item back into a [NotebookOutput] suitable for existing viewers.
  NotebookOutput toNotebookOutput() {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return NotebookOutput(
      id: outputId ?? id,
      notebookId: notebookId ?? '',
      type: type,
      title: title,
      data: data,
      generatedAt: parseDate(createdAt),
      publishedId: id,
      publishedCollection: 'published_content',
      publishMetadata: {
        'isGrammaticaContent': isGrammaticaContent,
        'isVisible': isVisible,
        'visibleTo': visibleTo,
        'isMembersOnly': isMembersOnly,
      },
    );
  }
}
