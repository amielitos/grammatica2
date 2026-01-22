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

class _LessonsList extends StatefulWidget {
  const _LessonsList({required this.user});
  final User user;

  @override
  State<_LessonsList> createState() => _LessonsListState();
}

class _LessonsListState extends State<_LessonsList> {
  final _searchCtrl = TextEditingController();
  Map<String, String> _usernames = {}; // uid -> username

  @override
  void initState() {
    super.initState();
    _fetchUsernames();
    // Removed listener to prevent rebuild on every keystroke
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsernames() async {
    try {
      final users = await DatabaseService.instance.fetchUsers();
      if (mounted) {
        setState(() {
          _usernames = {
            for (var u in users) u['uid'] as String: u['username'] as String,
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching usernames: $e');
    }
  }

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Widget _authorName({
    required String? uid,
    required String? fallbackEmail,
    TextStyle? style,
  }) {
    final username = _usernames[uid] ?? '';
    final display = username.isNotEmpty
        ? username
        : (fallbackEmail ?? 'Unknown');
    return Text('By: $display', style: style);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(widget.user.uid),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data;

        return StreamBuilder<List<Lesson>>(
          stream: DatabaseService.instance.streamLessons(
            userRole: role,
            userId: widget.user.uid,
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

            final allLessons = snapshot.data ?? [];
            final query = _searchCtrl.text.toLowerCase().trim();
            final lessons = allLessons.where((l) {
              if (query.isEmpty) return true;
              final title = l.title.toLowerCase();
              final email = (l.createdByEmail ?? '').toLowerCase();
              final author = (_usernames[l.createdByUid] ?? '').toLowerCase();
              return title.contains(query) ||
                  email.contains(query) ||
                  author.contains(query);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search by title, author name',
                      prefixIcon: const Icon(CupertinoIcons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          CupertinoIcons.arrow_right_circle_fill,
                        ),
                        color: AppColors.primaryGreen,
                        onPressed: () => setState(() {}),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (lessons.isEmpty)
                  const Expanded(
                    child: Center(child: Text('No lessons found.')),
                  )
                else
                  Expanded(
                    child: StreamBuilder<Map<String, bool>>(
                      stream: DatabaseService.instance.progressStream(
                        widget.user,
                      ),
                      builder: (context, progressSnap) {
                        final progress = progressSnap.data ?? const {};

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: lessons.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 16),
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
                                    builder: (_) => LessonPage(
                                      user: widget.user,
                                      lesson: lesson,
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lesson.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(fontSize: 18),
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
                                              fallbackEmail:
                                                  lesson.createdByEmail,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Colors.grey,
                                                  ),
                                            ),
                                            Text(
                                              '• $createdAtStr',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Colors.grey,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
                    ),
                  ),
              ],
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
