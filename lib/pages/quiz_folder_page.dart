import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/author_name_widget.dart';
import '../pages/quiz_detail_page.dart';
import '../theme/app_colors.dart';

class QuizFolderPage extends StatefulWidget {
  final User user;
  final String title;
  final String pillLabel;
  final List<Quiz> quizzes;
  // If true, this is the "Public Content" top folder which contains sub-folders
  final bool isPublicContentFolder;

  const QuizFolderPage({
    super.key,
    required this.user,
    required this.title,
    required this.pillLabel,
    required this.quizzes,
    this.isPublicContentFolder = false,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  State<QuizFolderPage> createState() => _QuizFolderPageState();
}

class _QuizFolderPageState extends State<QuizFolderPage> {
  String _searchQuery = '';
  String _selectedFilter = 'Name'; // Default

  final List<String> _filterOptions = ['Name', 'Create Date'];

  final _searchController = TextEditingController();
  late Stream<Map<String, Map<String, dynamic>>> _progressStream;

  @override
  void initState() {
    super.initState();
    _progressStream = DatabaseService.instance.quizProgressStream(widget.user);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
        ),
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.isPublicContentFolder) {
      return _buildPublicContentBody(context);
    }
    return _buildQuizListBody(context);
  }

  Widget _buildPublicContentBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Group quizzes by author
    final Map<String, List<Quiz>> authorQuizzes = {};
    for (var quiz in widget.quizzes) {
      final key = quiz.createdByUid ?? 'Unknown';
      authorQuizzes.putIfAbsent(key, () => []).add(quiz);
    }

    // Filter by search query
    final filteredAuthors = authorQuizzes.keys.where((uid) {
      if (_searchQuery.isEmpty) return true;
      final quizzes = authorQuizzes[uid]!;
      return quizzes.any(
        (q) =>
            q.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (q.createdByEmail ?? '').toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
      );
    }).toList();

    return Column(
      children: [
        if (widget.onBack != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width > 800
                    ? 500
                    : double.infinity,
              ),
              child: AppSearchBar(
                hintText: 'Search public quizzes...',
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
                  final quizzes = authorQuizzes[authorUid]!;
                  final authorEmail = quizzes.first.createdByEmail;

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
                              builder: (_) => QuizFolderPage(
                                user: widget.user,
                                title: 'Public Quizzes',
                                pillLabel: 'Public',
                                quizzes: quizzes,
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
                                'Check out content!',
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
                                  'Public',
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

  Widget _buildQuizListBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredQuizzes = widget.quizzes.where((q) {
      if (_searchQuery.isEmpty) return true;
      return q.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (q.createdByEmail ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();

    filteredQuizzes.sort((a, b) {
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
          cmp = tsB.compareTo(tsA);
        }
      }
      return cmp == 0
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : cmp;
    });

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: _progressStream,
      builder: (context, progressSnap) {
        final progress = progressSnap.data ?? const {};

        return Column(
          children: [
            if (widget.onBack != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width > 800
                        ? 500
                        : double.infinity,
                  ),
                  child: AppSearchBar(
                    hintText: 'Search quizzes...',
                    onSearch: (val) => setState(() => _searchQuery = val),
                    onFilterPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (context) => CupertinoActionSheet(
                          title: const Text('Filter Quizzes By'),
                          actions: _filterOptions.map((option) {
                            return CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _selectedFilter = option);
                                Navigator.pop(context);
                              },
                              child: Text(
                                option,
                                style: TextStyle(
                                  color: _selectedFilter == option
                                      ? AppColors.primary
                                      : (isDark ? Colors.white : AppColors.textPrimary),
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
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final listBlock = filteredQuizzes.isEmpty
                      ? const Center(child: Text('No quizzes found.', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: filteredQuizzes.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final quiz = filteredQuizzes[index];
                            final progData = progress[quiz.id];
                            final completed = progData?['completed'] == true;
                            final isCorrect = progData?['isCorrect'] == true;
                            final attempts =
                                (progData?['attemptsUsed'] as int?) ?? 0;
                            final max = quiz.maxAttempts;
                            bool failed = !isCorrect && attempts >= max;

                            return Card(
                              elevation: 0,
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => QuizDetailPage(
                                        user: widget.user,
                                        quiz: quiz,
                                        notebookId: quiz.notebookId,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                          Icons.quiz_rounded,
                                          color: AppColors.primary,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              quiz.title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${quiz.questions.length} Questions • Max Attempts: $max',
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (completed)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.green,
                                          size: 28,
                                        )
                                      else if (failed)
                                        const Icon(
                                          Icons.error_rounded,
                                          color: Colors.redAccent,
                                          size: 28,
                                        )
                                      else
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );

                  final metricsBlock = _buildMetricsSection(
                    context,
                    widget.quizzes,
                    progress,
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: listBlock),
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(
                              right: 24,
                              top: 24,
                              bottom: 24,
                            ),
                            child: metricsBlock,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        Expanded(child: listBlock),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: metricsBlock,
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricsSection(
    BuildContext context,
    List<Quiz> quizzes,
    Map<String, dynamic> progress,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int completedCount = 0;
    int passedCount = 0;
    List<Map<String, dynamic>> recentlyCompleted = [];

    for (var q in quizzes) {
      final p = progress[q.id];
      if (p != null && p['completed'] == true) {
        completedCount++;
        if (p['isCorrect'] == true) {
          passedCount++;
        }
        Timestamp? ts = p['completedAt'] as Timestamp?;
        recentlyCompleted.add({
          'title': q.title,
          'completedAt': ts ?? Timestamp.now(),
          'success': p['isCorrect'] == true,
        });
      }
    }

    double percent = quizzes.isEmpty ? 0 : completedCount / quizzes.length;
    double passRate = completedCount == 0 ? 0 : passedCount / completedCount;

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
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
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
                  '$completedCount / ${quizzes.length} Quizzes Completed',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Success Rate',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                    ),
                    Text(
                      '${(passRate * 100).toInt()}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
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
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
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
                  Text('No activity yet.', style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentlyCompleted.length,
                    separatorBuilder: (c, i) => Divider(color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final item = recentlyCompleted[index];
                      final success = item['success'] as bool;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              success ? Icons.check_circle_rounded : Icons.error_rounded,
                              color: success
                                  ? Colors.green
                                  : Colors.redAccent,
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
