import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_colors.dart';
import 'lesson_page.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/author_name_widget.dart';

class LessonFolderPage extends StatefulWidget {
  final User user;
  final String title;
  final String pillLabel;
  final List<Lesson> lessons;
  // If true, this is the "Public Content" top folder which contains sub-folders
  final bool isPublicContentFolder;

  const LessonFolderPage({
    super.key,
    required this.user,
    required this.title,
    required this.pillLabel,
    required this.lessons,
    this.isPublicContentFolder = false,
  });

  @override
  State<LessonFolderPage> createState() => _LessonFolderPageState();
}

class _LessonFolderPageState extends State<LessonFolderPage> {
  String _searchQuery = '';
  String _selectedFilter = 'Name'; // Default

  final List<String> _filterOptions = ['Name', 'Create Date'];

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPublicContentFolder) {
      return _buildPublicContentFolder(context);
    }
    return _buildLessonList(context);
  }

  Widget _buildPublicContentFolder(BuildContext context) {
    // Group lessons by author
    final Map<String, List<Lesson>> authorLessons = {};
    for (var lesson in widget.lessons) {
      final key = lesson.createdByUid ?? 'Unknown';
      authorLessons.putIfAbsent(key, () => []).add(lesson);
    }

    // Filter by search query
    final filteredAuthors = authorLessons.keys.where((uid) {
      if (_searchQuery.isEmpty) return true;
      // Search in author name (need to fetch?) or title of lessons
      // Ideally, we search the visible list.
      // For simplicity, we search lesson titles within the author's folder for now as a proxy,
      // or we can allow searching author names if we had them pre-fetched.
      // But author names are async. Let's filter by lesson content match?
      // Or simply filter authors whose lessons match.

      final lessons = authorLessons[uid]!;
      return lessons.any(
        (l) =>
            l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (l.createdByEmail ?? '').toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AppSearchBar(
              hintText: 'Search public lessons...',
              onSearch: (val) => setState(() => _searchQuery = val),
              onFilterPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filter options coming soon!')),
                );
              },
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Center(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: filteredAuthors.map((authorUid) {
                          final lessons = authorLessons[authorUid]!;
                          final authorEmail = lessons.first.createdByEmail;

                          return SizedBox(
                            width: 234, // 50% Bigger card width
                            height: 324, // 50% Bigger card height
                            child: GestureDetector(
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
                              child: GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        CupertinoIcons.folder_solid,
                                        size: 42,
                                        color: AppColors.primaryGreen,
                                      ),
                                      const Spacer(),
                                      AuthorName(
                                        uid: authorUid == 'Unknown'
                                            ? null
                                            : authorUid,
                                        fallbackEmail: authorEmail,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Check out content!',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.withOpacity(0.5),
                                          ),
                                        ),
                                        child: Text(
                                          'Public',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonList(BuildContext context) {
    final filteredLessons = widget.lessons.where((l) {
      if (_searchQuery.isEmpty) return true;
      return l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (l.createdByEmail ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();

    // Apply sorting based on filter
    filteredLessons.sort((a, b) {
      int cmp = 0;
      if (_selectedFilter == 'Name') {
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      } else if (_selectedFilter == 'Create Date') {
        final tsA = a.createdAt;
        final tsB = b.createdAt;
        if (tsA == null && tsB == null) {
          cmp = 0;
        } else if (tsA == null) {
          cmp = 1;
        } else if (tsB == null) {
          cmp = -1;
        } else {
          cmp = tsB.compareTo(tsA); // Newest first
        }
      }

      if (cmp == 0) {
        // Secondary sort by Name A-Z
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return cmp;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, Map<String, dynamic>>>(
        stream: DatabaseService.instance.progressStream(widget.user),
        builder: (context, progressSnap) {
          final progress = progressSnap.data ?? const {};

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              final listWidget = Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppSearchBar(
                      hintText: 'Search lessons...',
                      onSearch: (val) => setState(() => _searchQuery = val),
                      onFilterPressed: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (context) => CupertinoActionSheet(
                            title: const Text('Filter Lessons By'),
                            actions: _filterOptions.map((option) {
                              return CupertinoActionSheetAction(
                                onPressed: () {
                                  setState(() {
                                    _selectedFilter = option;
                                  });
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: _selectedFilter == option
                                        ? AppColors.primaryGreen
                                        : null,
                                    fontWeight: _selectedFilter == option
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                            cancelButton: CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(context),
                              isDestructiveAction: true,
                              child: const Text('Cancel'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: filteredLessons.isEmpty
                        ? const Center(child: Text('No lessons found.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredLessons.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final lesson = filteredLessons[index];
                              final pData = progress[lesson.id];
                              final done = pData?['completed'] == true;
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
                                              AuthorName(
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
                          ),
                  ),
                ],
              );

              final metricsWidget = _buildMetricsSection(
                context,
                widget.lessons,
                progress,
                isWide,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: listWidget),
                    Container(
                      width: 350,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                      ),
                      child: metricsWidget,
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Expanded(child: listWidget),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border(
                          top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: metricsWidget,
                    ),
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMetricsSection(
    BuildContext context,
    List<Lesson> lessons,
    Map<String, dynamic> progress,
    bool isWide,
  ) {
    int completedCount = 0;
    List<Map<String, dynamic>> recentlyCompleted = [];

    for (var l in lessons) {
      final p = progress[l.id];
      if (p != null && p['completed'] == true) {
        completedCount++;
        Timestamp? ts = p['completedAt'] as Timestamp?;
        recentlyCompleted.add({
          'title': l.title,
          'completedAt': ts ?? Timestamp.now(), // Fallback
        });
      }
    }

    double percent = lessons.isEmpty ? 0 : completedCount / lessons.length;
    recentlyCompleted.sort(
      (a, b) => (b['completedAt'] as Timestamp).compareTo(
        a['completedAt'] as Timestamp,
      ),
    );

    // Take top 5
    if (recentlyCompleted.length > 5) {
      recentlyCompleted = recentlyCompleted.sublist(0, 5);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Folder Progress',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: Stack(
                children: [
                  Center(
                    child: CircularProgressIndicator(
                      value: percent,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      color: AppColors.primaryGreen,
                      strokeWidth: 6,
                    ),
                  ),
                  Center(
                    child: Text(
                      '${(percent * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedCount / ${lessons.length} Completed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  completedCount == lessons.length
                      ? 'All done! Great job!'
                      : 'Keep going!',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Recent Activity',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (recentlyCompleted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No activity yet.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...recentlyCompleted.map((item) {
            final date = (item['completedAt'] as Timestamp).toDate().toLocal();
            final dateStr =
                '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    size: 14,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['title'],
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
