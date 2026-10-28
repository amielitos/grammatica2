import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/navigation_service.dart';
import '../services/agora_service.dart';
import 'conference_page.dart';

import 'quizzes_page.dart';
import 'lesson_folder_page.dart';
import 'profile_page.dart';
import 'educator_profile_page.dart';
import '../widgets/author_name_widget.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/modern_bottom_nav.dart';

import '../services/role_service.dart';
import 'browse_educators_tab.dart';
import 'practice_tab.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/center_notice_dialog.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
import '../models/playlist.dart';
import '../widgets/playlist_card.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';
import '../models/published_content_item.dart';
import '../models/notebook_models.dart';

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

  static final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(0);

  static void resetToDashboard() {
    _HomePageState._persistedTabIndex = 0;
    activeTabNotifier.value = 0;
  }

  static void navigateToTab(BuildContext context, int tabIndex) {
    _HomePageState._persistedTabIndex = tabIndex;
    activeTabNotifier.value = tabIndex;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static int _persistedTabIndex = 0;
  late int _tabIndex;

  final _profileKey = GlobalKey<ProfilePageState>();
  Timer? _mentorshipReminderTimer;

  @override
  void initState() {
    super.initState();
    _tabIndex = _persistedTabIndex;
    HomePage.activeTabNotifier.addListener(_onTabNotifierChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileCompletion();
      NotificationService.instance.checkUpcomingMentorshipReminders(widget.user.uid);
      if (widget.role == UserRole.learner) {
        BadgeService.instance.checkDailyActivity(widget.user.uid);
      }
    });
    _mentorshipReminderTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        NotificationService.instance.checkUpcomingMentorshipReminders(widget.user.uid);
      }
    });
  }

  void _onTabNotifierChange() {
    if (mounted && _tabIndex != HomePage.activeTabNotifier.value) {
      setState(() {
        _tabIndex = HomePage.activeTabNotifier.value;
        _persistedTabIndex = _tabIndex;
      });
    }
  }

  @override
  void dispose() {
    HomePage.activeTabNotifier.removeListener(_onTabNotifierChange);
    _mentorshipReminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkProfileCompletion() async {
    // Disabled automated profile reminder notifications
  }

  List<ModernNavItem> _buildNavItems(User user) {
    final items = [
      ModernNavItem(
        icon: widget.role == UserRole.learner ? Icons.dashboard_rounded : Icons.book,
        label: widget.role == UserRole.learner ? 'Dashboard' : 'Lessons',
      ),
      const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'),
      if (widget.role != UserRole.learner)
        const ModernNavItem(icon: Icons.help_outline, label: 'Quizzes'),
      const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
      const ModernNavItem(
        icon: Icons.person,
        label: 'My Profile',
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
          if (PracticeTab.isGenerating.value) {
            CenterNoticeDialog.show(
              context,
              title: 'Generation in Progress',
              message: 'Please wait until the AI finishes generating before returning to dashboard.',
            );
            return;
          }
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
        navItems: navItems,
        onTap: (index) {
          if (PracticeTab.isGenerating.value) {
            CenterNoticeDialog.show(
              context,
              title: 'Generation in Progress',
              message: 'Please wait until the AI finishes generating before switching tabs.',
            );
            return;
          }
          setState(() {
            _tabIndex = index;
            _persistedTabIndex = index;
          });
          if (index >= 0 && index < navItems.length && navItems[index].icon == Icons.person) {
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  Map<String, dynamic>? _activeFolder;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;
  late final Stream<List<Lesson>> _lessonsStream;
  late final Stream<List<PublishedContentItem>> _publishedStream;

  @override
  void initState() {
    super.initState();
    _lessonsStream = DatabaseService.instance.streamLessons(
      userRole: widget.role,
      userId: widget.user.uid,
    );
    _progressStream = DatabaseService.instance.progressStream(widget.user);
    _publishedStream = DatabaseService.instance.streamPublishedContent();
    DatabaseService.instance.migrateAdminLessonsToGrammaticaOfficial();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: _lessonsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No lessons available.'));
        }
        final lessons = snapshot.data!;

        return StreamBuilder<List<PublishedContentItem>>(
          stream: _publishedStream,
          builder: (context, pubSnap) {
            final publishedItems = pubSnap.data ?? const <PublishedContentItem>[];

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
                    publishedItems: publishedItems,
                    isPublicContentFolder:
                        _activeFolder!['isPublicFolder'] ?? false,
                    onBack: () {
                      setState(() => _activeFolder = null);
                      widget.onFolderChanged?.call(null);
                    },
                  );
                }

            // Workaround: Display the 'last lesson' the user viewed instead of attempting
            // to compute an uncompleted/current lesson (which incorrectly reported legacy
            // content without modern progress records as pending).
            Lesson? nextLesson;

            // 1. In-memory active session match
            if (DatabaseService.lastViewedLessonId != null) {
              final match = lessons
                  .where((l) => l.id == DatabaseService.lastViewedLessonId)
                  .toList();
              if (match.isNotEmpty) {
                nextLesson = match.first;
              }
            }

            // 2. Most recent activity from progress history (sorted by latest timestamp descending)
            if (nextLesson == null) {
              final lessonsWithHistory = lessons.where((l) {
                final p = progressMap[l.id];
                return p != null &&
                    (p['lastReadAt'] != null || p['completedAt'] != null);
              }).toList();

              if (lessonsWithHistory.isNotEmpty) {
                lessonsWithHistory.sort((a, b) {
                  final dynamic tsA = progressMap[a.id]?['lastReadAt'] ??
                      progressMap[a.id]?['completedAt'];
                  final dynamic tsB = progressMap[b.id]?['lastReadAt'] ??
                      progressMap[b.id]?['completedAt'];
                  if (tsA == null && tsB == null) return 0;
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  if (tsA is Timestamp && tsB is Timestamp) {
                    return tsB.compareTo(tsA);
                  }
                  return 0;
                });
                // Strictly use the most recently viewed lesson
                nextLesson = lessonsWithHistory.first;
              }
            }

            // 3. User profile persistent record
            if (nextLesson == null) {
              final lastId = widget.userData['lastViewedLessonId'] as String?;
              if (lastId != null && lastId.isNotEmpty) {
                final match = lessons.where((l) => l.id == lastId).toList();
                if (match.isNotEmpty) {
                  nextLesson = match.first;
                }
              }
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final username = widget.userData['username'] as String? ?? 'Learner';
            final query = _searchQuery.trim().toLowerCase();
            final matchingLessons = query.isEmpty || _selectedFilter == 'Playlists'
                ? <Lesson>[]
                : lessons.where((l) {
                    if (_selectedFilter == 'Grammatica') {
                      final isGramm = l.isGrammaticaLesson == true ||
                          (l.createdByEmail != null &&
                              l.createdByEmail!.toLowerCase().contains('admin'));
                      if (!isGramm) return false;
                    } else if (_selectedFilter == 'Public') {
                      if (l.isGrammaticaLesson) return false;
                      if (l.createdByEmail != null &&
                          l.createdByEmail!.toLowerCase().contains('admin')) {
                        return false;
                      }
                      if (!l.isVisible) return false;
                    } else if (_selectedFilter == 'Completed') {
                      if (progressMap[l.id]?['completed'] != true) return false;
                    }

                    final title = l.title.toLowerCase();
                    final prompt = l.prompt.toLowerCase();
                    final author = (l.createdByEmail ?? '').toLowerCase();
                    return title.contains(query) || prompt.contains(query) || author.contains(query);
                  }).toList();

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
                      const SizedBox(height: 16),

                      // Real-time Reactive Stats Overview (Option B Local-First + Aggregated Sync)
                      _buildLiveStatsOverview(
                        context,
                        isDark: isDark,
                        allLessons: lessons,
                        publishedItems: publishedItems,
                      ),
                      const SizedBox(height: 16),

                      // 2. Upcoming Mentorship Session Banner
                      _buildUpcomingSessionBanner(context),

                      // 3. Search Bar & Filter Chips
                      _buildSearchBarAndFilters(context),
                      const SizedBox(height: 20),

                      if (_searchQuery.trim().isNotEmpty) ...[
                        // Search Results Section
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
                                'Search Results (${matchingLessons.length})',
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
                        if (matchingLessons.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 44,
                                    color: isDark ? Colors.white24 : Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No lessons match "${_searchQuery.trim()}"',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try searching for different keywords or topics.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: matchingLessons.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final l = matchingLessons[idx];
                              final isCompleted = progressMap[l.id]?['completed'] == true;
                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isCompleted ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                                      color: const Color(0xFF81B655),
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    l.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    l.prompt.isNotEmpty ? l.prompt : (l.isGrammaticaLesson ? 'Official Curriculum' : (l.createdByEmail ?? 'Community')),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF81B655)),
                                  onTap: () {
                                    NavigationService.instance.goToLesson(context, l);
                                  },
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // 4. Continue Learning Card
                        if (nextLesson != null && _searchQuery.isEmpty && _selectedFilter == 'All') ...[
                          _buildContinueLearningCard(context, nextLesson, progressMap[nextLesson.id]),
                          const SizedBox(height: 24),
                        ],

                        // 4. Learning Hubs label & Hub Cards (hidden in Playlists filter)
                        if (_selectedFilter != 'Playlists') ...[
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
                                          'title': 'Public Lessons',
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
                        ],

                        // Curated Playlists (shown in All Hubs section and dedicated Playlists filter tab)
                        if (_selectedFilter == 'All' || _selectedFilter == 'Playlists') ...[
                          _buildPlaylistsSection(context, isDark),
                          const SizedBox(height: 24),
                        ],

                        // Enrolled Educators Easy Access (hidden in Official and Playlists tab)
                        if (_selectedFilter != 'Grammatica' && _selectedFilter != 'Playlists') ...[
                          _buildSubscribedEducatorsSection(context, isDark),

                          // Recent Lessons from Enrolled Educators
                          _buildSubscribedEducatorLessonsSection(context, lessons, progressMap, isDark),
                        ],
                      ],

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
  },
);
  }

  Widget _buildPlaylistsSection(BuildContext context, bool isDark) {
    return StreamBuilder<List<LessonPlaylist>>(
      stream: DatabaseService.instance.streamAllPlaylists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final allPlaylists = snapshot.data ?? [];
        final query = _searchQuery.trim().toLowerCase();
        final playlists = query.isEmpty
            ? allPlaylists
            : allPlaylists.where((p) =>
                p.title.toLowerCase().contains(query) ||
                p.description.toLowerCase().contains(query) ||
                p.createdByEmail.toLowerCase().contains(query)
              ).toList();

        if (playlists.isEmpty) {
          if (_selectedFilter == 'Playlists') {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_play_rounded,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    query.isNotEmpty
                        ? 'No playlists match "$query"'
                        : 'No learning playlists available yet',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Educators organize sequential lessons into playlists. Check back soon!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    'Curated Playlists (${playlists.length})',
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isNarrow ? 1 : 2,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final p = playlists[index];
                    return PlaylistCard(
                      playlist: p,
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
          ],
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
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF81B655),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                    StreamBuilder<UserBadgeStats>(
                      stream: BadgeService.instance.streamUserStats(widget.user.uid),
                      builder: (context, snap) {
                        final streak = snap.data?.currentStreak ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded,
                                  color: Color(0xFFFDE68A), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$streak Day${streak == 1 ? '' : 's'} Streak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
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

  Widget _buildLiveStatsOverview(
    BuildContext context, {
    required bool isDark,
    required List<Lesson> allLessons,
    required List<PublishedContentItem> publishedItems,
  }) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: DatabaseService.instance.userStatsSummaryStream(widget.user.uid),
      builder: (context, statsSnap) {
        final stats = statsSnap.data ?? {};

        return StreamBuilder<Map<String, Map<String, dynamic>>>(
          stream: DatabaseService.instance.progressStream(widget.user),
          builder: (context, progressSnap) {
            final liveProgressMap = progressSnap.data ?? {};

            return StreamBuilder<Map<String, Map<String, dynamic>>>(
              stream: DatabaseService.instance.quizProgressStream(widget.user),
              builder: (context, quizSnap) {
                final quizMap = quizSnap.data ?? {};

                // Compute fully completed lessons (Requirement: all components completed)
                int liveCompletedLessons = 0;
                for (final l in allLessons) {
                  // 1. Handout / Lesson reading
                  final handoutDone = liveProgressMap[l.id]?['completed'] == true;
                  if (!handoutDone) continue;

                  final companions = publishedItems.where((p) =>
                      p.lessonId == l.id ||
                      (l.notebookId != null && p.notebookId == l.notebookId)).toList();

                  // 2. Slides
                  final presItems = companions.where((p) => p.type == NotebookOutputType.presentation).toList();
                  bool slidesDone = true;
                  if (presItems.isNotEmpty) {
                    slidesDone = presItems.every((p) =>
                        liveProgressMap[p.id]?['completed'] == true ||
                        liveProgressMap['${l.id}_slides']?['completed'] == true);
                  }
                  if (!slidesDone) continue;

                  // 3. Flashcards
                  final fcItems = companions.where((p) => p.type == NotebookOutputType.flashcards).toList();
                  bool fcDone = true;
                  if (fcItems.isNotEmpty) {
                    fcDone = fcItems.every((p) =>
                        liveProgressMap[p.id]?['completed'] == true ||
                        liveProgressMap['${l.id}_flashcards']?['completed'] == true);
                  }
                  if (!fcDone) continue;

                  // 4. Quiz
                  final quizItems = companions.where((p) => p.type == NotebookOutputType.quiz).toList();
                  final qId = (l.quizId != null && l.quizId!.isNotEmpty)
                      ? l.quizId
                      : (quizItems.isNotEmpty ? quizItems.first.id : null);
                  bool quizDone = true;
                  if (qId != null) {
                    final qp = quizMap[qId];
                    quizDone = qp != null && (qp['completed'] == true || qp['passed'] == true);
                  }
                  if (!quizDone) continue;

                  liveCompletedLessons++;
                }

                final summaryLessons = (stats['totalLessonsCompleted'] as num?)?.toInt() ?? 0;
                final int lessons = liveCompletedLessons > summaryLessons ? liveCompletedLessons : summaryLessons;
                int liveQuizzesTaken = 0;
                double liveScoreSum = 0;
                int liveScoredCount = 0;

                for (final qp in quizMap.values) {
                  final attempts = (qp['attemptsUsed'] as num?)?.toInt() ?? 0;
                  final completed = qp['completed'] == true || qp['passed'] == true;
                  if (attempts > 0 || completed) {
                    liveQuizzesTaken += (attempts > 0 ? attempts : 1);
                    final score = (qp['score'] as num?)?.toDouble();
                    final total = (qp['totalQuestions'] as num?)?.toDouble();
                    if (score != null && total != null && total > 0) {
                      liveScoreSum += (score / total * 100);
                      liveScoredCount++;
                    }
                  }
                }

                final summaryQuizzes = (stats['totalQuizzesTaken'] as num?)?.toInt() ?? 0;
                final int quizzes = liveQuizzesTaken > summaryQuizzes ? liveQuizzesTaken : summaryQuizzes;
                final double avgScore = liveScoredCount > 0
                    ? (liveScoreSum / liveScoredCount)
                    : ((stats['averageQuizScore'] as num?)?.toDouble() ?? 0.0);

                final fcMastered = (stats['flashcardsMastered'] as num?)?.toInt() ?? 0;
                final streak = (stats['studyStreakDays'] as num?)?.toInt() ?? (lessons > 0 ? 1 : 0);

                return LayoutBuilder(
                  builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;

            Widget buildStatItem({
              required IconData icon,
              required Color color,
              required String label,
              required String value,
              String? subValue,
            }) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 16,
                  vertical: isNarrow ? 10 : 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isNarrow ? 7 : 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: isNarrow ? 17 : 20),
                    ),
                    SizedBox(width: isNarrow ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: isNarrow ? 15 : 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: isNarrow ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subValue != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              subValue,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final items = [
              buildStatItem(
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF10B981),
                label: 'Lessons Done',
                value: '$lessons',
              ),
              buildStatItem(
                icon: Icons.quiz_rounded,
                color: const Color(0xFF3B82F6),
                label: 'Quizzes Taken',
                value: '$quizzes',
                subValue: quizzes > 0 ? '${avgScore.toStringAsFixed(0)}% avg' : null,
              ),
              buildStatItem(
                icon: Icons.style_rounded,
                color: const Color(0xFF8B5CF6),
                label: 'Cards Mastered',
                value: '$fcMastered',
              ),
              buildStatItem(
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFF59E0B),
                label: 'Daily Streak',
                value: '$streak ${streak == 1 ? 'day' : 'days'}',
              ),
            ];

            if (isNarrow) {
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.15,
                children: items,
              );
            }

            return Row(
              children: [
                Expanded(child: items[0]),
                const SizedBox(width: 12),
                Expanded(child: items[1]),
                const SizedBox(width: 12),
                Expanded(child: items[2]),
                const SizedBox(width: 12),
                Expanded(child: items[3]),
              ],
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

  Widget _buildSearchBarAndFilters(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filters = ['All', 'Grammatica', 'Public', 'Playlists', 'Completed'];
    final filterLabels = {
      'All': 'All Hubs',
      'Grammatica': 'Official',
      'Public': 'Community',
      'Playlists': 'Playlists',
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
            controller: _searchController,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            onChanged: (val) {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 350), () {
                if (mounted) setState(() => _searchQuery = val);
              });
            },
            onSubmitted: (val) {
              _debounceTimer?.cancel();
              setState(() => _searchQuery = val);
            },
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
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (MediaQuery.of(context).size.width <= 600)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF81B655)),
                items: filters.map((filter) {
                  return DropdownMenuItem<String>(
                    value: filter,
                    child: Text(filterLabels[filter]!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedFilter = val);
                  }
                },
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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

  Widget _buildSubscribedEducatorsSection(BuildContext context, bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamLearnerSubscriptions(widget.user.uid),
      builder: (context, snapshot) {
        final subs = snapshot.data ?? [];
        final activeSubs = subs.where((s) => s['status'] == 'active').toList();
        if (activeSubs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Subscribed Educators',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => HomePage.navigateToTab(context, 2),
                  child: const Text('Browse More', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 85,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activeSubs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final sub = activeSubs[index];
                  final eduData = (sub['educatorData'] as Map<String, dynamic>?) ?? {};
                  final eduUid = (sub['educatorUid'] as String?) ?? (eduData['uid'] as String?) ?? '';
                  final tier = (sub['tier'] as String?) ?? 'Pro';
                  final firstName = (eduData['first_name'] as String?)?.trim() ?? '';
                  final lastName = (eduData['last_name'] as String?)?.trim() ?? '';
                  final fullName = '$firstName $lastName'.trim();
                  final username = (eduData['username'] as String?)?.trim();
                  final name = fullName.isNotEmpty ? fullName : (username ?? 'Educator');
                  final photoUrl = eduData['photoUrl'] as String?;

                  return InkWell(
                    onTap: () {
                      final fullEduMap = {'uid': eduUid, ...eduData};
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EducatorProfilePage(
                            educator: fullEduMap,
                            currentUser: widget.user,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 210,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                            onBackgroundImageError: (photoUrl != null && photoUrl.isNotEmpty) ? (err, st) {} : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tier.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSubscribedEducatorLessonsSection(
    BuildContext context,
    List<Lesson> lessons,
    Map<String, dynamic> progressMap,
    bool isDark,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamLearnerSubscriptions(widget.user.uid),
      builder: (context, snapshot) {
        final subs = snapshot.data ?? [];
        final activeSubUids = subs
            .where((s) => s['status'] == 'active')
            .map((s) => (s['educatorUid'] as String?) ?? '')
            .where((uid) => uid.isNotEmpty)
            .toSet();

        if (activeSubUids.isEmpty) return const SizedBox.shrink();

        final subscribedLessons = lessons
            .where((l) => activeSubUids.contains(l.createdByUid) && l.isVisible)
            .toList();

        if (subscribedLessons.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Recent Lessons from Your Educators',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subscribedLessons.take(3).length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final l = subscribedLessons[index];
                final isCompleted = progressMap[l.id]?['completed'] == true;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Color(0xFF0D9488),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            AuthorName(
                              uid: l.createdByUid,
                              fallbackEmail: l.createdByEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => NavigationService.instance.goToLesson(context, l),
                        style: FilledButton.styleFrom(
                          backgroundColor: isCompleted
                              ? (isDark ? Colors.white10 : Colors.grey.shade100)
                              : const Color(0xFF0D9488).withValues(alpha: 0.15),
                          foregroundColor: isCompleted
                              ? (isDark ? Colors.white60 : Colors.grey.shade700)
                              : const Color(0xFF0D9488),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: Text(
                          isCompleted ? 'Review' : 'Start',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildContinueLearningCard(BuildContext context, Lesson lesson, Map<String, dynamic>? progressInfo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double progress = (progressInfo?['progress'] as num?)?.toDouble() ?? 0.0;
    final bool isCompleted = progressInfo?['completed'] == true;

    return Container(
      width: double.infinity,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            NavigationService.instance.goToLesson(context, lesson);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                      Row(
                        children: [
                          const Text(
                            'LAST VIEWED LESSON',
                            style: TextStyle(
                              color: Color(0xFF81B655),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (progress > 0.0 && !isCompleted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}% COMPLETED',
                                style: const TextStyle(
                                  color: Color(0xFF81B655),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ] else if (isCompleted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  color: Color(0xFF81B655),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
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
                      const SizedBox(height: 2),
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
                    NavigationService.instance.goToLesson(context, lesson);
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
                  child: Text(isCompleted ? 'Review' : 'Resume',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSessionBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamStudentMentorshipSessions(widget.user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final upcoming = snapshot.data!
            .where((s) {
              final status = (s['status'] ?? '').toString().toLowerCase();
              if (status == 'cancelled' || status == 'completed') return false;
              final startTime = (s['startTime'] as Timestamp?)?.toDate();
              final endTime = (s['endTime'] as Timestamp?)?.toDate();
              final compareTime = endTime ?? startTime;
              // Filter out sessions whose scheduled time has already passed
              if (compareTime != null && compareTime.isBefore(now)) return false;
              return true;
            })
            .toList()
          ..sort((a, b) {
            // Sort by nearest upcoming startTime
            final ta = (a['startTime'] as Timestamp?)?.toDate() ?? DateTime(2099);
            final tb = (b['startTime'] as Timestamp?)?.toDate() ?? DateTime(2099);
            return ta.compareTo(tb);
          });

        if (upcoming.isEmpty) return const SizedBox.shrink();
        final next = upcoming.first;
        final title = (next['meetingTitle'] as String? ?? '').isNotEmpty
            ? next['meetingTitle'] as String
            : 'Mentorship Session';
        final agoraChannel = next['agoraChannel'] as String? ?? '';
        final sessionId = next['id'] as String? ?? '';
        final startTime = (next['startTime'] as Timestamp).toDate();
        final endTime = (next['endTime'] as Timestamp?)?.toDate();
        final dateStr = DateFormat('EEE, MMM d, yyyy').format(startTime);
        final timeStr = endTime != null
            ? '${DateFormat('h:mm a').format(startTime)} – ${DateFormat('h:mm a').format(endTime)}'
            : DateFormat('h:mm a').format(startTime);
        final educatorId = next['educatorId'] as String? ?? '';

        const appColor = Color(0xFF81B655);
        const appIcon = Icons.video_call_rounded;
        const appLabel = 'Meet';

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1a2a4a), const Color(0xFF111827)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_rounded, size: 12, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 5),
                            Text(
                              'UPCOMING SESSION',
                              style: TextStyle(
                                color: const Color(0xFF3B82F6),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: appColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(appIcon, size: 13, color: appColor),
                            const SizedBox(width: 4),
                            Text(appLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: appColor,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E3A5F),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: DatabaseService.instance.getUserDoc(educatorId),
                    builder: (context, snap) {
                      final name = snap.data?['username'] as String? ?? 'Your Educator';
                      return Row(
                        children: [
                          Icon(Icons.person_rounded, size: 14,
                              color: isDark ? Colors.white54 : const Color(0xFF4B7AB5)),
                          const SizedBox(width: 4),
                          Text(name,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : const Color(0xFF4B7AB5),
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14,
                          color: isDark ? Colors.white54 : const Color(0xFF4B7AB5)),
                      const SizedBox(width: 4),
                      Text('$dateStr  •  $timeStr',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : const Color(0xFF4B7AB5),
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.video_call_rounded, size: 16),
                      label: const Text('Join',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final channel = agoraChannel.isNotEmpty
                            ? agoraChannel
                            : AgoraService.instance.channelFromSessionId(
                                sessionId.isNotEmpty ? sessionId : 'session',
                              );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConferencePage(
                              channelName: channel,
                              sessionId: sessionId,
                              sessionTitle: title,
                              otherParticipantName: 'Educator',
                              isHost: false,
                              currentUser: widget.user,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildAiPracticeBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF4338CA),
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

    // 2. Draw subtle dot-grid pattern
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

