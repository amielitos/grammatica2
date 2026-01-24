import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
              final quizzes = snapshot.data!;

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

                  // 2. Subscribed Educator Quizzes
                  final subscribedQuizzes = <String, List<Quiz>>{};
                  for (var q in quizzes) {
                    if (q.isGrammaticaQuiz) continue;
                    if (subscriptions[q.createdByUid] == true) {
                      subscribedQuizzes
                          .putIfAbsent(q.createdByUid ?? 'Unknown', () => [])
                          .add(q);
                    }
                  }

                  // 3. Public Quizzes
                  final publicQuizzes = quizzes.where((q) {
                    if (q.isGrammaticaQuiz) return false;
                    if (subscriptions[q.createdByUid] == true) return false;
                    if (q.createdByUid == user.uid) return false;
                    if (q.isMembersOnly) return false;
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

                  // Subscribed Educators
                  subscribedQuizzes.forEach((uid, educatorQuizzes) {
                    if (educatorQuizzes.isNotEmpty) {
                      folderCards.add(
                        _buildFolderCardWithAuthor(
                          context,
                          uid: uid,
                          fallbackEmail: educatorQuizzes.first.createdByEmail,
                          description: 'From your educator',
                          pillLabel: 'Educator',
                          pillColor: Colors.green,
                          iconColor: Colors.greenAccent,
                          onTap: () => _openFolder(
                            context,
                            title: 'Educator Quizzes',
                            pillLabel: 'From your Educator',
                            quizzes: educatorQuizzes,
                          ),
                        ),
                      );
                    }
                  });

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

                  return GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: folderCards,
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
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.folder_solid, size: 32, color: iconColor),
              const Spacer(),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pillColor.withOpacity(0.5)),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    fontSize: 8,
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

  Widget _buildFolderCardWithAuthor(
    BuildContext context, {
    required String uid,
    required String? fallbackEmail,
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
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.folder_solid, size: 32, color: iconColor),
              const Spacer(),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final username = (data?['username'] as String?)?.trim();
                  final display = (username != null && username.isNotEmpty)
                      ? username
                      : (fallbackEmail ?? 'Unknown');
                  return Text(
                    display,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pillColor.withOpacity(0.5)),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    fontSize: 8,
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
