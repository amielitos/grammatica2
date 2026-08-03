import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/author_name_widget.dart';
import '../pages/lesson_page.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';


class LessonFolderPage extends StatefulWidget {
  final User user;
  final String title;
  final String pillLabel;
  final List<Lesson> lessons;
  // If true, this is the "Public Content" top folder which contains sub-folders
  final bool isPublicContentFolder;

  final VoidCallback? onBack;

  const LessonFolderPage({
    super.key,
    required this.user,
    required this.title,
    required this.pillLabel,
    required this.lessons,
    this.isPublicContentFolder = false,
    this.onBack,
  });

  @override
  State<LessonFolderPage> createState() => _LessonFolderPageState();
}

class _LessonFolderPageState extends State<LessonFolderPage> {
  String _searchQuery = '';
  final String _selectedFilter = 'Name'; // Default



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
      backgroundColor: Colors.transparent,
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
    // Group lessons by author
    final Map<String, List<Lesson>> authorLessons = {};
    for (var lesson in widget.lessons) {
      final key = lesson.createdByUid ?? 'Unknown';
      authorLessons.putIfAbsent(key, () => []).add(lesson);
    }

    // Filter by search query
    final filteredAuthors = authorLessons.keys.where((uid) {
      if (_searchQuery.isEmpty) return true;
      final lessons = authorLessons[uid]!;
      return lessons.any(
        (l) =>
            l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (l.createdByEmail ?? '').toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
      );
    }).toList();

    return Column(
      children: [
        if (widget.onBack != null)
          Padding(
            padding: EdgeInsets.fromLTRB(24, widget.onBack != null ? 24 : 100, 24, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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
                hintText: 'Search public lessons...',
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
                  final lessons = authorLessons[authorUid]!;
                  final authorEmail = lessons.first.createdByEmail;

                  return Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LessonFolderPage(
                              user: widget.user,
                              title: 'Public Lessons',
                              pillLabel: 'Public',
                              lessons: lessons,
                              isPublicContentFolder: false,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: 260,
                        height: 300,
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
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check out content!',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
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
                                child: Text(
                                  '${lessons.length} Lesson${lessons.length == 1 ? "" : "s"}',
                                  style: const TextStyle(
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

  Widget _buildLessonListBody(BuildContext context) {
    final filteredLessons = widget.lessons.where((l) {
      if (_searchQuery.isEmpty) return true;
      return l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (l.createdByEmail ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
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

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: _progressStream,
      builder: (context, progressSnap) {
        final progress = progressSnap.data ?? const {};

        // Group lessons by inferred category
        final Map<String, List<Lesson>> grouped = {};
        for (final lesson in filteredLessons) {
          final cat = _inferCategory(lesson.title);
          grouped.putIfAbsent(cat, () => []).add(lesson);
        }
        const categoryOrder = ['Grammar', 'Reading', 'Vocabulary', 'Writing', 'General'];
        final sortedKeys = [
          ...categoryOrder.where((c) => grouped.containsKey(c)),
          ...grouped.keys.where((k) => !categoryOrder.contains(k)),
        ];

        final authorLabel = (widget.pillLabel == 'From Grammatica' || widget.pillLabel == 'Grammatica')
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
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back_ios_rounded, size: 16, color: AppColors.textPrimary),
                              SizedBox(width: 4),
                              Text('Back to Folders',
                                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(28, widget.onBack != null ? 16 : 100, 28, 0),
                  child: Center(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search lesson..',
                      hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textSecondary),
                      suffixIcon: Icon(Icons.search_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textSecondary),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333333) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    ),
                  ),
                ),
              ],
            );

            final lessonsBlock = filteredLessons.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No lessons found.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cat in sortedKeys) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Lessons in $cat',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: grouped[cat]!.map((lesson) {
                              final completed = progress[lesson.id]?['completed'] == true;
                              return _buildSmallLessonCard(
                                context,
                                lesson: lesson,
                                completed: completed,
                                authorLabel: authorLabel,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );

            final metricsBlock = _buildMetricsSection(context, widget.lessons, progress);

            if (isWide) {
              return Column(
                children: [
                  headerBlock,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: lessonsBlock),
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
                  Expanded(child: lessonsBlock),
                  Padding(padding: const EdgeInsets.all(24), child: metricsBlock),
                ],
              );
            }
          },
        );
      },
    );
  }

  String _inferCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('grammar') || t.contains('verb') || t.contains('tense') ||
        t.contains('noun') || t.contains('adjective') || t.contains('adverb') ||
        t.contains('pronoun') || t.contains('conjunction') ||
        t.contains('preposition') || t.contains('parts of speech')) {
      return 'Grammar';
    }
    if (t.contains('reading') || t.contains('comprehension') ||
        t.contains('inference') || t.contains('main idea') ||
        t.contains('supporting') || t.contains('context clue')) {
      return 'Reading';
    }
    if (t.contains('vocabulary') || t.contains('word') ||
        t.contains('synonym') || t.contains('antonym') ||
        t.contains('definition') || t.contains('spelling')) {
      return 'Vocabulary';
    }
    if (t.contains('writing') || t.contains('essay') || t.contains('paragraph') ||
        t.contains('composition') || t.contains('structure') ||
        t.contains('organization') || t.contains('sentence')) {
      return 'Writing';
    }
    return 'General';
  }

  Widget _buildSmallLessonCard(
    BuildContext context, {
    required Lesson lesson,
    required bool completed,
    String? authorLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine icon color based on folder type
    Color iconColor = const Color(0xFFE8B84B); // Default Gold for Grammatica
    if (widget.pillLabel == 'Public' || widget.pillLabel == 'Public Lessons') {
      iconColor = const Color(0xFFE6625B); // Salmon Red for Public
    }

    return SizedBox(
      width: 200,
      height: 280, // Even taller, giving a more pronounced portrait format that feels larger overall
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
          color: isDark ? const Color(0xFF333333) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(24), // Increased padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Icon(Icons.menu_book_rounded, color: iconColor, size: 28),
                    if (completed)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 14),
                      ),
                  ],
                ),
                const Spacer(), // Use Spacer to push text to the bottom
                Text(
                  lesson.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'by: ${authorLabel ?? lesson.createdByEmail ?? 'Unknown'}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : AppColors.textSecondary),
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

    double percent = lessons.isEmpty ? 0 : completedCount / lessons.length;
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Folder Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
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
                  '$completedCount / ${lessons.length} Lessons Completed',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                if (recentlyCompleted.isEmpty)
                  Text('No recent activities...', style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentlyCompleted.length,
                    separatorBuilder: (c, i) => Divider(color: isDark ? Colors.grey[800] : AppColors.divider),
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
                                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
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
