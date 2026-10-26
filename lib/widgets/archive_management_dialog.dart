import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../theme/app_colors.dart';

class ArchiveManagementDialog extends StatefulWidget {
  final UserRole role;
  const ArchiveManagementDialog({super.key, required this.role});

  @override
  State<ArchiveManagementDialog> createState() => _ArchiveManagementDialogState();
}

class _ArchiveManagementDialogState extends State<ArchiveManagementDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _calculateDaysRemaining(dynamic purgeAt, dynamic archivedAt) {
    DateTime targetDate;
    if (purgeAt != null && purgeAt is DateTime) {
      targetDate = purgeAt;
    } else if (purgeAt != null) {
      targetDate = purgeAt.toDate();
    } else if (archivedAt != null) {
      final aDate = (archivedAt is DateTime) ? archivedAt : archivedAt.toDate();
      targetDate = aDate.add(const Duration(days: 30));
    } else {
      targetDate = DateTime.now().add(const Duration(days: 30));
    }

    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuperAdmin = widget.role == UserRole.superadmin;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE05050).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.archive_outlined, color: Color(0xFFE05050), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Content Archive',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'After 30 days, the content will be permanently deleted from Grammatica.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(Icons.auto_stories_rounded, size: 18), text: 'Archived Lessons'),
                  Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: 'Archived Quizzes'),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildArchivedLessonsTab(isDark, isSuperAdmin),
                    _buildArchivedQuizzesTab(isDark, isSuperAdmin),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedLessonsTab(bool isDark, bool isSuperAdmin) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamArchivedLessons(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No archived lessons',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final lesson = items[index];
            final daysRemaining = _calculateDaysRemaining(lesson.purgeAt, lesson.archivedAt);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$daysRemaining days remaining',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                            if (lesson.createdByEmail != null && lesson.createdByEmail!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• ${lesson.createdByEmail}',
                                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () async {
                      await DatabaseService.instance.restoreLesson(lesson.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lesson "${lesson.title}" restored successfully')),
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF81B655)),
                    label: const Text('Restore', style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold)),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Purge Immediately?'),
                            content: Text('Permanently purge "${lesson.title}" from storage right now?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE05050)),
                                child: const Text('Purge Now'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await DatabaseService.instance.permanentlyDeleteLessonPackage(lesson: lesson);
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Color(0xFFE05050)),
                      label: const Text('Purge Now', style: TextStyle(color: Color(0xFFE05050), fontWeight: FontWeight.bold)),
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

  Widget _buildArchivedQuizzesTab(bool isDark, bool isSuperAdmin) {
    return StreamBuilder<List<Quiz>>(
      stream: DatabaseService.instance.streamArchivedQuizzes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No archived quizzes',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final quiz = items[index];
            final daysRemaining = _calculateDaysRemaining(quiz.purgeAt, quiz.archivedAt);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$daysRemaining days remaining',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                            if (quiz.createdByEmail != null && quiz.createdByEmail!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• ${quiz.createdByEmail}',
                                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () async {
                      await DatabaseService.instance.restoreQuiz(quiz.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Quiz "${quiz.title}" restored successfully')),
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF81B655)),
                    label: const Text('Restore', style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold)),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Purge Immediately?'),
                            content: Text('Permanently purge "${quiz.title}" from storage right now?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE05050)),
                                child: const Text('Purge Now'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await DatabaseService.instance.deleteQuiz(quiz.id);
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Color(0xFFE05050)),
                      label: const Text('Purge Now', style: TextStyle(color: Color(0xFFE05050), fontWeight: FontWeight.bold)),
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
}
