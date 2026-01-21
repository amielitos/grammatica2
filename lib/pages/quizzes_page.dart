import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_detail_page.dart';
import '../widgets/glass_card.dart';

class QuizzesPage extends StatelessWidget {
  final User user;
  const QuizzesPage({super.key, required this.user});

  // Author name helper
  Widget _authorName({
    required String? uid,
    required String? fallbackEmail,
    TextStyle? style,
  }) {
    if (uid == null || uid.isEmpty) {
      return Text('By: ${fallbackEmail ?? 'Unknown'}', style: style);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        return Text('By: $display', style: style);
      },
    );
  }

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final y = d.year.toString();
    return '$m-$da-$y';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammatica'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Quiz>>(
        stream: DatabaseService.instance.streamQuizzes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading quizzes: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No quizzes available.'));
          }
          final quizzes = snapshot.data!;
          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: DatabaseService.instance.quizProgressStream(user),
            builder: (context, progSnap) {
              final progress = progSnap.data ?? const {};
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: quizzes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final q = quizzes[index];
                  final progData = progress[q.id];
                  final completed = progData?['completed'] == true;
                  final isCorrect = progData?['isCorrect'] == true;
                  final attempts = (progData?['attemptsUsed'] as int?) ?? 0;
                  final max = q.maxAttempts;

                  bool failed = !isCorrect && attempts >= max;

                  String createdAtStr = q.createdAt != null
                      ? _fmt(q.createdAt!)
                      : 'N/A';

                  return GlassCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizDetailPage(user: user, quiz: q),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ListTile(
                        title: Text(
                          q.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: _authorName(
                                    uid: q.createdByUid,
                                    fallbackEmail: q.createdByEmail,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Created: $createdAtStr',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (completed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: const Text(
                                  'Passed',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else if (failed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: const Text(
                                  'Failed',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                CupertinoIcons.chevron_right,
                                color: Colors.grey[400],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
