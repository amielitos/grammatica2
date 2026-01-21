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
import '../widgets/responsive_wrapper.dart';
import '../widgets/modern_bottom_nav.dart';

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0; // 0=Lessons,1=Quizzes,2=Profile,3=Subscription
  final _profileKey = GlobalKey<ProfilePageState>();

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Grammatica',
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: _tabIndex,
        onTap: (index) {
          setState(() => _tabIndex = index);
          if (index == 3) {
            _profileKey.currentState?.fetchProfile();
          }
        },
        items: [
          const ModernNavItem(icon: CupertinoIcons.book, label: 'Lessons'),
          const ModernNavItem(
            icon: CupertinoIcons.question_circle,
            label: 'Quizzes',
          ),
          const ModernNavItem(
            icon: CupertinoIcons.creditcard,
            label: 'Subscription',
          ),
          ModernNavItem(
            icon: CupertinoIcons.person,
            label: user.displayName?.split(' ').first ?? 'Profile',
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _LessonsList(user: user),
                  QuizzesPage(user: user),
                  const _SubscriptionTab(),
                  ProfilePage(key: _profileKey, user: user),
                ],
              ),
            ),
            const _SecondaryBottomNav(),
          ],
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
                      const SizedBox(width: 8),
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
                          color: AppColors.primaryGreen,
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

class _SubscriptionTab extends StatelessWidget {
  const _SubscriptionTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.creditcard, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Subscription Plan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Coming Soon', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SecondaryBottomNav extends StatelessWidget {
  const _SecondaryBottomNav();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        child: Row(
          children: [
            Expanded(
              child: _SecondaryNavButton(
                icon: CupertinoIcons.ant,
                label: 'Spelling Bee',
                onTap: () {},
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SecondaryNavButton(
                icon: CupertinoIcons.mic,
                label: 'Pronunciation',
                onTap: () {},
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _SecondaryNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
