import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lesson_page.dart';
import 'quizzes_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0; // 0=Lessons,1=Quizzes,2=Profile

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammatica - Lessons'),
        actions: [
          IconButton(
            onPressed: () async {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {});
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Lessons'),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            label: 'Quizzes',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _LessonsList(user: user),
          QuizzesPage(user: user),
          ProfilePage(user: user),
        ],
      ),
    );
  }
}

class _LessonsList extends StatelessWidget {
  const _LessonsList({required this.user});
  final User user;

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da $hh:$mm';
  }

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Lesson>>(
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
                final createdAtStr = lesson.createdAt != null
                    ? _fmt(lesson.createdAt!)
                    : 'N/A';
                return ListTile(
                  title: Text(lesson.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _authorName(
                            uid: lesson.createdByUid,
                            fallbackEmail: lesson.createdByEmail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• Created: $createdAtStr',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: done
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.circle_outlined),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LessonPage(user: user, lesson: lesson),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
