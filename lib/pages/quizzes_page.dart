import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../services/database_service.dart';

import 'quiz_folder_page.dart';
import '../widgets/glass_card.dart';
import '../services/role_service.dart';
import '../widgets/animations.dart';

class QuizzesPage extends StatefulWidget {
  final User user;
  const QuizzesPage({super.key, required this.user});

  @override
  State<QuizzesPage> createState() => _QuizzesPageState();
}

class _QuizzesPageState extends State<QuizzesPage> {
  Map<String, dynamic>? _activeFolder;

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
              return Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              );
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
              stream: DatabaseService.instance.quizProgressStream(widget.user),
              builder: (context, progressSnap) {
                // 1. Grammatica Quizzes
                final grammaticaQuizzes = quizzes
                    .where((q) => q.isGrammaticaQuiz == true)
                    .toList();

                // 2. Public Quizzes
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16, // Reduced from 32
                  ),
                  child: Column(
                    // Changed from Wrap/Center/LayoutBuilder combo
                    children: [
                      const SizedBox(height: 8), // Minimal gap
                      Center(
                        child: Text(
                          'Quizzes',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
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
                            title: 'Grammatica',
                            description: 'Official quizzes',
                            pillLabel: 'Grammatica',
                            pillColor: Colors.purple,
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
                            pillColor: Colors.blue,
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
    required Color pillColor,
    required VoidCallback onTap,
  }) {
    return HoverScale(
      scale: 1.0, // Stable size on hover
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          width: 240,
          height: 280, // Reduced from 320 to match HomePage
          isSolid: true,
          backgroundColor: AppColors.getCardColor(context),
          hoverBorderColor: Colors.yellow,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.folder,
                  size: 48,
                  color: title == 'Grammatica' ? Colors.purple : Colors.blue,
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: pillColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    pillLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pillColor.withValues(alpha: 1.0),
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
