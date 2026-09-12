import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/author_name_widget.dart';
import '../pages/lesson_page.dart';
import '../models/published_content_item.dart';
import '../models/notebook_models.dart';
import 'content_viewer_page.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';


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
  final String _selectedFilter = 'Name'; // Default
  String _selectedMediaFilter = 'All'; // Media filter: All, Lessons, Flashcards, etc.



  final _searchController = TextEditingController();
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = DatabaseService.instance.progressStream(widget.user);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onBack != null) {
      return _buildContent(context);
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
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.isPublicContentFolder) {
      return _buildPublicContentBody(context);
    }
    return _buildLessonListBody(context);
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

    return Column(
      children: [
        if (widget.onBack != null)
          Padding(
            padding: EdgeInsets.fromLTRB(24, widget.onBack != null ? 24 : 100, 24, 0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: widget.onBack != null ? 24 : 100, horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width > 800
                    ? 500
                    : double.infinity,
              ),
              child: AppSearchBar(
                hintText: 'Search educator content...',
                onSearch: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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

                  return SizedBox(
                    width: 260,
                    height: 300,
                    child: Card(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
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
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.folder_rounded,
                                  size: 32,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              AuthorName(
                                uid: authorUid == 'Unknown'
                                    ? null
                                    : authorUid,
                                fallbackEmail: authorEmail,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalCount learning materials available',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Educator',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaFilterChips(bool isDark) {
    final filters = [
      'All',
      'Lessons',
      'Flashcards',
      'Mind Maps',
      'Study Guides',
      'Timelines',
      'Briefings',
      'FAQs',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedMediaFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMediaFilter = filter),
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
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLessonListBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredLessons = widget.lessons.where((l) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return l.title.toLowerCase().contains(q) ||
          (l.createdByEmail ?? '').toLowerCase().contains(q);
    }).toList();

    final filteredPublished = widget.publishedItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.title.toLowerCase().contains(q) ||
          (item.createdByEmail ?? '').toLowerCase().contains(q);
    }).toList();

    filteredLessons.sort((a, b) {
      int cmp = 0;
      if (_selectedFilter == 'Name') {
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      } else if (_selectedFilter == 'Create Date') {
        final tsA = a.createdAt;
        final tsB = b.createdAt;
        cmp = tsA == null && tsB == null
            ? 0
            : tsA == null
                ? 1
                : tsB == null
                    ? -1
                    : tsB.compareTo(tsA);
      }
      return cmp == 0
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : cmp;
    });

    filteredPublished.sort((a, b) {
      int cmp = 0;
      if (_selectedFilter == 'Name') {
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      } else if (_selectedFilter == 'Create Date') {
        final tsA = a.createdAt;
        final tsB = b.createdAt;
        cmp = tsA == null && tsB == null
            ? 0
            : tsA == null
                ? 1
                : tsB == null
                    ? -1
                    : tsB.compareTo(tsA);
      }
      return cmp == 0
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : cmp;
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

    final showLessons =
        _selectedMediaFilter == 'All' || _selectedMediaFilter == 'Lessons';
    final showFlashcards =
        _selectedMediaFilter == 'All' || _selectedMediaFilter == 'Flashcards';
    final showMindMaps =
        _selectedMediaFilter == 'All' || _selectedMediaFilter == 'Mind Maps';
    final showStudyGuides =
        _selectedMediaFilter == 'All' || _selectedMediaFilter == 'Study Guides';
    final showTimelines =
        _selectedMediaFilter == 'All' || _selectedMediaFilter == 'Timelines';
    final showBriefings =
        _selectedMediaFilter == 'All' || _selectedMediaFilter == 'Briefings';
    final showFaqs =
        _selectedMediaFilter == 'All' || _selectedMediaFilter == 'FAQs';

    final hasAnyItems = (showLessons && filteredLessons.isNotEmpty) ||
        (showFlashcards && flashcards.isNotEmpty) ||
        (showMindMaps && mindMaps.isNotEmpty) ||
        (showStudyGuides && studyGuides.isNotEmpty) ||
        (showTimelines && timelines.isNotEmpty) ||
        (showBriefings && briefings.isNotEmpty) ||
        (showFaqs && faqs.isNotEmpty);

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
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onBack,
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back_ios_rounded,
                                  size: 16,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary),
                              const SizedBox(width: 4),
                              Text('Back to Hubs',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      28, widget.onBack != null ? 16 : 100, 28, 0),
                  child: Center(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search materials, lessons, flashcards...',
                      hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : AppColors.textSecondary),
                      suffixIcon: Icon(Icons.search_rounded,
                          color: isDark
                              ? Colors.white70
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
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                    ),
                  ),
                ),
                _buildMediaFilterChips(isDark),
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

            final contentBlock = !hasAnyItems
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No materials found.',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary)),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showLessons && filteredLessons.isNotEmpty)
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
                              );
                            }).toList(),
                          ),
                        if (showFlashcards && flashcards.isNotEmpty)
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
                              );
                            }).toList(),
                          ),
                        if (showMindMaps && mindMaps.isNotEmpty)
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
                              );
                            }).toList(),
                          ),
                        if (showStudyGuides && studyGuides.isNotEmpty)
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
                              );
                            }).toList(),
                          ),
                        if (showTimelines && timelines.isNotEmpty)
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
                              );
                            }).toList(),
                          ),
                        if (showBriefings && briefings.isNotEmpty)
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
                              );
                            }).toList(),
                          ),
                        if (showFaqs && faqs.isNotEmpty)
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
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );

            final metricsBlock = _buildMetricsSection(
                context, widget.lessons, widget.publishedItems, progress);

            if (isWide) {
              return Column(
                children: [
                  headerBlock,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: contentBlock),
                        SizedBox(
                          width: 260,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(0, 0, 24, 32),
                            child: metricsBlock,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  headerBlock,
                  Expanded(child: contentBlock),
                  Padding(
                      padding: const EdgeInsets.all(24), child: metricsBlock),
                ],
              );
            }
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color iconColor = const Color(0xFFE8B84B); // Default Gold for Grammatica
    if (widget.pillLabel == 'Public' ||
        widget.pillLabel == 'Public Lessons' ||
        widget.pillLabel == 'Educator Content' ||
        widget.pillLabel == 'Educator') {
      iconColor = const Color(0xFFE6625B); // Salmon Red for Educator/Public
    }

    return SizedBox(
      width: 200,
      height: 280,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonPage(user: widget.user, lesson: lesson),
            ),
          );
        },
        child: Card(
          elevation: 0,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.menu_book_rounded,
                          color: iconColor, size: 22),
                    ),
                    if (completed)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 20,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LESSON',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: iconColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  lesson.title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'by: ${authorLabel ?? lesson.createdByEmail ?? 'Unknown'}',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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

    return SizedBox(
      width: 200,
      height: 280,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ContentViewerPage(
                user: widget.user,
                item: item,
              ),
            ),
          );
        },
        child: Card(
          elevation: 0,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                      child: Icon(typeIcon, color: typeColor, size: 22),
                    ),
                    if (completed)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 20,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  'by: ${authorLabel ?? item.createdByEmail ?? 'Grammatica'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    List<Map<String, dynamic>> recentlyCompleted = [];

    for (var l in lessons) {
      final p = progress[l.id];
      if (p != null && p['completed'] == true) {
        completedCount++;
        Timestamp? ts = p['completedAt'] as Timestamp?;
        recentlyCompleted.add({
          'title': l.title,
          'completedAt': ts ?? Timestamp.now(),
        });
      }
    }

    for (var item in publishedItems) {
      final p = progress[item.id];
      if (p != null && p['completed'] == true) {
        completedCount++;
        Timestamp? ts = p['completedAt'] as Timestamp?;
        recentlyCompleted.add({
          'title': item.title,
          'completedAt': ts ?? Timestamp.now(),
        });
      }
    }

    final totalItems = lessons.length + publishedItems.length;
    double percent = totalItems == 0 ? 0 : completedCount / totalItems;
    recentlyCompleted.sort(
      (a, b) => (b['completedAt'] as Timestamp).compareTo(
        a['completedAt'] as Timestamp,
      ),
    );

    if (recentlyCompleted.length > 5) {
      recentlyCompleted = recentlyCompleted.sublist(0, 5);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Folder Progress',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$completedCount / $totalItems Materials Completed',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                if (recentlyCompleted.isEmpty)
                  Text('No recent activities...',
                      style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentlyCompleted.length,
                    separatorBuilder: (c, i) => Divider(
                        color: isDark ? Colors.grey[800] : AppColors.divider),
                    itemBuilder: (context, index) {
                      final item = recentlyCompleted[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['title'],
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
