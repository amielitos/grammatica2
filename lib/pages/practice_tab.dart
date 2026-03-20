import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'spelling_bee_page.dart';
import 'pronunciation_quiz_page.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../theme/app_colors.dart';
import 'quiz_folder_page.dart';
import 'admin/admin_quizzes_tab.dart';

import '../theme/app_colors.dart';

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
          final canEdit =
              role == UserRole.admin ||
              role == UserRole.superadmin ||
              role == UserRole.educator;

          return StatefulBuilder(
            builder: (context, setInternalState) {
              bool showEditor = false;

              return Column(
                children: [
                  if (canEdit)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('View'),
                            icon: Icon(Icons.visibility),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Manage'),
                            icon: Icon(Icons.edit),
                          ),
                        ],
                        selected: {showEditor},
                        onSelectionChanged: (val) {
                          setInternalState(() => showEditor = val.first);
                        },
                      ),
                    ),
                  Expanded(
                    child: showEditor
                        ? Scaffold(
                            appBar: AppBar(
                              leading: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () =>
                                    setState(() => _selectedSubTab = null),
                              ),
                              title: const Text('Assessment Editor'),
                            ),
                            body: const SingleChildScrollView(
                              child: AdminQuizzesTab(isEmbedded: true),
                            ),
                          )
                        : StreamBuilder<List<Quiz>>(
                            stream: DatabaseService.instance.streamQuizzes(
                              userRole: role,
                              userId: user.uid,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final assessments = (snapshot.data ?? [])
                                  .where((q) => q.isAssessment)
                                  .toList();

                              return QuizFolderPage(
                                user: user,
                                title: 'English Assessment',
                                pillLabel: 'Assessment',
                                quizzes: assessments,
                                onBack: () =>
                                    setState(() => _selectedSubTab = null),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Practice Tools',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Master your grammar and pronunciation',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _PracticeCard(
                title: 'Spelling Bee',
                subtitle: 'Master spelling through fun challenges',
                icon: Icons.spellcheck_rounded,
                iconColor: AppColors.primary,
                onTap: () => setState(() => _selectedSubTab = 0),
              ),
              const SizedBox(height: 24),
              _PracticeCard(
                title: 'Pronunciation',
                subtitle: 'Practice speaking with voice feedback',
                icon: Icons.mic_rounded,
                iconColor: AppColors.accent,
                onTap: () => setState(() => _selectedSubTab = 1),
              ),
              const SizedBox(height: 24),
              _PracticeCard(
                title: 'English Assessment',
                subtitle: 'Take your formal English evaluation',
                icon: Icons.assignment_turned_in_rounded,
                iconColor: AppColors.secondary,
                onTap: () => setState(() => _selectedSubTab = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
