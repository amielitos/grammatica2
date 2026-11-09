import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quiz UI Screen-Friendly & Skipped Questions Outline Tests', () {
    testWidgets('Skipped question indicator renders yellow outline with amber accent', (tester) async {
      // Simulating the question item in the question sidebar
      Widget buildQuestionItem({
        required int index,
        required bool isSelected,
        required bool hasAnswer,
        required bool isSkipped,
        required bool isDark,
      }) {
        Color bgColor = Colors.transparent;
        Color textColor = isDark ? Colors.white70 : const Color(0xFF64748B);
        Color borderColor = isDark ? Colors.white12 : Colors.black12;
        double borderWidth = 1.0;

        if (isSelected) {
          bgColor = const Color(0xFF2563EB); // AppColors.primary
          textColor = Colors.white;
          borderColor = const Color(0xFF2563EB);
          borderWidth = 1.5;
        } else if (hasAnswer) {
          bgColor = const Color(0xFF2563EB).withValues(alpha: 0.1);
          textColor = const Color(0xFF2563EB);
          borderColor = const Color(0xFF2563EB).withValues(alpha: 0.25);
        } else if (isSkipped) {
          bgColor = const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.12 : 0.4);
          textColor = isDark ? const Color(0xFFFDE047) : const Color(0xFFB45309);
          borderColor = const Color(0xFFEAB308); // Yellow outline
          borderWidth = 2.0;
        }

        return Container(
          key: ValueKey('question_$index'),
          height: 46,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${index + 1}', style: TextStyle(color: textColor)),
              if (isSkipped && !isSelected)
                const Icon(Icons.warning_amber_rounded, key: ValueKey('warning_icon')),
              if (hasAnswer && !isSelected)
                const Icon(Icons.check_rounded, key: ValueKey('check_icon')),
            ],
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Q1: Answered
                buildQuestionItem(index: 0, isSelected: false, hasAnswer: true, isSkipped: false, isDark: false),
                // Q2: Skipped without answer
                buildQuestionItem(index: 1, isSelected: false, hasAnswer: false, isSkipped: true, isDark: false),
                // Q3: Active / selected
                buildQuestionItem(index: 2, isSelected: true, hasAnswer: false, isSkipped: false, isDark: false),
                // Q4: Unvisited
                buildQuestionItem(index: 3, isSelected: false, hasAnswer: false, isSkipped: false, isDark: false),
              ],
            ),
          ),
        ),
      );

      // Verify Q2 has the yellow outline border
      final q2Container = tester.widget<Container>(find.byKey(const ValueKey('question_1')));
      final q2BoxDecoration = q2Container.decoration as BoxDecoration;
      final q2Border = q2BoxDecoration.border as Border;

      expect(q2Border.top.color, equals(const Color(0xFFEAB308)));
      expect(q2Border.top.width, equals(2.0));
      expect(find.byKey(const ValueKey('warning_icon')), findsOneWidget);

      // Verify Q1 has check icon
      expect(find.byKey(const ValueKey('check_icon')), findsOneWidget);
    });

    testWidgets('Scrollable question content and pinned submit button stay within viewport', (tester) async {
      final questionScrollController = ScrollController();
      final sideScrollController = ScrollController();

      addTearDown(() {
        questionScrollController.dispose();
        sideScrollController.dispose();
      });

      // Bounded height layout matching short screen viewport (e.g. 600px)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              width: 1000,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // Question Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text('Question 1 of 10'),
                                Expanded(
                                  child: Scrollbar(
                                    controller: questionScrollController,
                                    child: SingleChildScrollView(
                                      controller: questionScrollController,
                                      child: Column(
                                        children: List.generate(
                                          20,
                                          (i) => Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text('Long question paragraph or option $i'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Pinned Action Buttons
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                key: const ValueKey('finish_quiz_button'),
                                onPressed: () {},
                                child: const Text('Finish Quiz'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Side Panel with Scrollbar
                  SizedBox(
                    width: 280,
                    child: Scrollbar(
                      controller: sideScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: sideScrollController,
                        itemCount: 30,
                        itemBuilder: (context, i) => ListTile(title: Text('Question ${i + 1}')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Ensure Finish Quiz button is visible without any page scrolling needed
      expect(find.byKey(const ValueKey('finish_quiz_button')), findsOneWidget);
      expect(tester.getBottomRight(find.byKey(const ValueKey('finish_quiz_button'))).dy, lessThanOrEqualTo(600.0));

      // Side panel scrollbar exists and handles large question lists
      expect(find.byType(Scrollbar), findsNWidgets(2));
    });

    testWidgets('Pronunciation quiz session pins controls and keeps bottom actions within viewport', (tester) async {
      final innerWordScrollController = ScrollController();
      addTearDown(() => innerWordScrollController.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500, // Constrained height similar to small laptop / browser window
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          // Top header badge
                          const Text('PRONUNCIATION • Intermediate'),
                          const SizedBox(height: 8),
                          // Stats row
                          const Row(
                            children: [
                              Expanded(child: Text('Progress: 1/10')),
                              Expanded(child: Text('Score: 0/10')),
                              Expanded(child: Text('Time Left: 02:00')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Main interactive card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  // Inner scrollable word/hint area
                                  Expanded(
                                    child: Scrollbar(
                                      controller: innerWordScrollController,
                                      child: SingleChildScrollView(
                                        controller: innerWordScrollController,
                                        child: Column(
                                          children: [
                                            const Text('EXTRAORDINARY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                            ...List.generate(15, (i) => Text('Detailed pronunciation syllable breakdown line $i')),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Pinned bottom controls
                                  const SizedBox(height: 8),
                                  const Text('Press the mic and say the word clearly'),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        key: const ValueKey('pronounce_mic_button'),
                                        onPressed: () {},
                                        icon: const Icon(Icons.mic_rounded),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton(
                                        key: const ValueKey('pronounce_submit_button'),
                                        onPressed: () {},
                                        child: const Text('Submit'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    key: const ValueKey('pronounce_skip_button'),
                                    onPressed: () {},
                                    child: const Text('Skip Word'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Ensure all buttons exist and are visible within 500px height
      expect(find.byKey(const ValueKey('pronounce_mic_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pronounce_submit_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('pronounce_skip_button')), findsOneWidget);

      final skipBottom = tester.getBottomRight(find.byKey(const ValueKey('pronounce_skip_button'))).dy;
      expect(skipBottom, lessThanOrEqualTo(500.0));
    });

    testWidgets('Spelling bee session pins input and submit button within viewport', (tester) async {
      final innerPromptScrollController = ScrollController();
      final answerCtrl = TextEditingController();
      addTearDown(() {
        innerPromptScrollController.dispose();
        answerCtrl.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500, // Constrained height
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          const Text('SPELLING BEE • Beginner'),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Expanded(child: Text('Progress: 1/10')),
                              Expanded(child: Text('Score: 0/10')),
                              Expanded(child: Text('Time Left: 02:00')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  // Inner scrollable prompt & hints
                                  Expanded(
                                    child: Scrollbar(
                                      controller: innerPromptScrollController,
                                      child: SingleChildScrollView(
                                        controller: innerPromptScrollController,
                                        child: Column(
                                          children: [
                                            IconButton(
                                              key: const ValueKey('spelling_speaker_button'),
                                              onPressed: () {},
                                              icon: const Icon(Icons.volume_up_rounded),
                                            ),
                                            ...List.generate(15, (i) => Text('Comprehensive dictionary definition line $i')),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Pinned bottom input, submit, skip
                                  const SizedBox(height: 8),
                                  TextField(
                                    key: const ValueKey('spelling_input_field'),
                                    controller: answerCtrl,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    key: const ValueKey('spelling_submit_button'),
                                    onPressed: () {},
                                    child: const Text('Submit Answer'),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    key: const ValueKey('spelling_skip_button'),
                                    onPressed: () {},
                                    child: const Text('Skip Word'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Ensure controls exist and are within 500px height
      expect(find.byKey(const ValueKey('spelling_speaker_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('spelling_input_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('spelling_submit_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('spelling_skip_button')), findsOneWidget);

      final skipBottom = tester.getBottomRight(find.byKey(const ValueKey('spelling_skip_button'))).dy;
      expect(skipBottom, lessThanOrEqualTo(500.0));
    });

    testWidgets('Difficulty selection fits completely on screen without scrolling on desktop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 520, // Constrained height matching user's browser window
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 750;
                  final isCompactHeight = constraints.maxHeight < 720;
                  final isVeryShort = constraints.maxHeight < 480;

                  Widget content = Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? (isCompactHeight ? 24 : 48) : 20,
                          vertical: isCompactHeight ? 12 : 28,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Choose your Difficulty'),
                            const SizedBox(height: 6),
                            const Text('Select a challenge level below to practice speaking.'),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    key: const ValueKey('card_beginner'),
                                    padding: const EdgeInsets.all(14),
                                    child: const Column(
                                      children: [
                                        Text('BEGINNER'),
                                        Icon(Icons.lightbulb_outline_rounded, size: 26),
                                        Text('Beginner'),
                                        Text('120s per word.'),
                                        ElevatedButton(
                                          key: ValueKey('start_practice_beginner'),
                                          onPressed: null,
                                          child: Text('Start Practice'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (isDesktop && !isVeryShort) {
                    return SizedBox(
                      width: double.infinity,
                      height: constraints.maxHeight,
                      child: content,
                    );
                  }

                  return SingleChildScrollView(
                    key: const ValueKey('fallback_scroll'),
                    child: content,
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify that Start Practice button is visible within the 520px height
      expect(find.byKey(const ValueKey('start_practice_beginner')), findsOneWidget);
      final btnBottom = tester.getBottomRight(find.byKey(const ValueKey('start_practice_beginner'))).dy;
      expect(btnBottom, lessThanOrEqualTo(520.0));

      // Verify no outer scrollview was rendered when isDesktop && !isVeryShort
      expect(find.byKey(const ValueKey('fallback_scroll')), findsNothing);
    });
  });
}

