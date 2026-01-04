import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_detail_page.dart';

class QuizzesPage extends StatelessWidget {
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
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da $hh:$mm';
  }

  final User user;
  const QuizzesPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grammatica - Quizzes')),
      body: FutureBuilder<List<Quiz>>(
        future: DatabaseService.instance.fetchQuizzes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final quizzes = snapshot.data!;
          return StreamBuilder<Map<String, bool>>(
            stream: DatabaseService.instance.quizProgressStream(user),
            builder: (context, progSnap) {
              final progress = progSnap.data ?? const {};
              return ListView.separated(
                itemCount: quizzes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final q = quizzes[index];
                  final done = progress[q.id] == true;
                  String createdAtStr = q.createdAt != null
                      ? _fmt(q.createdAt!)
                      : 'N/A';
                  return ListTile(
                    title: Text(q.title),
                    subtitle: Row(
                      children: [
                        _authorName(
                          uid: q.createdByUid,
                          fallbackEmail: q.createdByEmail,
                        ),
                        const SizedBox(width: 8),
                        Text('• Created: $createdAtStr'),
                      ],
                    ),
                    trailing: done
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizDetailPage(user: user, quiz: q),
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
