import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'quiz_detail_page.dart';

class QuizzesPage extends StatelessWidget {
  final User user;
  const QuizzesPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grammatica - Quizzes')),
      body: FutureBuilder<List<Quiz>>(
        future: DatabaseService.instance.fetchQuizzes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                  return ListTile(
                    title: Text(q.title),
                    trailing: done ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => QuizDetailPage(user: user, quiz: q)),
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
