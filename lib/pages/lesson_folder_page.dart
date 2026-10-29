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
import '../widgets/sti_modules_view.dart';

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
  String _selectedDateFilter = 'All Materials'; // Filter: All Materials, Not Started, In Progress, Completed ✓
  bool _sortNewestFirst = true;
  bool _showAllSections = false;
  final Set<String> _expandedModuleIds = {};
  int _currentLessonPage = 1;
  static const int _pageSize = 10;

  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;
  late Stream<Map<String, Map<String, dynamic>>> _quizProgressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = DatabaseService.instance.progressStream(widget.user);
    _quizProgressStream = DatabaseService.instance.quizProgressStream(widget.user);
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
        onLogoTap: () {
          widget.onBack?.call();
          return true;
        },
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: AppSearchBar(
                  hintText: 'Search educator lessons...',
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
                                    title: 'Educator Lessons',
                                    pillLabel: 'Educator Lessons',
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
                                              'Explore Lessons',
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
    final authorUid = widget.lessons.isNotEmpty ? widget.lessons.first.createdByUid : null;
    final authorEmail = widget.lessons.isNotEmpty ? widget.lessons.first.createdByEmail : null;
    final folderTitle = widget.title.isNotEmpty ? widget.title : 'Educator Lessons';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, widget.onBack != null ? 14 : 20, 24, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onBack != null || Navigator.of(context).canPop())
                    MouseRegion(
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
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_rounded,
                                  size: 15,
                                  color: isDark ? Colors.white70 : const Color(0xFF0F172A)),
                              const SizedBox(width: 6),
                              Text(
                                'Back to Dashboard',
                                style: GoogleFonts.inter(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGrammatica
                          ? const Color(0xFF81B655).withValues(alpha: 0.12)
                          : const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isGrammatica
                            ? const Color(0xFF81B655).withValues(alpha: 0.3)
                            : const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isGrammatica ? '✨ OFFICIAL CURRICULUM' : '🌟 COMMUNITY HUB',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isGrammatica
                            ? const Color(0xFF81B655)
                            : const Color(0xFFEF4444),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '$itemCount Materials',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Educator Public Folder Header (Requirement 7)
          if (!isGrammatica && !widget.isPublicContentFolder) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.school_rounded, color: Color(0xFF3B82F6), size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: (authorUid != null && authorUid != 'Unknown')
                                  ? AuthorName(
                                      uid: authorUid,
                                      fallbackEmail: authorEmail,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    )
                                  : Text(
                                      folderTitle,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, size: 12, color: Color(0xFF3B82F6)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Educator Hub',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Public learning modules and instructional packages published by this educator.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationControls({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int itemsOnPage,
    required bool isDark,
    required Function(int) onPageChange,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 28),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–${startIndex + itemsOnPage} of $totalItems lessons',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: const Text('Prev'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(totalPages, (i) {
                final pageNum = i + 1;
                final isCurrent = pageNum == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => onPageChange(pageNum),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 16),
                label: const Text('Next'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChips(bool isDark) {
    final filters = [
      'All Materials',
      'Not Started',
      'In Progress',
      'Completed ✓',
    ];

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          ...filters.map((filter) {
            final isSelected = _selectedDateFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedDateFilter = filter;
                    _currentLessonPage = 1;
                  }),
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
    ),
  );
  }

  Widget _buildLessonListBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: _progressStream,
      builder: (context, progressSnap) {
        final progress = progressSnap.data ?? const {};
        return StreamBuilder<Map<String, Map<String, dynamic>>>(
          stream: _quizProgressStream,
          builder: (context, quizSnap) {
            final quizProgress = quizSnap.data ?? const {};

            final filteredLessons = widget.lessons.where((l) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matches = l.title.toLowerCase().contains(q) ||
                (l.createdByEmail ?? '').toLowerCase().contains(q) ||
                l.prompt.toLowerCase().contains(q);
            if (!matches) return false;
          }
          final isCompleted = progress[l.id]?['completed'] == true;
          final isStarted = progress[l.id] != null && !isCompleted;
          final isNotStarted = progress[l.id] == null;
          if (_selectedDateFilter == 'Completed ✓') return isCompleted;
          if (_selectedDateFilter == 'In Progress') return isStarted;
          if (_selectedDateFilter == 'Not Started') return isNotStarted;
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

        final hasAnyItems = filteredLessons.isNotEmpty;

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
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(const Duration(milliseconds: 350), () {
                            if (mounted) {
                              setState(() {
                                _searchQuery = val;
                                _currentLessonPage = 1;
                              });
                            }
                          });
                        },
                        onSubmitted: (val) {
                          _debounceTimer?.cancel();
                          setState(() {
                            _searchQuery = val;
                            _currentLessonPage = 1;
                          });
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
                                      setState(() {
                                        _searchQuery = '';
                                        _currentLessonPage = 1;
                                      });
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

            Widget buildStatusLegendItem(IconData icon, String label, Color color) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
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
                  // STI eLMS Inspired Modules Header Bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Modules',
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Modules and sections can be completed in any order.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isMobile)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _showAllSections = !_showAllSections;
                                        if (_showAllSections) {
                                          _expandedModuleIds.addAll(filteredLessons.map((l) => l.id));
                                        } else {
                                          _expandedModuleIds.clear();
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _showAllSections
                                                ? Icons.keyboard_arrow_up_rounded
                                                : Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _showAllSections ? 'Hide sections' : 'Show sections',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  buildStatusLegendItem(Icons.chevron_right_rounded, 'Available', isDark ? Colors.white70 : const Color(0xFF64748B)),
                                  const SizedBox(width: 14),
                                  buildStatusLegendItem(Icons.waves_rounded, 'Partial', const Color(0xFFF59E0B)),
                                  const SizedBox(width: 14),
                                  buildStatusLegendItem(Icons.check_rounded, 'Completed', const Color(0xFF10B981)),
                                ],
                              ),
                          ],
                        ),
                        if (isMobile) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showAllSections = !_showAllSections;
                                    if (_showAllSections) {
                                      _expandedModuleIds.addAll(filteredLessons.map((l) => l.id));
                                    } else {
                                      _expandedModuleIds.clear();
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _showAllSections
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _showAllSections ? 'Hide sections' : 'Show sections',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              buildStatusLegendItem(Icons.chevron_right_rounded, 'Available', isDark ? Colors.white70 : const Color(0xFF64748B)),
                              buildStatusLegendItem(Icons.waves_rounded, 'Partial', const Color(0xFFF59E0B)),
                              buildStatusLegendItem(Icons.check_rounded, 'Completed', const Color(0xFF10B981)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (filteredLessons.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final totalItems = filteredLessons.length;
                        final totalPages = (totalItems / _pageSize).ceil();
                        final safePage = _currentLessonPage > totalPages ? 1 : _currentLessonPage;
                        final startIndex = (safePage - 1) * _pageSize;
                        final pageLessons = filteredLessons.skip(startIndex).take(_pageSize).toList();

                        final pagePublic = pageLessons.where((l) => !l.isMembersOnly).toList();
                        final pageMembers = pageLessons.where((l) => l.isMembersOnly).toList();
                        final hasAnyMembersOnly = filteredLessons.any((l) => l.isMembersOnly);

                        Widget renderCards(List<Lesson> list, int baseOffset) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: list.asMap().entries.map((entry) {
                              final idx = baseOffset + entry.key;
                              final l = entry.value;
                              final completed = progress[l.id]?['completed'] == true;
                              final pVal = completed ? 1.0 : (progress[l.id]?['progress'] as double? ?? 0.0);
                              final quizData = quizProgress[l.quizId ?? l.id];
                              final scoreStr = quizData?['score'] != null ? '${quizData!['score']}%' : null;
                              final isExpanded = _showAllSections || _expandedModuleIds.contains(l.id);

                              return STIModuleCard(
                                index: idx,
                                lesson: l,
                                isCompleted: completed,
                                progress: pVal,
                                isExpanded: isExpanded,
                                quizScore: scoreStr,
                                progressMap: progress,
                                companionItems: widget.publishedItems
                                    .where((item) =>
                                        item.lessonId == l.id ||
                                        (l.notebookId != null && item.notebookId == l.notebookId))
                                    .toList(),
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    if (expanded) {
                                      _expandedModuleIds.add(l.id);
                                    } else {
                                      _expandedModuleIds.remove(l.id);
                                      _showAllSections = false;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasAnyMembersOnly) ...[
                              // Section 1: Public Lessons (Requirement 4)
                              if (pagePublic.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.public_rounded, size: 16, color: Color(0xFF81B655)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Public Lessons',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${filteredLessons.where((l) => !l.isMembersOnly).length}',
                                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                renderCards(pagePublic, startIndex),
                              ],

                              // Section 2: Members-Only Lessons (Requirement 4)
                              if (pageMembers.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 18, bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9B59B6).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF9B59B6)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Members-Only Lessons',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${filteredLessons.where((l) => l.isMembersOnly).length}',
                                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF9B59B6)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                renderCards(pageMembers, startIndex + pagePublic.length),
                              ],
                            ] else ...[
                              renderCards(pageLessons, startIndex),
                            ],

                            // Pagination Controls (Requirement 8: paginate if more than 10 lessons)
                            if (totalItems > _pageSize)
                              _buildPaginationControls(
                                totalItems: totalItems,
                                currentPage: safePage,
                                totalPages: totalPages,
                                startIndex: startIndex,
                                itemsOnPage: pageLessons.length,
                                isDark: isDark,
                                onPageChange: (newPage) {
                                  setState(() => _currentLessonPage = newPage);
                                },
                              ),
                          ],
                        );
                      },
                    ),
                ],
              );
            }

            final metricsBlock = _buildMetricsSection(
                context, widget.lessons, widget.publishedItems, progress, quizProgress);

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
  },
);
  }

  // ignore: unused_element
  Widget _buildSmallLessonCard(
    BuildContext context, {
    required Lesson lesson,
    required bool completed,
    bool isStarted = false,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Completed',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isStarted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.waves_rounded, color: Color(0xFFF59E0B), size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Partial',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 13),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Available',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
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
                                    authorLabel != null
                                        ? Text(
                                            'by: $authorLabel',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF475569),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : AuthorName(
                                            uid: lesson.createdByUid,
                                            fallbackEmail: lesson.createdByEmail,
                                            prefix: 'by: ',
                                            isClickable: true,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF475569),
                                              fontWeight: FontWeight.w500,
                                            ),
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

  // ignore: unused_element
  Widget _buildSmallPublishedItemCard(
    BuildContext context, {
    required PublishedContentItem item,
    required bool completed,
    bool isStarted = false,
    String? authorLabel,
    bool isMobile = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color typeColor;
    IconData typeIcon;
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Completed',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isStarted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.waves_rounded, color: Color(0xFFF59E0B), size: 11),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Partial',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 12),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Available',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
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
                                child: authorLabel != null
                                    ? Text(
                                        'by: $authorLabel',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : AuthorName(
                                        uid: item.createdByUid,
                                        fallbackEmail: item.createdByEmail,
                                        prefix: 'by: ',
                                        isClickable: true,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                        ),
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
    Map<String, dynamic> quizProgress,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int completedCount = 0;
    List<Map<String, dynamic>> recentActivities = [];
    Lesson? nextUncompletedLesson;

    for (var l in lessons) {
      final p = progress[l.id];
      final isCompleted = p != null && p['completed'] == true;
      if (isCompleted) {
        completedCount++;
      } else {
        nextUncompletedLesson ??= l;
      }

      if (p != null) {
        final dynamic rawTs = p['lastReadAt'] ?? p['completedAt'];
        DateTime? parsedDate;
        if (rawTs is Timestamp) {
          parsedDate = rawTs.toDate();
        } else if (rawTs is DateTime) {
          parsedDate = rawTs;
        } else if (rawTs is String) {
          parsedDate = DateTime.tryParse(rawTs);
        } else if (rawTs is int) {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(rawTs);
        } else if (isCompleted) {
          parsedDate = DateTime.now();
        }

        if (parsedDate != null) {
          recentActivities.add({
            'title': l.title,
            'completed': isCompleted,
            'date': parsedDate,
            'lesson': l,
            'type': 'Lesson',
          });
        }
      }
    }

    for (var item in publishedItems) {
      final p = progress[item.id];
      final isCompleted = p != null && p['completed'] == true;
      if (isCompleted) {
        completedCount++;
      }

      if (p != null) {
        final dynamic rawTs = p['lastReadAt'] ?? p['completedAt'];
        DateTime? parsedDate;
        if (rawTs is Timestamp) {
          parsedDate = rawTs.toDate();
        } else if (rawTs is DateTime) {
          parsedDate = rawTs;
        } else if (rawTs is String) {
          parsedDate = DateTime.tryParse(rawTs);
        } else if (rawTs is int) {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(rawTs);
        } else if (isCompleted) {
          parsedDate = DateTime.now();
        }

        if (parsedDate != null) {
          recentActivities.add({
            'title': item.title,
            'completed': isCompleted,
            'date': parsedDate,
            'item': item,
            'type': item.type.displayName,
          });
        }
      }
    }

    final totalItems = lessons.length + publishedItems.length;
    double percent = totalItems == 0 ? 0.0 : (completedCount / totalItems).clamp(0.0, 1.0);
    final percentInt = (percent * 100).toInt();

    recentActivities.sort(
      (a, b) => (b['date'] as DateTime).compareTo(
        a['date'] as DateTime,
      ),
    );

    if (recentActivities.length > 5) {
      recentActivities = recentActivities.sublist(0, 5);
    }

    String formatTime(dynamic raw) {
      DateTime dt;
      if (raw is Timestamp) {
        dt = raw.toDate();
      } else if (raw is DateTime) {
        dt = raw;
      } else if (raw is String) {
        dt = DateTime.tryParse(raw) ?? DateTime.now();
      } else {
        dt = DateTime.now();
      }
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
        // ── STI eLMS: Activity Widget ──
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.waves_rounded, size: 18, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 8),
                  Text(
                    'Activity',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF06B6D4)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.displayName ?? 'A user',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          recentActivities.isNotEmpty
                              ? 'Viewed: ${recentActivities.first['title']}'
                              : 'Viewed modules overview',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (recentActivities.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9), height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentActivities.take(3).length,
                  separatorBuilder: (c, i) => Divider(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    height: 12,
                  ),
                  itemBuilder: (context, index) {
                    final act = recentActivities[index];
                    final isComp = act['completed'] == true;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (act['lesson'] != null) {
                          NavigationService.instance.goToLesson(context, act['lesson'] as Lesson);
                        } else if (act['item'] != null) {
                          NavigationService.instance.goToContent(context, act['item'] as PublishedContentItem);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isComp ? Icons.check_circle_rounded : Icons.schedule_rounded,
                              color: isComp ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                act['title'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatTime(act['date']),
                              style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── STI eLMS: Progress Widget (Circular Gauge) ──
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          child: Column(
            children: [
              Text(
                'Progress',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: CircularProgressIndicator(
                        value: percent.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percent >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF6AAF3D),
                        ),
                      ),
                    ),
                    Text(
                      '$percentInt%',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$completedCount of $totalItems completed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              if (nextUncompletedLesson != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(
                      'Resume: ${nextUncompletedLesson.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                    onPressed: () {
                      NavigationService.instance.goToLesson(context, nextUncompletedLesson!);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── STI eLMS: Grade & Scores Dual Gauges ──
        Builder(
          builder: (context) {
            final folderQuizIds = <String>{};
            for (final l in lessons) {
              if (l.quizId != null && l.quizId!.isNotEmpty) {
                folderQuizIds.add(l.quizId!);
              }
              folderQuizIds.add(l.id);
            }
            for (final item in publishedItems) {
              if (item.type == NotebookOutputType.quiz) {
                folderQuizIds.add(item.id);
              }
            }

            int quizzesTaken = 0;
            double scorePercentageSum = 0.0;

            for (final qId in folderQuizIds) {
              final qp = quizProgress[qId];
              if (qp != null && ((qp['attemptsUsed'] as num? ?? 0) > 0 || qp['score'] != null)) {
                final score = (qp['score'] as num?)?.toDouble() ?? 0.0;
                final total = (qp['totalQuestions'] as num?)?.toDouble() ?? 0.0;
                if (total > 0) {
                  quizzesTaken++;
                  scorePercentageSum += (score / total) * 100.0;
                }
              }
            }

            final String gradeDisplay;
            final String scoresDisplay;
            final double gradeGaugeValue;
            final double scoresGaugeValue;

            if (quizzesTaken == 0) {
              gradeDisplay = '0.0';
              scoresDisplay = '0%';
              gradeGaugeValue = 0.0;
              scoresGaugeValue = 0.0;
            } else {
              final double avgScore = (scorePercentageSum / quizzesTaken).clamp(0.0, 100.0);
              scoresDisplay = '${avgScore.round()}%';
              scoresGaugeValue = (avgScore / 100.0).clamp(0.0, 1.0);

              if (avgScore >= 97.5) {
                gradeDisplay = '1.00';
              } else if (avgScore >= 94.5) {
                gradeDisplay = '1.25';
              } else if (avgScore >= 91.5) {
                gradeDisplay = '1.50';
              } else if (avgScore >= 88.5) {
                gradeDisplay = '1.75';
              } else if (avgScore >= 85.5) {
                gradeDisplay = '2.00';
              } else if (avgScore >= 81.5) {
                gradeDisplay = '2.25';
              } else if (avgScore >= 77.5) {
                gradeDisplay = '2.50';
              } else if (avgScore >= 74.5) {
                gradeDisplay = '2.75';
              } else if (avgScore >= 70.0) {
                gradeDisplay = '3.00';
              } else {
                gradeDisplay = '5.00';
              }
              gradeGaugeValue = (avgScore / 100.0).clamp(0.0, 1.0);
            }

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Grade Circular Gauge
                  Column(
                    children: [
                      Text(
                        'Grade',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 74,
                              height: 74,
                              child: CircularProgressIndicator(
                                value: gradeGaugeValue,
                                strokeWidth: 6,
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  quizzesTaken > 0 ? const Color(0xFF6AAF3D) : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                ),
                              ),
                            ),
                            Text(
                              gradeDisplay,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Scores Circular Gauge
                  Column(
                    children: [
                      Text(
                        'Scores',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 74,
                              height: 74,
                              child: CircularProgressIndicator(
                                value: scoresGaugeValue,
                                strokeWidth: 6,
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scoresGaugeValue >= 0.8
                                      ? const Color(0xFF10B981)
                                      : (scoresGaugeValue > 0 ? const Color(0xFFF59E0B) : (isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                                ),
                              ),
                            ),
                            Text(
                              scoresDisplay,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
