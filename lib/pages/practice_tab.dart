import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'spelling_bee_page.dart';
import 'pronunciation_quiz_page.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import 'quiz_folder_page.dart';
import 'admin/admin_quizzes_tab.dart';

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
                            body: SingleChildScrollView(
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Practice Tools',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Master your grammar and pronunciation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _PracticeCard(
            title: 'Spelling Bee',
            subtitle: 'Master spelling through fun challenges',
            icon: Icons.spellcheck,
            iconColor: Theme.of(context).colorScheme.primary,
            onTap: () => setState(() => _selectedSubTab = 0),
          ),
          const SizedBox(height: 16),
          _PracticeCard(
            title: 'Pronunciation',
            subtitle: 'Practice speaking with voice feedback',
            icon: Icons.mic,
            iconColor: Theme.of(context).colorScheme.tertiary,
            onTap: () => setState(() => _selectedSubTab = 1),
          ),
          const SizedBox(height: 16),
          _PracticeCard(
            title: 'English Assessment',
            subtitle: 'Take your formal English evaluation',
            icon: Icons.assignment_turned_in,
            iconColor: Theme.of(context).colorScheme.secondary,
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
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
