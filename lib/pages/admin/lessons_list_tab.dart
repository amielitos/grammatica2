import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_colors.dart';
import '../lesson_page.dart';

class LessonsListTab extends StatefulWidget {
  final Function(Lesson)? onEdit;
  final Function(Lesson)? onEditQuiz;
  const LessonsListTab({super.key, this.onEdit, this.onEditQuiz});
  @override
  State<LessonsListTab> createState() => _LessonsListTabState();
}

class _LessonsListTabState extends State<LessonsListTab> {
  String _searchQuery = '';
  String _selectedFilter = 'Create Date';
  final List<String> _filterOptions = ['Name', 'Status', 'Create Date'];

  String _formatTs(dynamic ts) {
    if (ts == null) return 'N/A';
    DateTime d;
    if (ts is Timestamp) {
      d = ts.toDate().toLocal();
    } else if (ts is DateTime) {
      d = ts.toLocal();
    } else {
      return 'N/A';
    }
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Color _statusColor(String? status, bool isMembersOnly) {
    if (status == 'awaiting_approval') return const Color(0xFFF5A623);
    if (status == 'rejected') return const Color(0xFFD32F2F);
    if (isMembersOnly) return const Color(0xFF9B59B6);
    return AppColors.primary;
  }

  String _statusLabel(String? status, bool isMembersOnly) {
    if (status == 'awaiting_approval') return 'Pending Review';
    if (status == 'rejected') return 'Rejected';
    if (isMembersOnly) return 'Members Only';
    return 'Published';
  }

  IconData _statusIcon(String? status, bool isMembersOnly) {
    if (status == 'awaiting_approval') return Icons.hourglass_top_rounded;
    if (status == 'rejected') return Icons.cancel_rounded;
    if (isMembersOnly) return Icons.lock_rounded;
    return Icons.check_circle_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<UserRole>(
      stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
      builder: (context, roleSnap) {
        final role = roleSnap.data ?? UserRole.learner;
        final canEdit = role == UserRole.admin || role == UserRole.superadmin || role == UserRole.educator;

        return StreamBuilder<List<Lesson>>(
          stream: DatabaseService.instance.streamLessons(
            approvedOnly: false,
            userRole: role,
            userId: user?.uid,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var lessons = snapshot.data!.toList();

            // Educators only see their own lessons
            if (role == UserRole.educator && user != null) {
              lessons = lessons.where((l) => l.createdByUid == user.uid).toList();
            }

            // Search filter
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              lessons = lessons.where((l) {
                return l.title.toLowerCase().contains(q) ||
                    (l.createdByEmail ?? '').toLowerCase().contains(q);
              }).toList();
            }

            // Sort
            lessons.sort((a, b) {
              if (_selectedFilter == 'Name') {
                return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              } else if (_selectedFilter == 'Status') {
                final order = {'awaiting_approval': 0, 'rejected': 1, 'approved': 2};
                final oa = order[a.validationStatus] ?? 3;
                final ob = order[b.validationStatus] ?? 3;
                return oa.compareTo(ob);
              } else {
                final tsA = a.createdAt;
                final tsB = b.createdAt;
                if (tsA == null && tsB == null) return 0;
                if (tsA == null) return 1;
                if (tsB == null) return -1;
                return tsB.compareTo(tsA);
              }
            });

            return CustomScrollView(
              slivers: [
                // ── Top Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lessons',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${lessons.length} lesson${lessons.length == 1 ? '' : 's'} found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Search + Filter Bar ──
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Icon(Icons.search_rounded,
                                  color: AppColors.textSecondary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                  style: GoogleFonts.inter(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Search by title or author…',
                                    hintStyle: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    fillColor: Colors.transparent,
                                    filled: true,
                                  ),
                                ),
                              ),
                              // Filter Chip
                              GestureDetector(
                                onTap: () => _showFilterSheet(context),
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.tune_rounded,
                                          color: AppColors.primary, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        _selectedFilter,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),

                // ── Empty State ──
                if (lessons.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 72,
                              color: AppColors.primary.withValues(alpha: 0.15)),
                          const SizedBox(height: 20),
                          Text(
                            'No lessons found',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try a different search term.'
                                : 'Lessons will appear here once available.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // ── Lessons Grid ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    sliver: SliverLayoutBuilder(
                      builder: (context, slc) {
                        final isWide = slc.crossAxisExtent > 700;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 2 : 1,
                            childAspectRatio: isWide ? 2.2 : 2.8,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final l = lessons[index];
                              return _LessonCard(
                                lesson: l,
                                canEdit: canEdit,
                                isDark: isDark,
                                statusColor: _statusColor(l.validationStatus, l.isMembersOnly),
                                statusLabel: _statusLabel(l.validationStatus, l.isMembersOnly),
                                statusIcon: _statusIcon(l.validationStatus, l.isMembersOnly),
                                dateStr: _formatTs(l.createdAt),
                                onTap: () {
                                  final currentUser = AuthService.instance.currentUser;
                                  if (currentUser != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => LessonPage(user: currentUser, lesson: l),
                                      ),
                                    );
                                  }
                                },
                                onEdit: canEdit ? () => widget.onEdit?.call(l) : null,
                                onEditQuiz: (canEdit && l.quizId != null)
                                    ? () => widget.onEditQuiz?.call(l)
                                    : null,
                                onDelete: canEdit ? () => _confirmDelete(context, l) : null,
                              );
                            },
                            childCount: lessons.length,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sort By',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._filterOptions.map((opt) {
              final selected = _selectedFilter == opt;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedFilter = opt);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        opt,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected
                              ? AppColors.primary
                              : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(Icons.check_rounded,
                            color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Lesson lesson) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFD32F2F), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Delete Lesson?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${lesson.title}" and its integrated quiz? This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await DatabaseService.instance.deleteLesson(lesson.id);
        if (lesson.quizId != null) {
          await DatabaseService.instance.deleteQuiz(lesson.quizId!);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

// ─── Lesson Card ──────────────────────────────────────────────────────────────

class _LessonCard extends StatefulWidget {
  final Lesson lesson;
  final bool canEdit;
  final bool isDark;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final String dateStr;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onEditQuiz;
  final VoidCallback? onDelete;

  const _LessonCard({
    required this.lesson,
    required this.canEdit,
    required this.isDark,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.dateStr,
    required this.onTap,
    this.onEdit,
    this.onEditQuiz,
    this.onDelete,
  });

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withValues(alpha: 0.4)
                : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.08 : 0.04),
              blurRadius: _hovered ? 20 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: status pill + actions ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.statusIcon,
                              size: 12, color: widget.statusColor),
                          const SizedBox(width: 5),
                          Text(
                            widget.statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Action icons (only for editors)
                    if (widget.canEdit)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onEditQuiz != null)
                            _iconBtn(
                              Icons.quiz_rounded,
                              Colors.blueAccent,
                              widget.onEditQuiz!,
                              tooltip: 'Edit Quiz',
                            ),
                          if (widget.onEdit != null) ...[
                            const SizedBox(width: 6),
                            _iconBtn(
                              Icons.edit_rounded,
                              AppColors.textSecondary,
                              widget.onEdit!,
                              tooltip: 'Edit Lesson',
                            ),
                          ],
                          if (widget.onDelete != null) ...[
                            const SizedBox(width: 6),
                            _iconBtn(
                              Icons.delete_outline_rounded,
                              const Color(0xFFD32F2F),
                              widget.onDelete!,
                              tooltip: 'Delete',
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Title ──
                Text(
                  widget.lesson.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: widget.isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Prompt preview ──
                Expanded(
                  child: Text(
                    widget.lesson.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bottom Row: author + date ──
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      widget.dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.lesson.quizId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.quiz_rounded,
                                size: 11, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Quiz',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
