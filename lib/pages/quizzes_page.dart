import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

import 'quiz_folder_page.dart';
import '../widgets/glass_card.dart';
import '../services/role_service.dart';

class QuizzesPage extends StatelessWidget {
  final User user;
  const QuizzesPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammatica'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<UserRole>(
        stream: RoleService.instance.roleStream(user.uid),
        builder: (context, roleSnapshot) {
          final role = roleSnapshot.data;

          return StreamBuilder<List<Quiz>>(
            stream: DatabaseService.instance.streamQuizzes(
              userRole: role,
              userId: user.uid,
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

              return StreamBuilder<Map<String, dynamic>>(
                stream: DatabaseService.instance
                    .streamLearnerSubscriptions(user.uid)
                    .map(
                      (subs) => {
                        for (var s in subs)
                          s['educatorUid']: s['status'] == 'active',
                      },
                    ),
                builder: (context, subsSnap) {
                  final subscriptions = subsSnap.data ?? const {};

                  // 1. Grammatica Quizzes
                  final grammaticaQuizzes = quizzes
                      .where((q) => q.isGrammaticaQuiz == true)
                      .toList();

                  // 2. Subscribed Educator Quizzes (Members Only)
                  final subscribedQuizzes = quizzes.where((q) {
                    if (q.isGrammaticaQuiz) return false;
                    // Only include subscribed & members only
                    if (subscriptions[q.createdByUid] == true &&
                        q.isMembersOnly) {
                      return true;
                    }
                    return false;
                  }).toList();

                  // 3. Public Quizzes
                  final publicQuizzes = quizzes.where((q) {
                    if (q.isGrammaticaQuiz) return false;
                    // Exclude members only (they go to subscribed or filtered out)
                    if (q.isMembersOnly) return false;
                    // Everything else public
                    if (!q.isVisible) return false;
                    return true;
                  }).toList();

                  final List<Widget> folderCards = [];

                  // Grammatica Folder
                  if (grammaticaQuizzes.isNotEmpty) {
                    folderCards.add(
                      _buildFolderCard(
                        context,
                        title: 'Grammatica',
                        description: 'Official quizzes',
                        pillLabel: 'Grammatica',
                        pillColor: Colors.purple,
                        iconColor: Colors.purpleAccent,
                        onTap: () => _openFolder(
                          context,
                          title: 'Grammatica Quizzes',
                          pillLabel: 'From Grammatica',
                          quizzes: grammaticaQuizzes,
                        ),
                      ),
                    );
                  }

                  // Your Educators Folder
                  if (subscribedQuizzes.isNotEmpty) {
                    folderCards.add(
                      _buildFolderCard(
                        context,
                        title: 'Your Educators',
                        description: 'Members-only content',
                        pillLabel: 'Subscribed',
                        pillColor: Colors.green,
                        iconColor: Colors.greenAccent,
                        onTap: () => _openFolder(
                          context,
                          title: 'Your Educators',
                          pillLabel: 'Members Only',
                          quizzes: subscribedQuizzes,
                          isPublicFolder: true, // Use nesting logic
                        ),
                      ),
                    );
                  }

                  // Public Content
                  if (publicQuizzes.isNotEmpty) {
                    folderCards.add(
                      _buildFolderCard(
                        context,
                        title: 'Public',
                        description: 'Community quizzes',
                        pillLabel: 'Public',
                        pillColor: Colors.blue,
                        iconColor: Colors.lightBlueAccent,
                        onTap: () => _openFolder(
                          context,
                          title: 'Public Content',
                          pillLabel: 'Public',
                          quizzes: publicQuizzes,
                          isPublicFolder: true,
                        ),
                      ),
                    );
                  }

                  if (folderCards.isEmpty) {
                    return const Center(child: Text('No quizzes available.'));
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                          ),
                          child: Center(
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: folderCards
                                  .map(
                                    (w) => SizedBox(
                                      width: 234, // 50% Bigger card width
                                      height: 324, // 50% Bigger card height
                                      child: w,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openFolder(
    BuildContext context, {
    required String title,
    required String pillLabel,
    required List<Quiz> quizzes,
    bool isPublicFolder = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizFolderPage(
          user: user,
          title: title,
          pillLabel: pillLabel,
          quizzes: quizzes,
          isPublicContentFolder: isPublicFolder,
        ),
      ),
    );
  }

  Widget _buildFolderCard(
    BuildContext context, {
    required String title,
    required String description,
    required String pillLabel,
    required Color pillColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.folder,
                size: 42, // Increased icon size
                color: iconColor,
              ),
              const Spacer(),
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pillColor.withOpacity(0.5)),
                ),
                child: Text(
                  pillLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pillColor.withOpacity(1.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
