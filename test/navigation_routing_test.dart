import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/pages/admin/educator_dashboard_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Educator Dashboard Quick Actions Navigation Tests', () {
    testWidgets('Quick Actions trigger onNamedNavigation with correct labels', (tester) async {
      String? navigatedName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionsGrid(
              isPremium: true,
              onNamedNavigation: (name) => navigatedName = name,
              onTabChange: (_) {},
            ),
          ),
        ),
      );

      // Verify AI Notebooks quick action
      final aiNotebooksItem = find.text('AI Notebooks');
      expect(aiNotebooksItem, findsOneWidget);
      await tester.tap(aiNotebooksItem);
      await tester.pump();
      expect(navigatedName, equals('AI Notebooks'));

      // Verify Mentorship quick action
      final mentorshipItem = find.text('Mentorship');
      expect(mentorshipItem, findsOneWidget);
      await tester.tap(mentorshipItem);
      await tester.pump();
      expect(navigatedName, equals('Mentorship'));

      // Verify My Lessons quick action
      final myLessonsItem = find.text('My Lessons');
      expect(myLessonsItem, findsOneWidget);
      await tester.tap(myLessonsItem);
      await tester.pump();
      expect(navigatedName, equals('Lessons'));

      // Verify Practice & Quizzes quick action
      final practiceItem = find.text('Practice & Quizzes');
      expect(practiceItem, findsOneWidget);
      await tester.tap(practiceItem);
      await tester.pump();
      expect(navigatedName, equals('Practice'));
    });

    testWidgets('Quick Actions fallback to exact onTabChange indices when onNamedNavigation is null', (tester) async {
      int? navigatedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionsGrid(
              isPremium: false,
              onTabChange: (idx) => navigatedIndex = idx,
            ),
          ),
        ),
      );

      // AI Notebooks should fallback to index 4
      final aiNotebooksItem = find.text('AI Notebooks');
      await tester.tap(aiNotebooksItem);
      await tester.pump();
      expect(navigatedIndex, equals(4));

      // Mentorship should fallback to index 2
      final mentorshipItem = find.text('Mentorship');
      await tester.tap(mentorshipItem);
      await tester.pump();
      expect(navigatedIndex, equals(2));

      // My Lessons should fallback to index 1
      final myLessonsItem = find.text('My Lessons');
      await tester.tap(myLessonsItem);
      await tester.pump();
      expect(navigatedIndex, equals(1));

      // Practice & Quizzes should fallback to index 3
      final practiceItem = find.text('Practice & Quizzes');
      await tester.tap(practiceItem);
      await tester.pump();
      expect(navigatedIndex, equals(3));
    });
  });
}
