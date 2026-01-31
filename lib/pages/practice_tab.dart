import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'spelling_bee_page.dart';
import 'pronunciation_quiz_page.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import 'quiz_folder_page.dart';

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  int? _selectedSubTab; // null = Selection, 0 = Bee, 1 = Voice, 2 = Assessment

  @override
  Widget build(BuildContext context) {
    if (_selectedSubTab == 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const Center(child: Text("Please login first"));
      return SpellingBeePage(
        user: user,
        onBack: () => setState(() => _selectedSubTab = null),
      );
    }
    if (_selectedSubTab == 1) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const Center(child: Text("Please login first"));
      return PronunciationQuizPage(
        user: user,
        onBack: () => setState(() => _selectedSubTab = null),
      );
    }
    if (_selectedSubTab == 2) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const Center(child: Text("Please login first"));

      return StreamBuilder<UserRole>(
        stream: RoleService.instance.roleStream(user.uid),
        builder: (context, roleSnap) {
          final role = roleSnap.data;
          return StreamBuilder<List<Quiz>>(
            stream: DatabaseService.instance.streamQuizzes(
              userRole: role,
              userId: user.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final assessments = (snapshot.data ?? [])
                  .where((q) => q.isAssessment)
                  .toList();

              return QuizFolderPage(
                user: user,
                title: 'English Assessment',
                pillLabel: 'Assessment',
                quizzes: assessments,
                onBack: () => setState(() => _selectedSubTab = null),
              );
            },
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Practice Tools',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Master your grammar and pronunciation',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _PracticeCard(
            title: 'Spelling Bee',
            subtitle: 'Master spelling through fun challenges',
            icon: Icons.bug_report,
            backgroundColor: Colors.yellow.shade700,
            onTap: () => setState(() => _selectedSubTab = 0),
          ),
          const SizedBox(height: 20),
          _PracticeCard(
            title: 'Pronunciation',
            subtitle: 'Practice speaking with voice feedback',
            icon: Icons.mic,
            backgroundColor: Colors.pink.shade300,
            onTap: () => setState(() => _selectedSubTab = 1),
          ),
          const SizedBox(height: 20),
          _PracticeCard(
            title: 'English Assessment',
            subtitle: 'Take your formal English evaluation',
            icon: Icons.assignment_turned_in,
            backgroundColor: Colors.blue.shade600,
            onTap: () => setState(() => _selectedSubTab = 2),
          ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: backgroundColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: backgroundColor, size: 20),
          ],
        ),
      ),
    );
  }
}
