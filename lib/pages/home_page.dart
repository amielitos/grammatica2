import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

import 'quizzes_page.dart';
import 'lesson_folder_page.dart';
import 'profile_page.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../services/role_service.dart';
import 'browse_educators_tab.dart';
import 'practice_tab.dart';
import '../widgets/notification_widgets.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // To access notificationVisibleNotifier

class HomePage extends StatefulWidget {
  final User user;
  final UserRole role;
  final Map<String, dynamic> userData;
  final bool showProfileWarning;
  const HomePage({
    super.key,
    required this.user,
    required this.role,
    required this.userData,
    this.showProfileWarning = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static int _persistedTabIndex = 0;
  late int _tabIndex;

  final _profileKey = GlobalKey<ProfilePageState>();
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabIndex = _persistedTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileCompletion();
    });
  }

  Future<void> _checkProfileCompletion() async {
    try {
      final String? phone = widget.userData['phone_number'];
      final Timestamp? dobTs = widget.userData['date_of_birth'] as Timestamp?;

      if (phone == null || phone.isEmpty || dobTs == null) {
        // Check if we should send a reminder
        final achRef = _firestore
            .collection('users')
            .doc(widget.user.uid)
            .collection('achievements')
            .doc('profile_reminder');

        final achDoc = await achRef.get();
        bool shouldNotify = false;

        if (!achDoc.exists) {
          shouldNotify = true;
        } else {
          final lastSent = (achDoc.data()?['achievedAt'] as Timestamp?)
              ?.toDate();
          if (lastSent != null) {
            final daysSince = DateTime.now().difference(lastSent).inDays;
            if (daysSince >= 7) {
              shouldNotify = true;
            }
          }
        }

        if (shouldNotify) {
          await NotificationService.instance.sendProfileReminderNotification(
            widget.user.uid,
          );
          await achRef.set({
            'achievedAt': FieldValue.serverTimestamp(),
            'id': 'profile_reminder',
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
    }
  }

  List<ModernNavItem> _buildNavItems(User user) {
    final items = [
      const ModernNavItem(icon: Icons.book, label: 'Lessons'),
      const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'),
      if (widget.role != UserRole.learner)
        const ModernNavItem(icon: Icons.help_outline, label: 'Quizzes'),
      const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
      ModernNavItem(
        icon: Icons.person,
        label: widget.userData['username']?.split(' ').first ?? 'Profile',
      ),
    ];
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final navItems = _buildNavItems(user);

    final mainContent = ResponsiveWrapper(
      child: IndexedStack(
        index: _tabIndex,
        children: [
          _LessonsList(user: user, role: widget.role),
          const PracticeTab(),
          if (widget.role != UserRole.learner) QuizzesPage(user: user),
          BrowseEducatorsTab(user: user),
          ProfilePage(key: _profileKey, user: user),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(navItems[_tabIndex].label),
        actions: [
          NotificationIconButton(
            userId: user.uid,
            onTap: () {
              notificationVisibleNotifier.value =
                  !notificationVisibleNotifier.value;
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Sidebar(
          currentIndex: _tabIndex,
          onTap: (index) {
            setState(() {
              _tabIndex = index;
              _persistedTabIndex = index;
            });
            if (index == 4) {
              _profileKey.currentState?.fetchProfile();
            }
          },
          items: navItems,
          showProfileWarning: widget.showProfileWarning,
          isDrawer: true,
        ),
      ),
      body: mainContent,
    );
  }
}

class _LessonsList extends StatefulWidget {
  const _LessonsList({required this.user, required this.role});
  final User user;
  final UserRole role;

  @override
  State<_LessonsList> createState() => _LessonsListState();
}

class _LessonsListState extends State<_LessonsList> {
  Map<String, dynamic>? _activeFolder;
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = DatabaseService.instance.progressStream(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamLessons(
        userRole: widget.role,
        userId: widget.user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No lessons available.'));
        }
        final lessons = snapshot.data!;

        return StreamBuilder<Map<String, Map<String, dynamic>>>(
          stream: _progressStream,
          builder: (context, progressSnap) {
            // 1. Grammatica Lessons
            final grammaticaLessons = lessons
                .where((l) => l.isGrammaticaLesson == true)
                .toList();

            // 2. Public / Educator Content
            final publicLessons = lessons.where((l) {
              if (l.isGrammaticaLesson) return false;
              if (!l.isVisible) return false;
              return true;
            }).toList();

            if (_activeFolder != null) {
              return LessonFolderPage(
                user: widget.user,
                title: _activeFolder!['title'],
                pillLabel: _activeFolder!['pillLabel'],
                lessons: _activeFolder!['lessons'],
                isPublicContentFolder:
                    _activeFolder!['isPublicFolder'] ?? false,
                onBack: () => setState(() => _activeFolder = null),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Center(
                    child: Text(
                      'Lessons',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 32,
                    runSpacing: 32,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFolderCard(
                        context,
                        title: 'Grammatica',
                        description: 'Official lessons',
                        pillLabel: 'Grammatica',
                        iconColor: Theme.of(context).colorScheme.primary,
                        onTap: () => setState(() {
                          _activeFolder = {
                            'title': 'Grammatica Lessons',
                            'pillLabel': 'From Grammatica',
                            'lessons': grammaticaLessons,
                          };
                        }),
                      ),
                      _buildFolderCard(
                        context,
                        title: 'Public',
                        description: 'Community & Educators',
                        pillLabel: 'Public',
                        iconColor: Theme.of(context).colorScheme.secondary,
                        onTap: () => setState(() {
                          _activeFolder = {
                            'title': 'Public Content',
                            'pillLabel': 'Public',
                            'lessons': publicLessons,
                            'isPublicFolder': true,
                          };
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFolderCard(
    BuildContext context, {
    required String title,
    required String description,
    required String pillLabel,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 240,
          height: 280,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.folder, size: 48, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    pillLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
