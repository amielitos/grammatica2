import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/models/notebook_models.dart';
import 'package:grammatica/models/published_content_item.dart';
import 'package:grammatica/models/study_guide_models.dart';

void main() {
  group('PublishedContentItem Tests', () {
    test('Flashcard deck published item serialization and getter roundtrip', () {
      final data = {
        'id': 'deck_1',
        'title': 'English Irregular Verbs',
        'cards': [
          {'id': 'c1', 'front': 'go', 'back': 'went / gone'},
          {'id': 'c2', 'front': 'sing', 'back': 'sang / sung'},
        ],
      };

      final item = PublishedContentItem(
        id: 'pub_1',
        type: NotebookOutputType.flashcards,
        title: 'English Irregular Verbs',
        data: data,
        createdByUid: 'edu_123',
        createdByEmail: 'educator@grammatica.com',
        isVisible: true,
        isMembersOnly: false,
        isGrammaticaContent: false,
      );

      final map = item.toMap();
      expect(map['type'], 'flashcards');
      expect(map['title'], 'English Irregular Verbs');
      expect(map['isVisible'], true);
      expect(map['isGrammaticaContent'], false);

      final fromMap = PublishedContentItem.fromMap('pub_1', map);
      expect(fromMap.type, NotebookOutputType.flashcards);
      expect(fromMap.flashcardDeck.cards.length, 2);
      expect(fromMap.flashcardDeck.cards.first.front, 'go');

      final output = fromMap.toNotebookOutput();
      expect(output.type, NotebookOutputType.flashcards);
      expect(output.title, 'English Irregular Verbs');
      expect(output.publishedId, 'pub_1');
    });

    test('Mind map published item serialization and getter roundtrip', () {
      const mindMap = MindMap(
        title: 'Grammar Mind Map',
        centralTopic: 'English Grammar',
        nodes: [
          MindMapNode(id: 'root', label: 'English Grammar'),
          MindMapNode(id: 'n1', label: 'Nouns', parentId: 'root'),
          MindMapNode(id: 'n2', label: 'Verbs', parentId: 'root'),
        ],
        edges: [
          MindMapEdge(fromId: 'root', toId: 'n1'),
          MindMapEdge(fromId: 'root', toId: 'n2'),
        ],
      );

      final item = PublishedContentItem(
        id: 'pub_mindmap',
        type: NotebookOutputType.mindMap,
        title: 'Grammar Mind Map',
        data: mindMap.toJson(),
        isGrammaticaContent: true,
      );

      expect(item.type, NotebookOutputType.mindMap);
      expect(item.mindMap.centralTopic, 'English Grammar');
      expect(item.mindMap.nodes.length, 3);
      expect(item.mindMap.edges.length, 2);
      expect(item.isGrammaticaContent, true);
    });

    test('Study guide published item serialization and getter roundtrip', () {
      const guide = StudyGuide(
        title: 'Tenses Master Guide',
        summary: 'A comprehensive guide to English verb tenses.',
        sections: [
          StudyGuideSection(
            heading: 'Past Tense',
            content: 'Simple past and past perfect usage.',
            bulletPoints: ['Add -ed for regular verbs', 'Watch for irregulars'],
          ),
        ],
        keyTerms: [],
        keyTakeaways: [],
      );

      final item = PublishedContentItem(
        id: 'pub_guide',
        type: NotebookOutputType.studyGuide,
        title: 'Tenses Master Guide',
        data: guide.toJson(),
        isMembersOnly: true,
      );

      expect(item.studyGuide.sections.length, 1);
      expect(item.studyGuide.sections.first.heading, 'Past Tense');
      expect(item.isMembersOnly, true);
    });

    test('Timeline and FAQ published item getters', () {
      const timeline = Timeline(
        title: 'Evolution of English',
        description: 'Key milestones in English history',
        events: [
          TimelineEvent(
            dateOrPeriod: '450 AD',
            title: 'Old English',
            description: 'Anglo-Saxon settlement',
          ),
          TimelineEvent(
            dateOrPeriod: '1066 AD',
            title: 'Middle English',
            description: 'Norman conquest',
          ),
        ],
      );

      final timelineItem = PublishedContentItem(
        id: 'pub_time',
        type: NotebookOutputType.timeline,
        title: 'Evolution of English',
        data: timeline.toJson(),
      );

      expect(timelineItem.timeline.events.length, 2);
      expect(timelineItem.timeline.events[0].dateOrPeriod, '450 AD');

      const faq = FAQ(
        title: 'Grammar FAQ',
        items: [
          FAQItem(
            question: 'What is the subjunctive mood?',
            answer: 'A verb mood used to express wishes, hypothetical situations, or demands.',
            category: 'Grammar',
          ),
        ],
      );

      final faqItem = PublishedContentItem(
        id: 'pub_faq',
        type: NotebookOutputType.faq,
        title: 'Grammar FAQ',
        data: faq.toJson(),
      );

      expect(faqItem.faq.items.length, 1);
      expect(faqItem.faq.items.first.question, contains('subjunctive'));
    });
  });
}
