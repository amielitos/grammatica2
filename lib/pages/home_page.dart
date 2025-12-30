import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'lesson_page.dart';
import 'profile_page.dart';

class HomePage extends StatelessWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammatica - Lessons'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ProfilePage(user: user))),
            icon: const Icon(Icons.person),
          ),
          IconButton(
            onPressed: () async {
              /* quick reload by rebuilding */
              (context as Element).markNeedsBuild();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Lesson>>(
        future: DatabaseService.instance.fetchLessons(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lessons = snapshot.data!;
          return StreamBuilder<Map<String, bool>>(
            stream: DatabaseService.instance.progressStream(user),
            builder: (context, progressSnap) {
              final progress = progressSnap.data ?? const {};
              return ListView.builder(
                itemCount: lessons.length,
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  final done = progress[lesson.id] == true;
                  return ListTile(
                    title: Text(lesson.title),
                    subtitle: Text(
                      lesson.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: done
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.circle_outlined),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              LessonPage(user: user, lesson: lesson),
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
}
