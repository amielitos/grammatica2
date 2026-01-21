import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lesson_page.dart';
import 'quizzes_page.dart';
import 'profile_page.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/rainbow_background.dart';
import '../widgets/responsive_wrapper.dart';

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0; // 0=Lessons,1=Quizzes,2=Profile
  final _profileKey = GlobalKey<ProfilePageState>();

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return RainbowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) {
            setState(() => _tabIndex = i);
            if (i == 2) {
              _profileKey.currentState?.fetchProfile();
            }
          },
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black.withOpacity(0.5)
              : AppColors.glassWhite,
          elevation: 0,
          indicatorColor: AppColors.rainbow.violet,
          destinations: [
            const NavigationDestination(
              icon: Icon(CupertinoIcons.book),
              label: 'Lessons',
            ),
            const NavigationDestination(
              icon: Icon(CupertinoIcons.question_circle),
              label: 'Quizzes',
            ),
            NavigationDestination(
              icon: const Icon(CupertinoIcons.person),
              label: user.displayName?.split(' ').first ?? 'Profile',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Grammatica',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
              ),
              Expanded(
                child: ResponsiveWrapper(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _LessonsList(user: user),
                      QuizzesPage(user: user),
                      ProfilePage(key: _profileKey, user: user),
                    ],
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

class _LessonsList extends StatelessWidget {
  const _LessonsList({required this.user});
  final User user;

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamLessons(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading lessons: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No lessons available.'));
        }
        final lessons = snapshot.data!;

        return StreamBuilder<Map<String, bool>>(
          stream: DatabaseService.instance.progressStream(user),
          builder: (context, progressSnap) {
            final progress = progressSnap.data ?? const {};

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lessons.length,
              separatorBuilder: (c, i) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                final done = progress[lesson.id] == true;
                final createdAtStr = lesson.createdAt != null
                    ? _fmt(lesson.createdAt!)
                    : 'N/A';

                // Cycle through rainbow colors for card accents
                final color = AppColors.rainbow.elementAt(index);

                return GlassCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LessonPage(user: user, lesson: lesson),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      // Colored Indicator Strip
                      Container(
                        width: 6,
                        height: 80,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson.title,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lesson.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children: [
                                _authorName(
                                  uid: lesson.createdByUid,
                                  fallbackEmail: lesson.createdByEmail,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey),
                                ),
                                Text(
                                  '• $createdAtStr',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status Icon
                      if (done)
                        Icon(
                          CupertinoIcons.check_mark_circled,
                          color: AppColors.rainbow.green,
                          size: 28,
                        )
                      else
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: Colors.grey.withOpacity(0.5),
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
}
