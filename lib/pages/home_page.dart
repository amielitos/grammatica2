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
import '../services/role_service.dart';
import 'browse_educators_tab.dart';
import 'practice_tab.dart';

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex =
      0; // 0=Lessons, 1=Practice, 2=Quizzes, 3=Subscription, 4=Profile
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
          if (index == 4) {
            _profileKey.currentState?.fetchProfile();
          }
        },
        items: [
          const ModernNavItem(icon: CupertinoIcons.book, label: 'Lessons'),
          ModernNavItem(
            icon: CupertinoIcons.sparkles,
            label: 'Practice',
            selectedColor: Colors.orange.shade400,
          ),
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
        child: IndexedStack(
          index: _tabIndex,
          children: [
            _LessonsList(user: user),
            const PracticeTab(),
            QuizzesPage(user: user),
            BrowseEducatorsTab(user: user),
            ProfilePage(key: _profileKey, user: user),
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
    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(user.uid),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data;

        return StreamBuilder<List<Lesson>>(
          stream: DatabaseService.instance.streamLessons(
            userRole: role,
            userId: user.uid,
          ),
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
                final visibleLessons = lessons.where((l) {
                  if (role == UserRole.admin || role == UserRole.superadmin) {
                    return true;
                  }
                  if (!l.isMembersOnly) return true;
                  if (l.createdByUid == user.uid) return true;
                  return subscriptions[l.createdByUid] == true;
                }).toList();

                if (visibleLessons.isEmpty) {
                  return const Center(child: Text('No lessons available.'));
                }

                return StreamBuilder<Map<String, bool>>(
                  stream: DatabaseService.instance.progressStream(user),
                  builder: (context, progressSnap) {
                    final progress = progressSnap.data ?? const {};

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleLessons.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final lesson = visibleLessons[index];
                        final isSubbedMembersOnly =
                            lesson.isMembersOnly &&
                            subscriptions[lesson.createdByUid] == true;
                        final done = progress[lesson.id] == true;
                        final createdAtStr = lesson.createdAt != null
                            ? _fmt(lesson.createdAt!)
                            : 'N/A';

                        return GlassCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LessonPage(user: user, lesson: lesson),
                              ),
                            );
                          },
                          borderColor: isSubbedMembersOnly
                              ? Colors.green
                              : null,
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontSize: 18),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (lesson.isMembersOnly
                                                        ? Colors.amber
                                                        : Colors.blue)
                                                    .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (lesson.isMembersOnly
                                                          ? Colors.amber
                                                          : Colors.blue)
                                                      .withOpacity(0.5),
                                            ),
                                          ),
                                          child: Text(
                                            lesson.isMembersOnly
                                                ? 'Members Only'
                                                : 'Public',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: lesson.isMembersOnly
                                                  ? Colors.amber.shade900
                                                  : Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lesson.prompt,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        _authorName(
                                          uid: lesson.createdByUid,
                                          fallbackEmail: lesson.createdByEmail,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                        Text(
                                          '• $createdAtStr',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
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
          },
        );
      },
    );
  }
}
