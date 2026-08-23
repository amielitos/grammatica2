import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

import 'quizzes_page.dart';
import 'lesson_folder_page.dart';
import 'lesson_page.dart';
import 'profile_page.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/modern_bottom_nav.dart';

import '../services/role_service.dart';
import 'browse_educators_tab.dart';
import 'practice_tab.dart';
import '../widgets/notification_widgets.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';

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
            userData: widget.userData,
            onFolderChanged: (folderName) {},
            onNavigateTab: (idx) {
              setState(() {
                _tabIndex = idx;
                _persistedTabIndex = idx;
              });
            },
          ),
          const PracticeTab(),
          if (widget.role != UserRole.learner) QuizzesPage(user: user),
          BrowseEducatorsTab(user: user),
          ProfilePage(key: _profileKey, user: user),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        user: user,
        userData: widget.userData,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: user.uid),
          );
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
      drawer: UniversalDrawer(
        user: user,
        userData: widget.userData,
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
      ),
      body: mainContent,
    );
  }
}

class _LessonsList extends StatefulWidget {
  const _LessonsList({
    required this.user,
    required this.role,
    required this.userData,
    this.onFolderChanged,
    this.onNavigateTab,
  });

  final User user;
  final UserRole role;
  final Map<String, dynamic> userData;
  final ValueChanged<String?>? onFolderChanged;
  final ValueChanged<int>? onNavigateTab;

  @override
  State<_LessonsList> createState() => _LessonsListState();
}

class _LessonsListState extends State<_LessonsList> {
  Map<String, dynamic>? _activeFolder;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = DatabaseService.instance.progressStream(widget.user);
    DatabaseService.instance.migrateAdminLessonsToGrammaticaOfficial();
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
            final progressMap = progressSnap.data ?? {};

            final grammaticaLessons = lessons
                .where((l) =>
                    l.isGrammaticaLesson == true ||
                    (l.createdByEmail != null &&
                        l.createdByEmail!.toLowerCase().contains('admin')))
                .toList();

            final publicLessons = lessons.where((l) {
              if (l.isGrammaticaLesson) return false;
              if (l.createdByEmail != null &&
                  l.createdByEmail!.toLowerCase().contains('admin')) {
                return false;
              }
              if (!l.isVisible) return false;
              return true;
            }).toList();
            // Calculate completed counts for each hub
            final int grammaticaCompleted = grammaticaLessons.where((l) => progressMap[l.id]?['completed'] == true).length;
            final int publicCompleted = publicLessons.where((l) => progressMap[l.id]?['completed'] == true).length;



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

