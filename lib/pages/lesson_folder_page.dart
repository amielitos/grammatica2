import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/author_name_widget.dart';
import '../models/published_content_item.dart';
import '../models/notebook_models.dart';
import '../services/navigation_service.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/universal_drawer.dart';
import '../widgets/design_ornaments.dart';


class LessonFolderPage extends StatefulWidget {
  final User user;
  final String title;
  final String pillLabel;
  final List<Lesson> lessons;
  final List<PublishedContentItem> publishedItems;
  // If true, this is the "Public Content" top folder which contains sub-folders
  final bool isPublicContentFolder;

  final VoidCallback? onBack;

  const LessonFolderPage({
    super.key,
    required this.user,
    required this.title,
    required this.pillLabel,
    required this.lessons,
    this.publishedItems = const [],
    this.isPublicContentFolder = false,
    this.onBack,
  });

  @override
  State<LessonFolderPage> createState() => _LessonFolderPageState();
}

class _LessonFolderPageState extends State<LessonFolderPage> {
  String _searchQuery = '';
  String _selectedDateFilter = 'All Time'; // Date filter: All Time, Past 7 Days, Past 30 Days, This Year
  bool _sortNewestFirst = true;



  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = DatabaseService.instance.progressStream(widget.user);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onBack != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _buildContent(context),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        user: widget.user,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
      ),
      drawer: UniversalDrawer(
        user: widget.user,
        userData: const {},
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return BackgroundWrapper(
      child: widget.isPublicContentFolder
          ? _buildPublicContentBody(context)
          : _buildLessonListBody(context),
    );
  }

  Widget _buildPublicContentBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Group lessons and published items by author
    final Map<String, List<Lesson>> authorLessons = {};
    for (var lesson in widget.lessons) {
      final key = lesson.createdByUid ?? 'Unknown';
      authorLessons.putIfAbsent(key, () => []).add(lesson);
    }
    final Map<String, List<PublishedContentItem>> authorPublished = {};
    for (var item in widget.publishedItems) {
      final key = item.createdByUid ?? 'Unknown';
      authorPublished.putIfAbsent(key, () => []).add(item);
    }

    final allAuthorUids = <String>{
      ...authorLessons.keys,
      ...authorPublished.keys,
    }.toList();

    // Filter by search query
    final filteredAuthors = allAuthorUids.where((uid) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final lList = authorLessons[uid] ?? [];
      final pList = authorPublished[uid] ?? [];
      final matchesLesson = lList.any((l) =>
          l.title.toLowerCase().contains(q) ||
          (l.createdByEmail ?? '').toLowerCase().contains(q));
      final matchesPublished = pList.any((p) =>
          p.title.toLowerCase().contains(q) ||
          (p.createdByEmail ?? '').toLowerCase().contains(q));
      return matchesLesson || matchesPublished;
    }).toList();

    final totalMaterials = widget.lessons.length + widget.publishedItems.length;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroBanner(
            context,
            isDark: isDark,
            itemCount: totalMaterials,
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: widget.onBack != null ? 16 : 24,
              horizontal: 28,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width > 800
                      ? 520
                      : double.infinity,
                ),
                child: AppSearchBar(
                  hintText: 'Search educator content...',
                  onSearch: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Center(
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: filteredAuthors.map((authorUid) {
                  final lessons = authorLessons[authorUid] ?? [];
                  final published = authorPublished[authorUid] ?? [];
                  final authorEmail = lessons.isNotEmpty
                      ? lessons.first.createdByEmail
                      : (published.isNotEmpty ? published.first.createdByEmail : null);
                  final totalCount = lessons.length + published.length;
                  final isMobile = MediaQuery.of(context).size.width < 650;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: isMobile ? double.infinity : 320,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LessonFolderPage(
                                    user: widget.user,
                                    title: 'Educator Content',
                                    pillLabel: 'Educator Content',
                                    lessons: lessons,
                                    publishedItems: published,
                                    isPublicContentFolder: false,
                                    onBack: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Gradient Banner with Avatar
                                Container(
                                  height: 90,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFDC2626).withValues(alpha: isDark ? 0.4 : 0.15),
                                        const Color(0xFFF97316).withValues(alpha: isDark ? 0.25 : 0.08),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(24),
                                      topRight: Radius.circular(24),
                                    ),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        top: 14,
                                        right: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.verified_rounded, size: 14, color: Color(0xFF3B82F6)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Educator',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF3B82F6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: -24,
                                        left: 20,
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFFEE2E2),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                              width: 3.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.12),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.school_rounded,
                                              color: const Color(0xFFDC2626),
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Card Content
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AuthorName(
                                        uid: authorUid == 'Unknown' ? null : authorUid,
                                        fallbackEmail: authorEmail,
                                        style: GoogleFonts.outfit(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.auto_stories_rounded,
                                              size: 14,
                                              color: const Color(0xFFDC2626),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$totalCount Learning Materials',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Explore Content',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFDC2626),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 15,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(
    BuildContext context, {
    required bool isDark,
    required int itemCount,
  }) {
    final isGrammatica = widget.pillLabel.toLowerCase().contains('grammatica') ||
        widget.title.toLowerCase().contains('grammatica');

    final gradientColors = isGrammatica
        ? (isDark
            ? [const Color(0xFF142E20), const Color(0xFF0B1912)]
            : [const Color(0xFF6AAF3D), const Color(0xFF437A20)])
        : (isDark
            ? [const Color(0xFF381A28), const Color(0xFF1D0E16)]
            : [const Color(0xFFF97316), const Color(0xFFEF4444)]);

    final tagLabel = isGrammatica ? '✨ OFFICIAL CURRICULUM' : '🌟 COMMUNITY HUB';
    final subtitle = isGrammatica
        ? 'Master grammar, punctuation, and syntax with structured lessons curated by language experts.'
        : 'Explore community-crafted lessons, flashcards, mind maps, and interactive notes.';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(28, widget.onBack != null ? 16 : 32, 28, 12),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: isDark ? 0.35 : 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -20,
            child: Opacity(
              opacity: 0.12,
              child: Icon(
                isGrammatica ? Icons.verified_rounded : Icons.public_rounded,
                size: 140,
                color: Colors.white,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null || Navigator.of(context).canPop())
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white),
                            const SizedBox(width: 7),
                            Text(
                              isGrammatica ? 'Back to Lessons' : 'Back to Community Hub',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  tagLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _buildBannerBadge(Icons.auto_stories_rounded, '$itemCount Materials Available'),
                  _buildBannerBadge(Icons.verified_rounded, isGrammatica ? 'Official Verified' : 'Community Rated'),
                  _buildBannerBadge(Icons.bolt_rounded, 'Self-Paced Practice'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChips(bool isDark) {
    final filters = [
      'All Time',
      'Past 7 Days',
      'Past 30 Days',
      'This Year',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      child: Row(
        children: [
          ...filters.map((filter) {
            final isSelected = _selectedDateFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDateFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          // Sort toggle
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sortNewestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 13,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortNewestFirst ? 'Newest' : 'Oldest',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonListBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final filteredLessons = widget.lessons.where((l) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = l.title.toLowerCase().contains(q) ||
            (l.createdByEmail ?? '').toLowerCase().contains(q) ||
            l.prompt.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_selectedDateFilter == 'All Time') return true;
      if (l.createdAt == null) return false;
      final lessonDate = l.createdAt!.toDate();
      final diff = now.difference(lessonDate).inDays;
      if (_selectedDateFilter == 'Past 7 Days') return diff <= 7;
      if (_selectedDateFilter == 'Past 30 Days') return diff <= 30;
      if (_selectedDateFilter == 'This Year') return lessonDate.year == now.year;
      return true;
    }).toList();

    final filteredPublished = widget.publishedItems.where((item) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = item.title.toLowerCase().contains(q) ||
            (item.createdByEmail ?? '').toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_selectedDateFilter == 'All Time') return true;
      if (item.createdAt == null) return false;
      final itemDate = item.createdAt!.toDate();
      final diff = now.difference(itemDate).inDays;
      if (_selectedDateFilter == 'Past 7 Days') return diff <= 7;
      if (_selectedDateFilter == 'Past 30 Days') return diff <= 30;
      if (_selectedDateFilter == 'This Year') return itemDate.year == now.year;
      return true;
    }).toList();

    filteredLessons.sort((a, b) {
      final tsA = a.createdAt;
      final tsB = b.createdAt;
      if (tsA == null && tsB == null) return a.title.compareTo(b.title);
      if (tsA == null) return 1;
      if (tsB == null) return -1;
      return _sortNewestFirst ? tsB.compareTo(tsA) : tsA.compareTo(tsB);
    });

    filteredPublished.sort((a, b) {
      final tsA = a.createdAt;
      final tsB = b.createdAt;
      if (tsA == null && tsB == null) return a.title.compareTo(b.title);
      if (tsA == null) return 1;
      if (tsB == null) return -1;
      return _sortNewestFirst ? tsB.compareTo(tsA) : tsA.compareTo(tsB);
    });

    final flashcards = filteredPublished
        .where((p) => p.type == NotebookOutputType.flashcards)
        .toList();
    final mindMaps = filteredPublished
        .where((p) => p.type == NotebookOutputType.mindMap)
        .toList();
    final studyGuides = filteredPublished
        .where((p) => p.type == NotebookOutputType.studyGuide)
        .toList();
    final timelines = filteredPublished
        .where((p) => p.type == NotebookOutputType.timeline)
        .toList();
    final briefings = filteredPublished
        .where((p) => p.type == NotebookOutputType.briefing)
        .toList();
    final faqs = filteredPublished
        .where((p) => p.type == NotebookOutputType.faq)
        .toList();

    final hasAnyItems = filteredLessons.isNotEmpty ||
        flashcards.isNotEmpty ||
        mindMaps.isNotEmpty ||
        studyGuides.isNotEmpty ||
        timelines.isNotEmpty ||
        briefings.isNotEmpty ||
        faqs.isNotEmpty;

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: _progressStream,
      builder: (context, progressSnap) {
        final progress = progressSnap.data ?? const {};

        final authorLabel = (widget.pillLabel == 'From Grammatica' ||
                widget.pillLabel == 'Grammatica')
            ? 'Grammatica'
            : null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            final headerBlock = Column(
              children: [
                _buildHeroBanner(
                  context,
                  isDark: isDark,
                  itemCount: widget.lessons.length + widget.publishedItems.length,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: TextField(
                        controller: _searchController,
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
                        style:
                            TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Search lessons and materials...',
                          hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _debounceTimer?.cancel();
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                                )
                              : Icon(Icons.search_rounded,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.textSecondary),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 22),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildDateFilterChips(isDark),
                const SizedBox(height: 8),
              ],
            );

            Widget buildSection(String title, List<Widget> cards) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards,
                  ),
                ],
              );
            }

            Widget buildContentItems({required bool isMobile}) {
              if (!hasAnyItems) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No materials found.',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : AppColors.textSecondary)),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (filteredLessons.isNotEmpty)
                    buildSection(
                      'Lessons (${filteredLessons.length})',
                      filteredLessons.map((l) {
                        final completed =
                            progress[l.id]?['completed'] == true;
                        return _buildSmallLessonCard(
                          context,
                          lesson: l,
                          completed: completed,
                          authorLabel: authorLabel,
                          isMobile: isMobile,
                        );
                      }).toList(),
                    ),
                  if (flashcards.isNotEmpty)
                    buildSection(
                      'Flashcard Decks (${flashcards.length})',
                      flashcards.map((f) {
                        final completed =
                            progress[f.id]?['completed'] == true;
                        return _buildSmallPublishedItemCard(
                          context,
                          item: f,
                          completed: completed,
                          authorLabel: authorLabel,
                          isMobile: isMobile,
                        );
                      }).toList(),
                    ),
                  if (mindMaps.isNotEmpty)
                    buildSection(
                      'Mind Maps (${mindMaps.length})',
                      mindMaps.map((m) {
                        final completed =
                            progress[m.id]?['completed'] == true;
                        return _buildSmallPublishedItemCard(
                          context,
                          item: m,
                          completed: completed,
                          authorLabel: authorLabel,
                          isMobile: isMobile,
                        );
                      }).toList(),
                    ),
                  if (studyGuides.isNotEmpty)
                    buildSection(
                      'Study Guides (${studyGuides.length})',
                      studyGuides.map((g) {
                        final completed =
                            progress[g.id]?['completed'] == true;
                        return _buildSmallPublishedItemCard(
                          context,
                          item: g,
                          completed: completed,
                          authorLabel: authorLabel,
                          isMobile: isMobile,
                        );
                      }).toList(),
                    ),
                  if (timelines.isNotEmpty)
                    buildSection(
                      'Timelines (${timelines.length})',
                      timelines.map((t) {
                        final completed =
                            progress[t.id]?['completed'] == true;
                        return _buildSmallPublishedItemCard(
                          context,
                          item: t,
                          completed: completed,
                          authorLabel: authorLabel,
                          isMobile: isMobile,
                        );
                      }).toList(),
                    ),
                  if (briefings.isNotEmpty)
                    buildSection(
                      'Briefing Documents (${briefings.length})',
                      briefings.map((b) {
                        final completed =
                            progress[b.id]?['completed'] == true;
                        return _buildSmallPublishedItemCard(
                          context,
                          item: b,
                          completed: completed,
                          authorLabel: authorLabel,
                          isMobile: isMobile,
                        );
                      }).toList(),
                    ),
                  if (faqs.isNotEmpty)
                    buildSection(
                      'Frequently Asked Questions (${faqs.length})',
                      faqs.map((q) {
                        final completed =
                            progress[q.id]?['completed'] == true;
                        return _buildSmallPublishedItemCard(
                          context,
                          item: q,
                          completed: completed,
                          authorLabel: authorLabel,
                          isMobile: isMobile,
                        );
                      }).toList(),
                    ),
                ],
              );
            }

            final metricsBlock = _buildMetricsSection(
                context, widget.lessons, widget.publishedItems, progress);

            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerBlock,
                  if (isWide)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: buildContentItems(isMobile: false),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 280,
                            child: metricsBlock,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: buildContentItems(isMobile: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: metricsBlock,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSmallLessonCard(
    BuildContext context, {
    required Lesson lesson,
    required bool completed,
    String? authorLabel,
    bool isMobile = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isGrammatica = widget.pillLabel == 'From Grammatica' ||
        widget.pillLabel == 'Grammatica' ||
        lesson.isGrammaticaLesson;

    final Color accentColor = isGrammatica
        ? const Color(0xFF6AAF3D)
        : const Color(0xFFEF4444);

    final List<Color> topGradient = isGrammatica
        ? [const Color(0xFF6AAF3D), const Color(0xFF81B655)]
        : [const Color(0xFFF97316), const Color(0xFFEF4444)];

    final double cardWidth = isMobile ? double.infinity : 290.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: cardWidth,
        height: 310,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                NavigationService.instance.goToLesson(context, lesson);
              },
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: topGradient),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isGrammatica
                                      ? Icons.menu_book_rounded
                                      : Icons.school_rounded,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              if (completed)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF10B981), size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        'COMPLETED',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'LESSON',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: accentColor,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lesson.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (lesson.prompt.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              lesson.prompt,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const Spacer(),
                          Divider(
                            height: 16,
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 11,
                                          color: isDark
                                              ? Colors.white38
                                              : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          lesson.createdAt != null
                                              ? DateFormat.yMMMd().format(
                                                  lesson.createdAt!.toDate().toLocal())
                                              : 'Grammatica Official',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white54
                                                : const Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'by: ${authorLabel ?? lesson.createdByEmail ?? 'Unknown'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 15,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallPublishedItemCard(
    BuildContext context, {
    required PublishedContentItem item,
    required bool completed,
    String? authorLabel,
    bool isMobile = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color typeColor;
    IconData typeIcon;
    String badgeLabel = item.type.displayName.toUpperCase();
    String subtitle = '';

    switch (item.type) {
      case NotebookOutputType.flashcards:
        typeColor = const Color(0xFF8B5CF6); // Purple
        typeIcon = Icons.style_rounded;
        final count = item.flashcardDeck.cards.length;
        subtitle = '$count cards';
        break;
      case NotebookOutputType.mindMap:
        typeColor = const Color(0xFF06B6D4); // Cyan
        typeIcon = Icons.account_tree_rounded;
        subtitle = 'Interactive graph';
        break;
      case NotebookOutputType.studyGuide:
        typeColor = const Color(0xFF10B981); // Emerald
        typeIcon = Icons.menu_book_rounded;
        final count = item.studyGuide.sections.length;
        subtitle = '$count sections';
        break;
      case NotebookOutputType.timeline:
        typeColor = const Color(0xFFF59E0B); // Amber
        typeIcon = Icons.timeline_rounded;
        final count = item.timeline.events.length;
        subtitle = '$count events';
        break;
      case NotebookOutputType.briefing:
        typeColor = const Color(0xFF3B82F6); // Blue
        typeIcon = Icons.description_rounded;
        subtitle = 'Executive doc';
        break;
      case NotebookOutputType.faq:
        typeColor = const Color(0xFFEC4899); // Pink
        typeIcon = Icons.question_answer_rounded;
        final count = item.faq.items.length;
        subtitle = '$count Q&As';
        break;
      default:
        typeColor = const Color(0xFF81B655);
        typeIcon = Icons.article_rounded;
        subtitle = 'Document';
        break;
    }

    final double cardWidth = isMobile ? double.infinity : 240.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: cardWidth,
        height: isMobile ? 240 : 290,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                NavigationService.instance.goToContent(context, item);
              },
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [typeColor, typeColor.withValues(alpha: 0.6)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(typeIcon, color: typeColor, size: 20),
                              ),
                              if (completed)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF10B981), size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        'COMPLETED',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: typeColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'by: ${authorLabel ?? item.createdByEmail ?? 'Grammatica'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection(
    BuildContext context,
    List<Lesson> lessons,
    List<PublishedContentItem> publishedItems,
    Map<String, dynamic> progress,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int completedCount = 0;
    List<Map<String, dynamic>> recentActivities = [];

    for (var l in lessons) {
      final p = progress[l.id];
      if (p != null) {
        final isCompleted = p['completed'] == true;
        if (isCompleted) {
          completedCount++;
        }
        final dynamic rawTs = p['lastReadAt'] ?? p['completedAt'];
        if (rawTs is Timestamp) {
          recentActivities.add({
            'title': l.title,
            'completed': isCompleted,
            'timestamp': rawTs,
            'lesson': l,
            'type': 'Lesson',
          });
        }
      }
    }

    for (var item in publishedItems) {
      final p = progress[item.id];
      if (p != null) {
        final isCompleted = p['completed'] == true;
        if (isCompleted) {
          completedCount++;
        }
        final dynamic rawTs = p['lastReadAt'] ?? p['completedAt'];
        if (rawTs is Timestamp) {
          recentActivities.add({
            'title': item.title,
            'completed': isCompleted,
            'timestamp': rawTs,
            'item': item,
            'type': item.type.displayName,
          });
        }
      }
    }

    final totalItems = lessons.length + publishedItems.length;
    double percent = totalItems == 0 ? 0 : (completedCount / totalItems).clamp(0.0, 1.0);
    final percentInt = (percent * 100).toInt();

    recentActivities.sort(
      (a, b) => (b['timestamp'] as Timestamp).compareTo(
        a['timestamp'] as Timestamp,
      ),
    );

    if (recentActivities.length > 5) {
      recentActivities = recentActivities.sublist(0, 5);
    }

    String formatTime(Timestamp ts) {
      final dt = ts.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.track_changes_rounded,
                            size: 17,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Folder Progress',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6AAF3D), Color(0xFF4A8A24)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6AAF3D).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$percentInt%',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        width: double.infinity,
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      ),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6AAF3D), Color(0xFF81B655)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: (percent >= 1.0
                            ? const Color(0xFF10B981)
                            : (percent > 0 ? AppColors.primary : const Color(0xFF6366F1)))
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (percent >= 1.0
                              ? const Color(0xFF10B981)
                              : (percent > 0 ? AppColors.primary : const Color(0xFF6366F1)))
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        percent >= 1.0 ? '🏆' : (percent > 0.5 ? '🔥' : (percent > 0 ? '⚡' : '🚀')),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          percent >= 1.0
                              ? 'All materials completed! Excellent job!'
                              : (percent >= 0.5
                                  ? 'More than halfway! Keep the momentum!'
                                  : (percent > 0
                                      ? 'Good progress! Keep learning!'
                                      : 'Ready to level up? Start reading!')),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (percent >= 1.0 && totalItems > 0) ...[
                      const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '$completedCount / $totalItems Materials Completed',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            size: 17,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Activity',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    if (recentActivities.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${recentActivities.length} recent',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (recentActivities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_stories_rounded,
                              size: 32,
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your Learning Journey Starts Here!',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pick any lesson above to begin learning.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentActivities.length,
                    separatorBuilder: (c, i) => Divider(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        height: 16),
                    itemBuilder: (context, index) {
                      final act = recentActivities[index];
                      final isComp = act['completed'] == true;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (act['lesson'] != null) {
                              NavigationService.instance.goToLesson(context, act['lesson'] as Lesson);
                            } else if (act['item'] != null) {
                              NavigationService.instance.goToContent(context, act['item'] as PublishedContentItem);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isComp
                                        ? AppColors.primary.withValues(alpha: 0.12)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isComp
                                        ? Icons.check_circle_rounded
                                        : Icons.schedule_rounded,
                                    color: isComp ? AppColors.primary : const Color(0xFFF59E0B),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        act['title'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            act['type'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isComp ? AppColors.primary : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '•',
                                            style: TextStyle(
                                              color: isDark ? Colors.white24 : Colors.grey.shade400,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            formatTime(act['timestamp'] as Timestamp),
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
