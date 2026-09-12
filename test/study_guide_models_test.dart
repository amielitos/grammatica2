import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/models/study_guide_models.dart';
import 'package:grammatica/models/notebook_models.dart';

void main() {
  group('Study Guide Models Serialization', () {
    test('StudyGuide serialization roundtrip', () {
      const guide = StudyGuide(
        title: 'Cellular Biology',
        summary: 'Overview of cell organelles and functions.',
        sections: [
          StudyGuideSection(
            heading: 'Mitochondria',
            content: 'Powerhouse of the cell generating ATP.',
            bulletPoints: ['Inner membrane', 'Matrix'],
          ),
        ],
        keyTerms: [
          KeyTerm(term: 'ATP', definition: 'Adenosine Triphosphate energy molecule'),
        ],
        keyTakeaways: ['Cells require energy from mitochondria.'],
      );

      final json = guide.toJson();
      final restored = StudyGuide.fromJson(json);

      expect(restored.title, 'Cellular Biology');
      expect(restored.summary, 'Overview of cell organelles and functions.');
      expect(restored.sections.length, 1);
      expect(restored.sections.first.heading, 'Mitochondria');
      expect(restored.sections.first.bulletPoints, ['Inner membrane', 'Matrix']);
      expect(restored.keyTerms.length, 1);
      expect(restored.keyTerms.first.term, 'ATP');
      expect(restored.keyTakeaways, ['Cells require energy from mitochondria.']);

      final output = guide.toNotebookOutput(id: 'out_1', notebookId: 'nb_1');
      expect(output.type, NotebookOutputType.studyGuide);
      final fromOutput = StudyGuide.fromNotebookOutput(output);
      expect(fromOutput.title, guide.title);
    });

    test('Timeline serialization roundtrip', () {
      const timeline = Timeline(
        title: 'World War II',
        description: 'Key milestones',
        events: [
          TimelineEvent(
            dateOrPeriod: '1939',
            title: 'Invasion of Poland',
            description: 'Start of the war',
            category: 'Conflict',
          ),
        ],
      );

      final json = timeline.toJson();
      final restored = Timeline.fromJson(json);

      expect(restored.title, 'World War II');
      expect(restored.events.first.dateOrPeriod, '1939');
      expect(restored.events.first.title, 'Invasion of Poland');
      expect(restored.events.first.category, 'Conflict');
    });

    test('MindMap serialization roundtrip', () {
      const mindMap = MindMap(
        title: 'Photosynthesis',
        centralTopic: 'Photosynthesis Process',
        nodes: [
          MindMapNode(
            id: 'root',
            label: 'Photosynthesis',
            colorHex: '#10B981',
          ),
          MindMapNode(
            id: 'branch_1',
            label: 'Light Reactions',
            parentId: 'root',
            colorHex: '#3B82F6',
          ),
        ],
        edges: [
          MindMapEdge(fromId: 'root', toId: 'branch_1', label: 'involves'),
        ],
      );

      final json = mindMap.toJson();
      final restored = MindMap.fromJson(json);

      expect(restored.title, 'Photosynthesis');
      expect(restored.centralTopic, 'Photosynthesis Process');
      expect(restored.nodes.length, 2);
      expect(restored.edges.length, 1);
      expect(restored.edges.first.label, 'involves');
    });
  });
}