            // Find next uncompleted lesson for "Continue Learning"
            Lesson? nextLesson;
            for (var l in lessons) {
              if (progressMap[l.id]?['completed'] != true) {
                nextLesson = l;
                break;
              }
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final username = widget.userData['username'] as String? ?? 'Learner';

            return CustomPaint(
              painter: _DashboardBackgroundPainter(isDark: isDark),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Hero Header
                      _buildHeroHeader(context, username: username),
                      const SizedBox(height: 20),

                      // 2. Search Bar & Filter Chips
                      _buildSearchBarAndFilters(context),
                      const SizedBox(height: 20),

                      // 3. Continue Learning Card
                      if (nextLesson != null && _searchQuery.isEmpty && _selectedFilter == 'All') ...[
                        _buildContinueLearningCard(context, nextLesson),
                        const SizedBox(height: 24),
                      ],

                      // 4. Learning Hubs label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF81B655),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Learning Hubs',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. Hub Cards — responsive row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 600;
                          final cards = <Widget>[
                            if (_selectedFilter == 'All' ||
                                _selectedFilter == 'Grammatica' ||
                                (_selectedFilter == 'Completed' && grammaticaCompleted > 0))
                              _buildHubCard(
                                context,
                                tag: 'OFFICIAL CURRICULUM',
                                title: 'Grammatica Official',
                                description:
                                    'Structured lessons by language experts. Master tenses, punctuation & sentence structure.',
                                icon: Icons.verified_rounded,
                                brandColor: const Color(0xFFF59E0B),
                                gradientEnd: const Color(0xFFD97706),
                                lessonCount: grammaticaLessons.length,
                                completedCount: grammaticaCompleted,
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
                            if (_selectedFilter == 'All' ||
                                _selectedFilter == 'Public' ||
                                (_selectedFilter == 'Completed' && publicCompleted > 0))
                              _buildHubCard(
                                context,
                                tag: 'COMMUNITY & EDUCATORS',
                                title: 'Community Hub',
                                description:
                                    'Public lessons by verified educators. Real-world topics & specialized exercises.',
                                icon: Icons.public_rounded,
                                brandColor: const Color(0xFFEF4444),
                                gradientEnd: const Color(0xFFDC2626),
                                lessonCount: publicLessons.length,
                                completedCount: publicCompleted,
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
                          ];

                          if (isNarrow) {
                            return Column(
                              children: cards
                                  .map((c) => Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: c,
                                      ))
                                  .toList(),
                            );
                          }
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: cards
                                  .map((c) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 16),
                                          child: c,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // 6. AI Practice Banner
                      _buildAiPracticeBanner(context),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );

          },
        );
      },
    );
  }

  Widget _buildHeroHeader(
    BuildContext context, {
    required String username,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = username.split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B2838), const Color(0xFF0D1117)]
              : [const Color(0xFF6AAF3D), const Color(0xFF4A8A24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF6AAF3D))
                .withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded,
                          color: Colors.amberAccent, size: 13),
                      SizedBox(width: 5),
                      Text(
                        'LEARNER DASHBOARD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome back, $firstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Master English grammar with interactive modules & AI guidance.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarAndFilters(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filters = ['All', 'Grammatica', 'Public', 'Completed'];
    final filterLabels = {
      'All': 'All Hubs',
      'Grammatica': 'Official',
      'Public': 'Community',
      'Completed': 'Completed',
    };

    return Column(
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.07),
            ),
          ),
          child: TextField(
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search lessons, topics, or educators...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white54 : const Color(0xFF81B655),
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF81B655)
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white24 : Colors.black12),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF81B655)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    filterLabels[filter]!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String tag,
    required String title,
    required String description,
    required IconData icon,
    required Color brandColor,
    required Color gradientEnd,
    required int lessonCount,
    required int completedCount,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: brandColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: brandColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [brandColor, gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Explore Hub',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
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

  Widget _buildContinueLearningCard(BuildContext context, Lesson lesson) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF81B655).withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF81B655).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Color(0xFF81B655),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONTINUE LEARNING',
                  style: TextStyle(
                    color: Color(0xFF81B655),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'By ${lesson.createdByEmail ?? "Grammatica"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonPage(user: widget.user, lesson: lesson),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81B655),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Resume',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildAiPracticeBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2D2B55), const Color(0xFF1A1836)]
              : [const Color(0xFF5B5BD6), const Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B5BD6).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'INTERACTIVE AI PRACTICE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Practice Grammar with AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instant feedback, custom questions & real-time explanations.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onNavigateTab?.call(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4338CA),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                  label: const Text(
                    'Start Practice',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.psychology_rounded,
            color: Colors.white24,
            size: 72,
          ),
        ],
      ),
    );
  }
}

class _DashboardBackgroundPainter extends CustomPainter {
  final bool isDark;

  _DashboardBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill base background color
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor);

    // 2. Draw top-right brand green glow orb
    final greenPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF81B655).withValues(alpha: isDark ? 0.15 : 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width, 0),
        radius: 350,
      ));
    canvas.drawCircle(Offset(size.width, 0), 350, greenPaint);

    // 3. Draw middle-left indigo glow orb
    final indigoPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? const Color(0xFF6366F1) : const Color(0xFF818CF8))
              .withValues(alpha: isDark ? 0.12 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(0, 350),
        radius: 380,
      ));
    canvas.drawCircle(Offset(0, 350), 380, indigoPaint);

    // 4. Draw dot-grid pattern
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : const Color(0xFF334155).withValues(alpha: 0.04)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;

    const spacing = 28.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

