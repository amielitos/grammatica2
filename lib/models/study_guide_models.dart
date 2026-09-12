import 'notebook_models.dart';

// ---------------------------------------------------------------------------
// Study Guide
// ---------------------------------------------------------------------------

class KeyTerm {
  final String term;
  final String definition;

  const KeyTerm({required this.term, required this.definition});

  factory KeyTerm.fromJson(Map<String, dynamic> json) {
    return KeyTerm(
      term: json['term'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'definition': definition,
      };
}

class StudyGuideSection {
  final String heading;
  final String content;
  final List<String> bulletPoints;

  const StudyGuideSection({
    required this.heading,
    required this.content,
    this.bulletPoints = const [],
  });

  factory StudyGuideSection.fromJson(Map<String, dynamic> json) {
    return StudyGuideSection(
      heading: json['heading'] as String? ?? '',
      content: json['content'] as String? ?? '',
      bulletPoints: (json['bulletPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'content': content,
        'bulletPoints': bulletPoints,
      };
}

class StudyGuide {
  final String title;
  final String summary;
  final List<StudyGuideSection> sections;
  final List<KeyTerm> keyTerms;
  final List<String> keyTakeaways;

  const StudyGuide({
    required this.title,
    required this.summary,
    required this.sections,
    required this.keyTerms,
    required this.keyTakeaways,
  });

  factory StudyGuide.fromJson(Map<String, dynamic> json) {
    return StudyGuide(
      title: json['title'] as String? ?? 'Study Guide',
      summary: json['summary'] as String? ?? '',
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((s) => StudyGuideSection.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      keyTerms: (json['keyTerms'] as List<dynamic>? ?? [])
          .map((k) => KeyTerm.fromJson(Map<String, dynamic>.from(k as Map)))
          .toList(),
      keyTakeaways: (json['keyTakeaways'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'sections': sections.map((s) => s.toJson()).toList(),
        'keyTerms': keyTerms.map((k) => k.toJson()).toList(),
        'keyTakeaways': keyTakeaways,
      };

  NotebookOutput toNotebookOutput({
    required String id,
    required String notebookId,
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.studyGuide,
      title: title,
      data: toJson(),
      generatedAt: DateTime.now(),
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
    );
  }

  factory StudyGuide.fromNotebookOutput(NotebookOutput output) {
    return StudyGuide.fromJson(output.data);
  }
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

class TimelineEvent {
  final String dateOrPeriod;
  final String title;
  final String description;
  final String? category;

  const TimelineEvent({
    required this.dateOrPeriod,
    required this.title,
    required this.description,
    this.category,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      dateOrPeriod: json['dateOrPeriod'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateOrPeriod': dateOrPeriod,
        'title': title,
        'description': description,
        if (category != null) 'category': category,
      };
}

class Timeline {
  final String title;
  final String description;
  final List<TimelineEvent> events;

  const Timeline({
    required this.title,
    this.description = '',
    required this.events,
  });

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      title: json['title'] as String? ?? 'Chronological Timeline',
      description: json['description'] as String? ?? '',
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => TimelineEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'events': events.map((e) => e.toJson()).toList(),
      };

  NotebookOutput toNotebookOutput({
    required String id,
    required String notebookId,
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.timeline,
      title: title,
      data: toJson(),
      generatedAt: DateTime.now(),
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
    );
  }

  factory Timeline.fromNotebookOutput(NotebookOutput output) {
    return Timeline.fromJson(output.data);
  }
}

// ---------------------------------------------------------------------------
// Briefing
// ---------------------------------------------------------------------------

class BriefingActionItem {
  final String text;
  final bool isDone;
  final String priority; // low, medium, high

  const BriefingActionItem({
    required this.text,
    this.isDone = false,
    this.priority = 'medium',
  });

  factory BriefingActionItem.fromJson(Map<String, dynamic> json) {
    return BriefingActionItem(
      text: json['text'] as String? ?? '',
      isDone: json['isDone'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'isDone': isDone,
        'priority': priority,
      };

  BriefingActionItem copyWith({bool? isDone}) {
    return BriefingActionItem(
      text: text,
      isDone: isDone ?? this.isDone,
      priority: priority,
    );
  }
}

class Briefing {
  final String title;
  final String executiveSummary;
  final List<String> keyPoints;
  final List<BriefingActionItem> actionItems;
  final String? conclusion;

  const Briefing({
    required this.title,
    required this.executiveSummary,
    required this.keyPoints,
    required this.actionItems,
    this.conclusion,
  });

  factory Briefing.fromJson(Map<String, dynamic> json) {
    return Briefing(
      title: json['title'] as String? ?? 'Briefing Document',
      executiveSummary: json['executiveSummary'] as String? ?? '',
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      actionItems: (json['actionItems'] as List<dynamic>? ?? [])
          .map((a) => BriefingActionItem.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      conclusion: json['conclusion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'executiveSummary': executiveSummary,
        'keyPoints': keyPoints,
        'actionItems': actionItems.map((a) => a.toJson()).toList(),
        if (conclusion != null) 'conclusion': conclusion,
      };

  NotebookOutput toNotebookOutput({
    required String id,
    required String notebookId,
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.briefing,
      title: title,
      data: toJson(),
      generatedAt: DateTime.now(),
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
    );
  }

  factory Briefing.fromNotebookOutput(NotebookOutput output) {
    return Briefing.fromJson(output.data);
  }
}

// ---------------------------------------------------------------------------
// FAQ
// ---------------------------------------------------------------------------

class FAQItem {
  final String question;
  final String answer;
  final String? category;

  const FAQItem({
    required this.question,
    required this.answer,
    this.category,
  });

  factory FAQItem.fromJson(Map<String, dynamic> json) {
    return FAQItem(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        if (category != null) 'category': category,
      };
}

class FAQ {
  final String title;
  final String description;
  final List<FAQItem> items;

  const FAQ({
    required this.title,
    this.description = '',
    required this.items,
  });

  factory FAQ.fromJson(Map<String, dynamic> json) {
    return FAQ(
      title: json['title'] as String? ?? 'Frequently Asked Questions',
      description: json['description'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => FAQItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'items': items.map((i) => i.toJson()).toList(),
      };

  NotebookOutput toNotebookOutput({
    required String id,
    required String notebookId,
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.faq,
      title: title,
      data: toJson(),
      generatedAt: DateTime.now(),
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
    );
  }

  factory FAQ.fromNotebookOutput(NotebookOutput output) {
    return FAQ.fromJson(output.data);
  }
}

// ---------------------------------------------------------------------------
// Mind Map
// ---------------------------------------------------------------------------

class MindMapNode {
  final String id;
  final String label;
  final String? parentId;
  final String? category;
  final String? colorHex;
  final String? description;

  const MindMapNode({
    required this.id,
    required this.label,
    this.parentId,
    this.category,
    this.colorHex,
    this.description,
  });

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      parentId: json['parentId'] as String?,
      category: json['category'] as String?,
      colorHex: json['colorHex'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (parentId != null) 'parentId': parentId,
        if (category != null) 'category': category,
        if (colorHex != null) 'colorHex': colorHex,
        if (description != null) 'description': description,
      };
}

class MindMapEdge {
  final String fromId;
  final String toId;
  final String? label;

  const MindMapEdge({
    required this.fromId,
    required this.toId,
    this.label,
  });

  factory MindMapEdge.fromJson(Map<String, dynamic> json) {
    return MindMapEdge(
      fromId: json['fromId'] as String? ?? '',
      toId: json['toId'] as String? ?? '',
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'fromId': fromId,
        'toId': toId,
        if (label != null) 'label': label,
      };
}

class MindMap {
  final String title;
  final String centralTopic;
  final List<MindMapNode> nodes;
  final List<MindMapEdge> edges;

  const MindMap({
    required this.title,
    required this.centralTopic,
    required this.nodes,
    this.edges = const [],
  });

  factory MindMap.fromJson(Map<String, dynamic> json) {
    return MindMap(
      title: json['title'] as String? ?? 'Mind Map',
      centralTopic: json['centralTopic'] as String? ?? '',
      nodes: (json['nodes'] as List<dynamic>? ?? [])
          .map((n) => MindMapNode.fromJson(Map<String, dynamic>.from(n as Map)))
          .toList(),
      edges: (json['edges'] as List<dynamic>? ?? [])
          .map((e) => MindMapEdge.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'centralTopic': centralTopic,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  NotebookOutput toNotebookOutput({
    required String id,
    required String notebookId,
    List<String> sourceIds = const [],
    bool isShared = false,
    DateTime? sharedAt,
    List<String> sharedTo = const [],
  }) {
    return NotebookOutput(
      id: id,
      notebookId: notebookId,
      type: NotebookOutputType.mindMap,
      title: title,
      data: toJson(),
      generatedAt: DateTime.now(),
      sourceIds: sourceIds,
      isShared: isShared,
      sharedAt: sharedAt,
      sharedTo: sharedTo,
    );
  }

  factory MindMap.fromNotebookOutput(NotebookOutput output) {
    return MindMap.fromJson(output.data);
  }
}
