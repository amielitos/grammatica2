import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'spelling_bee_page.dart';
import 'pronunciation_quiz_page.dart';


import 'ai_assessment_generator_page.dart';

import '../widgets/design_ornaments.dart';

class PracticeTab extends StatefulWidget {
  final int? initialSubTab;
  const PracticeTab({super.key, this.initialSubTab});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  late int? _selectedSubTab; // null = Selection, 0 = Bee, 1 = Voice, 2 = Assessment
  
  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please login first"));

    if (_selectedSubTab == 0) {
      return SpellingBeePage(
        user: user,
        onBack: () => setState(() => _selectedSubTab = null),
      );
    }
    if (_selectedSubTab == 1) {
      return PronunciationQuizPage(
        user: user,
        onBack: () => setState(() => _selectedSubTab = null),
      );
    }
    // AI Assessment Generator sub-tab
    if (_selectedSubTab == 2) {
      return AiAssessmentGeneratorPage(
        user: user,
        onBack: () => setState(() => _selectedSubTab = null),
      );
    }

    return BackgroundWrapper(
      imageAssetPath: 'assets/practicebg.png',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            const Text(
              'Practice Tools',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        _PracticeCard(
                          title: 'Spelling Bee',
                          icon: Icons.emoji_nature_outlined,
                          themeColor: const Color(0xFFF6BC00),
                          onTap: () => setState(() => _selectedSubTab = 0),
                        ),
                        const SizedBox(height: 32),
                        _PracticeCard(
                          title: 'Pronunciation',
                          icon: Icons.record_voice_over_rounded,
                          themeColor: const Color(0xFF75A94B),
                          onTap: () => setState(() => _selectedSubTab = 1),
                        ),
                        const SizedBox(height: 32),
                        _PracticeCard(
                          title: 'English Assessment',
                          icon: Icons.fact_check_outlined,
                          themeColor: const Color(0xFFDF3F32),
                          onTap: () => setState(() => _selectedSubTab = 2),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: _PracticeCard(
                          title: 'Spelling Bee',
                          icon: Icons.emoji_nature_outlined,
                          themeColor: const Color(0xFFF6BC00),
                          onTap: () => setState(() => _selectedSubTab = 0),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _PracticeCard(
                          title: 'Pronunciation',
                          icon: Icons.record_voice_over_rounded,
                          themeColor: const Color(0xFF75A94B),
                          onTap: () => setState(() => _selectedSubTab = 1),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _PracticeCard(
                          title: 'English Assessment',
                          icon: Icons.fact_check_outlined,
                          themeColor: const Color(0xFFDF3F32),
                          onTap: () => setState(() => _selectedSubTab = 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color themeColor;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 480, // Taller card to match vertical orientation
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Browse',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
