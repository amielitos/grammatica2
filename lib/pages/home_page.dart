import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../services/database_service.dart';

import 'quizzes_page.dart';
import 'lesson_folder_page.dart';
import 'profile_page.dart';
import '../widgets/glass_card.dart';
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
import '../widgets/animations.dart';

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
  int _tabIndex =
      0; // 0=Lessons, 1=Practice, 2=Quizzes, 3=Subscription, 4=Profile
  final _profileKey = GlobalKey<ProfilePageState>();
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
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
    return [
      const ModernNavItem(icon: Icons.book, label: 'Lessons'),
      ModernNavItem(
        icon: Icons.auto_awesome,
        label: 'Practice',
        selectedColor: Colors.teal.shade400,
      ),
      const ModernNavItem(icon: Icons.help_outline, label: 'Quizzes'),
      const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
      ModernNavItem(
        icon: Icons.person,
        label: widget.userData['username']?.split(' ').first ?? 'Profile',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final user = widget.user;
        final navItems = _buildNavItems(user);

        final mainContent = ResponsiveWrapper(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _LessonsList(user: user, role: widget.role),
              const PracticeTab(),
              QuizzesPage(user: user),
              BrowseEducatorsTab(user: user),
              ProfilePage(key: _profileKey, user: user),
            ],
          ),
        );

        if (isDesktop) {
          return Row(
            children: [
              Sidebar(
                currentIndex: _tabIndex,
                onTap: (index) {
                  setState(() => _tabIndex = index);
                  if (index == 4) {
                    _profileKey.currentState?.fetchProfile();
                  }
                },
                items: navItems,
                showProfileWarning: widget.showProfileWarning,
                isDrawer: false,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.getMainGradient(context),
                  ),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    extendBody: true,
                    appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      surfaceTintColor: Colors.transparent,
                      centerTitle: true,
                      automaticallyImplyLeading: false,
                      actions: [
                        NotificationIconButton(
                          userId: user.uid,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  NotificationsDialog(userId: user.uid),
                            );
                          },
                        ),
                      ],
                    ),
                    body: mainContent,
                  ),
                ),
              ),
            ],
          );
        }

        // Mobile/Tablet Layout
        return Container(
          decoration: BoxDecoration(
            gradient: AppColors.getMainGradient(context),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                },
              ),
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
                  setState(() => _tabIndex = index);
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
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamLessons(
        userRole: widget.role,
        userId: widget.user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No lessons available.'));
        }
        final lessons = snapshot.data!;

        return StreamBuilder<Map<String, Map<String, dynamic>>>(
          stream: DatabaseService.instance.progressStream(widget.user),
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
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
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
                        pillColor: Colors.purple,
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
                        pillColor: Colors.blue,
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
    required Color pillColor,
    required VoidCallback onTap,
  }) {
    return HoverScale(
      scale: 1.0, // Stable size on hover
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          width: 240,
          height: 280, // Reduced from 320 to be more compact
          hoverBorderColor: pillColor,
          backgroundColor: AppColors.getCardColor(context),
          child: Padding(
            padding: const EdgeInsets.all(12.0), // Increased padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.folder,
                  size: 42,
                  color: title == 'Grammatica' ? Colors.purple : Colors.blue,
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: pillColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    pillLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pillColor.withValues(alpha: 1.0),
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

