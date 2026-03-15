import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'quiz_folder_page.dart';
import '../services/role_service.dart';

class QuizzesPage extends StatefulWidget {
  final User user;
  const QuizzesPage({super.key, required this.user});

  @override
  State<QuizzesPage> createState() => _QuizzesPageState();
}

class _QuizzesPageState extends State<QuizzesPage> {
  Map<String, dynamic>? _activeFolder;
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = DatabaseService.instance.quizProgressStream(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(widget.user.uid),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data;

        return StreamBuilder<List<Quiz>>(
          stream: DatabaseService.instance.streamQuizzes(
            userRole: role,
            userId: widget.user.uid,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No quizzes available.'));
            }
            final allQuizzes = snapshot.data!;
            final quizzes = allQuizzes.where((q) {
              if (q.isAssessment == false) return true;
              return role == UserRole.admin || role == UserRole.superadmin;
            }).toList();

            return StreamBuilder<Map<String, Map<String, dynamic>>>(
              stream: _progressStream,
              builder: (context, progressSnap) {
                final grammaticaQuizzes = quizzes
                    .where((q) => q.isGrammaticaQuiz == true)
                    .toList();

                final publicQuizzes = quizzes.where((q) {
                  if (q.isGrammaticaQuiz) return false;
                  if (!q.isVisible) return false;
                  return true;
                }).toList();

                if (_activeFolder != null) {
                  return QuizFolderPage(
                    user: widget.user,
                    title: _activeFolder!['title'],
                    pillLabel: _activeFolder!['pillLabel'],
                    quizzes: _activeFolder!['quizzes'],
                    isPublicContentFolder:
                        _activeFolder!['isPublicFolder'] ?? false,
                    onBack: () => setState(() => _activeFolder = null),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Quizzes',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFolderCard(
                            context,
                            title: 'Grammatica',
                            description: 'Official quizzes',
                            pillLabel: 'Grammatica',
                            iconColor: Theme.of(context).colorScheme.primary,
                            onTap: () => setState(() {
                              _activeFolder = {
                                'title': 'Grammatica Quizzes',
                                'pillLabel': 'From Grammatica',
                                'quizzes': grammaticaQuizzes,
                              };
                            }),
                          ),
                          _buildFolderCard(
                            context,
                            title: 'Public',
                            description: 'Community & Educators',
                            pillLabel: 'Public',
                            iconColor: Theme.of(context).colorScheme.secondary,
                            onTap: () => setState(() {
                              _activeFolder = {
                                'title': 'Public Content',
                                'pillLabel': 'Public',
                                'quizzes': publicQuizzes,
                                'isPublicFolder': true,
                              };
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFolderCard(
    BuildContext context, {
    required String title,
    required String description,
    required String pillLabel,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.folder, size: 56, color: iconColor),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pillLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
