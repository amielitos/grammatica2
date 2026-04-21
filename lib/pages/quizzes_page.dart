import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import 'quiz_folder_page.dart';
import '../theme/app_colors.dart';

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
            final nonFilteredQuizzes = allQuizzes;

            return StreamBuilder<Map<String, Map<String, dynamic>>>(
              stream: _progressStream,
              builder: (context, progressSnap) {
                final assessments = nonFilteredQuizzes.where((q) => q.isAssessment).toList();
                final regularQuizzes = nonFilteredQuizzes.where((q) => !q.isAssessment).toList();

                final grammaticaQuizzes = regularQuizzes
                    .where((q) => q.isGrammaticaQuiz == true)
                    .toList();

                final publicQuizzes = regularQuizzes.where((q) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                          'Quizzes & Assessments',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 32,
                        runSpacing: 32,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFolderCard(
                            context,
                            title: 'Assessments',
                            description: 'Tests and Exams',
                            pillLabel: 'Assessments',
                            iconColor: Colors.orange,
                            icon: Icons.assignment_turned_in_rounded,
                            onTap: () => setState(() {
                              _activeFolder = {
                                'title': 'Assessments',
                                'pillLabel': 'Independent Assessments',
                                'quizzes': assessments,
                              };
                            }),
                          ),
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
    IconData icon = Icons.quiz_rounded,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 280,
          height: 320,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 40, color: iconColor),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pillLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
