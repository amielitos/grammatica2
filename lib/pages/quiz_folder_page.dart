import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_colors.dart';
import '../widgets/animations.dart';
import 'quiz_detail_page.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/author_name_widget.dart';

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

    return Container(
      decoration: BoxDecoration(gradient: AppColors.getMainGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.isPublicContentFolder) {
      return _buildPublicContentBody(context);
    }
    return _buildQuizListBody(context);
  }

  Widget _buildPublicContentBody(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
                maxWidth: MediaQuery.of(context).size.width > 600
                    ? MediaQuery.of(context).size.width * 0.6
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: filteredAuthors.asMap().entries.map((entry) {
                      final index = entry.key;
                      final authorUid = entry.value;
                      final quizzes = authorQuizzes[authorUid]!;
                      final authorEmail = quizzes.first.createdByEmail;

                      return FadeInSlide(
                        delay: Duration(milliseconds: index * 100),
                        child: HoverScale(
                          scale: 1.0, // Stable size on hover
                          child: GestureDetector(
                            onTap: () {
                              if (widget.onBack != null) {
                                // In embedded mode, maybe we need to push a sub-folder?
                                // For now, let's just push normally if it's a sub-folder,
                                // but the top level is what persists the burger.
                              }
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
                            child: GlassCard(
                              width: 240,
                              height: 320,
                              isSolid: true,
                              backgroundColor: AppColors.getCardColor(context),
                              hoverBorderColor: Colors.yellow,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.folder,
                                      size: 48,
                                      color: Colors.blue,
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
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.blue.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Public',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
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
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuizListBody(BuildContext context) {
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
      stream: DatabaseService.instance.quizProgressStream(widget.user),
      builder: (context, progressSnap) {
        final progress = progressSnap.data ?? const {};

        return Column(
          children: [
            if (widget.onBack != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                    maxWidth: MediaQuery.of(context).size.width > 600
                        ? MediaQuery.of(context).size.width * 0.6
                        : double.infinity,
                    minWidth: MediaQuery.of(context).size.width > 600
                        ? 0
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
                                      ? Colors.yellow
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
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final listBlock = filteredQuizzes.isEmpty
                      ? const Center(child: Text('No quizzes found.'))
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

                            return FadeInSlide(
                              delay: Duration(milliseconds: index * 50),
                              child: HoverScale(
                                scale: 1.0, // Stable size on hover
                                child: GlassCard(
                                  isSolid: true,
                                  backgroundColor: AppColors.getCardColor(
                                    context,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => QuizDetailPage(
                                          user: widget.user,
                                          quiz: quiz,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.quiz,
                                        color: Colors.yellow,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              quiz.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${quiz.questions.length} Questions • Max Attempts: $max',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (completed)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 28,
                                        )
                                      else if (failed)
                                        const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                          size: 28,
                                        )
                                      else
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.yellow,
                                          size: 20,
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
        GlassCard(
          isSolid: true,
          backgroundColor: AppColors.getCardColor(context),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Folder Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.yellow,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$completedCount / ${quizzes.length} Quizzes Completed',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Success Rate',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(passRate * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.yellow,
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
        GlassCard(
          isSolid: true,
          backgroundColor: AppColors.getCardColor(context),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (recentlyCompleted.isEmpty)
                  const Text(
                    'No activity yet.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentlyCompleted.length,
                    separatorBuilder: (c, i) =>
                        Divider(color: Colors.grey[100]),
                    itemBuilder: (context, index) {
                      final item = recentlyCompleted[index];
                      final success = item['success'] as bool;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              success ? Icons.check_circle : Icons.error,
                              color: success ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['title'],
                                style: const TextStyle(fontSize: 14),
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
