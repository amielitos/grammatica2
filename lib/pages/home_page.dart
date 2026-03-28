import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

import 'quizzes_page.dart';
import 'lesson_folder_page.dart';
import 'profile_page.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/modern_bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../main.dart';
import '../services/role_service.dart';
import 'browse_educators_tab.dart';
import 'practice_tab.dart';
import '../widgets/notification_widgets.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../widgets/custom_app_bar.dart';

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
  String? _activeFolderName;

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
          _LessonsList(
            user: user,
            role: widget.role,
            onFolderChanged: (folderName) {
              if (mounted) {
                setState(() => _activeFolderName = folderName);
              }
            },
          ),
          const PracticeTab(),
          if (widget.role != UserRole.learner) QuizzesPage(user: user),
          BrowseEducatorsTab(user: user),
          ProfilePage(key: _profileKey, user: user),
        ],
      ),
    );
    final String currentTabLabel = navItems[_tabIndex].label;
    String bgPath = 'assets/dashboardbg.png';
    if (_activeFolderName == 'Grammatica Lessons') {
      bgPath = 'assets/grammaticafolderbg.png';
    } else if (_activeFolderName == 'Public') {
      bgPath = 'assets/publicfolderbg.png';
    } else if (currentTabLabel == 'Practice') {
      bgPath = 'assets/practicebg.png';
    } else if (currentTabLabel == 'Profile' || currentTabLabel == (widget.userData['username']?.split(' ').first ?? 'Profile')) {
      bgPath = 'assets/profilebg.png';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        user: user,
        userData: widget.userData,
        onNotificationTap: () {
          notificationVisibleNotifier.value =
              !notificationVisibleNotifier.value;
        },
        onLogoTap: () {
          setState(() {
            _tabIndex = 0;
          });
        },
        onProfileTap: () {
          final profileIndex = navItems.indexWhere((item) => item.icon == Icons.person);
          if (profileIndex != -1) {
            setState(() {
              _tabIndex = profileIndex;
            });
          }
        },
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
      body: BackgroundWrapper(
        imageAssetPath: bgPath,
        child: mainContent,
      ),
    );
  }
}

class _LessonsList extends StatefulWidget {
  const _LessonsList({required this.user, required this.role, this.onFolderChanged});
  final User user;
  final UserRole role;
  final ValueChanged<String?>? onFolderChanged;

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
                onBack: () {
                  setState(() => _activeFolder = null);
                  widget.onFolderChanged?.call(null);
                },
              );
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 64, top: 24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF333333) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: TextField(
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search lesson..',
                            hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 16),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Icon(Icons.search, color: isDark ? Colors.white : Colors.black, size: 24),
                            ),
                          ),
                        ),
                      ),
                      
                      Wrap(
                        spacing: 48,
                        runSpacing: 48,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFolderCard(
                            context,
                            title: 'Grammatica',
                            description: 'Official Lessons',
                            iconColor: const Color(0xFFF3AF0D), // Exact Yellow mock
                            onTap: () {
                              setState(() {
                                _activeFolder = {
                                  'title': 'Grammatica Lessons',
                                  'pillLabel': 'From Grammatica',
                                  'lessons': grammaticaLessons,
                                };
                              });
                              widget.onFolderChanged?.call('Grammatica Lessons');
                            },
                          ),
                          _buildFolderCard(
                            context,
                            title: 'Public',
                            description: 'Community and Educators',
                            iconColor: const Color(0xFFDE372A), // Exact Red mock
                            onTap: () {
                              setState(() {
                                _activeFolder = {
                                  'title': 'Public Content',
                                  'pillLabel': 'Public',
                                  'lessons': publicLessons,
                                  'isPublicFolder': true,
                                };
                              });
                              widget.onFolderChanged?.call('Public');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 320,
      height: 400,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Icon(Icons.folder_rounded, size: 100, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Browse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
