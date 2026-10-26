import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/role_service.dart';
import '../../widgets/author_name_widget.dart';
import '../../widgets/content_denial_dialog.dart';
import '../../widgets/interactive_markdown.dart';
import '../../widgets/archive_management_dialog.dart';
import '../../theme/app_colors.dart';
import '../lesson_page.dart';

/// Database view for Admins showing the entire collection of platform lessons.
class AdminLessonDatabaseTab extends StatefulWidget {
  final UserRole role;
  const AdminLessonDatabaseTab({super.key, this.role = UserRole.admin});

  @override
  State<AdminLessonDatabaseTab> createState() => _AdminLessonDatabaseTabState();
}

class _AdminLessonDatabaseTabState extends State<AdminLessonDatabaseTab> {
  String _searchQuery = '';
  String _searchCriteria = 'all'; // 'all', 'title', 'author'
  String _statusFilter = 'all'; // 'all', 'approved', 'awaiting_approval', 'rejected'
  DateTime? _selectedDate;
  final Set<String> _superAdminUids = {};

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'SUPERADMIN')
        .get()
        .then((snap) {
      if (mounted) {
        setState(() {
          _superAdminUids.addAll(snap.docs.map((d) => d.id));
        });
      }
    });
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'N/A';
    DateTime d;
    if (ts is Timestamp) {
      d = ts.toDate().toLocal();
    } else if (ts is DateTime) {
      d = ts.toLocal();
    } else {
      return 'N/A';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _parseDateTime(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate().toLocal();
    if (ts is DateTime) return ts.toLocal();
    return null;
  }

  Color _statusColor(String? status) {
    if (status == 'awaiting_approval') return const Color(0xFFF5A623);
    if (status == 'rejected') return const Color(0xFFD32F2F);
    return const Color(0xFF2E7D32); // Approved / Published
  }

  String _statusLabel(String? status) {
    if (status == 'awaiting_approval') return 'Pending Review';
    if (status == 'rejected') return 'Rejected';
    return 'Published';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleDeleteLesson(BuildContext context, Lesson lesson) async {
    final result = await showContentDenialDialog(
      context,
      contentTitle: lesson.title,
      authorName: lesson.createdByEmail,
      isPermanentDeletion: true,
    );

    if (result == null) return;

    try {
      // 1. Move lesson package to Archive for 30 days
      await DatabaseService.instance.archiveLesson(lesson.id);

      // 2. Deliver notification to author if author UID is available
      if (lesson.createdByUid != null && lesson.createdByUid!.isNotEmpty) {
        await NotificationService.instance.sendContentDeletedNotification(
          uid: lesson.createdByUid!,
          title: lesson.title,
          reasonCategory: result.category,
          explanation: result.explanation,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.archive_outlined, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lesson "${lesson.title}" moved to Archive. After 30 days, the content will be permanently deleted from Grammatica.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving lesson: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showViewContentModal(BuildContext context, Lesson lesson) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.90,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 25,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Handle bar ───────────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Header ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              AuthorName(
                                uid: lesson.createdByUid,
                                fallbackEmail: lesson.createdByEmail,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• Created ${_formatDate(lesson.createdAt)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Scrollable Lesson Content ────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Metadata Pill Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(lesson.validationStatus).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _statusColor(lesson.validationStatus).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _statusLabel(lesson.validationStatus).toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(lesson.validationStatus),
                              ),
                            ),
                          ),
                          if (lesson.isGrammaticaLesson == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'OFFICIAL GRAMMATICA',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          if (lesson.quizId != null && lesson.quizId!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.quiz_rounded, size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'COMPANION QUIZ LINKED',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Rejection Alert if rejected
                      if (lesson.validationStatus == 'rejected' &&
                          (lesson.rejectionReason != null || lesson.rejectionDescription != null)) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE05050).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.block_rounded, color: Color(0xFFD32F2F), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'REJECTION RECORD',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFD32F2F),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (lesson.rejectionReason != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Category: ${lesson.rejectionReason}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFB71C1C),
                                  ),
                                ),
                              ],
                              if (lesson.rejectionDescription != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  lesson.rejectionDescription!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF7A2020),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Image banner if present
                      if (lesson.imageUrl != null && lesson.imageUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            lesson.imageUrl!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Lesson Prompt / Description Box
                      if (lesson.prompt.isNotEmpty) ...[
                        Text(
                          'Prompt & Lesson Overview',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155).withValues(alpha: 0.4)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            lesson.prompt,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Full Lesson Body (Markdown)
                      Text(
                        'Full Lesson Content',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                        ),
                        child: lesson.markdown.isNotEmpty
                            ? InteractiveMarkdown(
                                data: lesson.markdown,
                              )
                            : Text(
                                'No markdown body provided for this lesson.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Action Footer ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Delete/Archive Button
                    Builder(
                      builder: (ctxBtn) {
                        final isSuperAdminContent = _superAdminUids.contains(lesson.createdByUid);
                        final canDelete = widget.role == UserRole.superadmin || !isSuperAdminContent;

                        if (!canDelete) {
                          return Tooltip(
                            message: 'Only Super Admin can delete content created by Super Admin',
                            child: Opacity(
                              opacity: 0.4,
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.archive_outlined, color: Colors.grey, size: 18),
                                label: Text(
                                  'Move to Archive',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleDeleteLesson(context, lesson);
                          },
                          icon: const Icon(Icons.archive_outlined, color: Color(0xFFD32F2F), size: 18),
                          label: Text(
                            'Move to Archive',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFD32F2F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE57373)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),

                    // Interactive Preview in Full Lesson Page
                    if (user != null)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LessonPage(
                                user: user,
                                lesson: lesson,
                                previewMode: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          'Open Live Preview',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamAllLessonsDatabase(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load lesson database: ${snapshot.error}',
                    style: GoogleFonts.inter(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allLessons = snapshot.data ?? [];

        // Apply Search & Filters
        var filteredLessons = allLessons.where((lesson) {
          // Admin (non-superadmin) should not view lessons for approval
          if (widget.role == UserRole.admin && lesson.validationStatus == 'awaiting_approval') {
            return false;
          }

          // Status filter
          if (_statusFilter != 'all') {
            if (_statusFilter == 'approved') {
              if (lesson.validationStatus == 'awaiting_approval' || lesson.validationStatus == 'rejected') {
                return false;
              }
            } else if (lesson.validationStatus != _statusFilter) {
              return false;
            }
          }

          // Date filter
          if (_selectedDate != null) {
            final lessonDate = _parseDateTime(lesson.createdAt);
            if (lessonDate == null || !_isSameDay(lessonDate, _selectedDate!)) {
              return false;
            }
          }

          // Text Search filter
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            final titleMatch = lesson.title.toLowerCase().contains(q);
            final authorMatch = (lesson.createdByEmail ?? '').toLowerCase().contains(q);
            final promptMatch = lesson.prompt.toLowerCase().contains(q);

            if (_searchCriteria == 'title') {
              return titleMatch;
            } else if (_searchCriteria == 'author') {
              return authorMatch;
            } else {
              return titleMatch || authorMatch || promptMatch;
            }
          }

          return true;
        }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Page Header ──────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.table_chart_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lesson Database',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Master database of all platform lessons across educators and official curriculum.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ArchiveManagementDialog(role: widget.role),
                            );
                          },
                          icon: const Icon(Icons.archive_outlined, size: 18),
                          label: Text(
                            'Open Archive',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE05050).withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFFE05050),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 30-Day Archive Retention Notice ──────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.archive_outlined,
                            color: Color(0xFFE05050),
                            size: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CONTENT ARCHIVE & 30-DAY RETENTION',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: const Color(0xFFE05050),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Deleted lessons are moved to the Archive. After 30 days, the content will be permanently deleted from Grammatica. You can restore archived content at any time before expiration.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Search & Filter Controls ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: TextField(
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    style: GoogleFonts.inter(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Search by title, prompt, author name, or email...',
                                      hintStyle: GoogleFonts.inter(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () => setState(() => _searchQuery = ''),
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Filter chips row: Search Criteria, Date Filter, Status Filter
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Criteria Selector
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Criteria: ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    DropdownButton<String>(
                                      value: _searchCriteria,
                                      underline: const SizedBox.shrink(),
                                      isDense: true,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                      ),
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('All Fields')),
                                        DropdownMenuItem(value: 'title', child: Text('Title')),
                                        DropdownMenuItem(value: 'author', child: Text('Author')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _searchCriteria = v);
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Status Selector
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Status: ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    DropdownButton<String>(
                                      value: _statusFilter,
                                      underline: const SizedBox.shrink(),
                                      isDense: true,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                      ),
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      items: [
                                        const DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                                        const DropdownMenuItem(value: 'approved', child: Text('Published')),
                                        if (widget.role != UserRole.admin)
                                          const DropdownMenuItem(value: 'awaiting_approval', child: Text('Pending Review')),
                                        const DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _statusFilter = v);
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Date Filter Button
                              ActionChip(
                                avatar: Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: _selectedDate != null ? Colors.white : AppColors.primary,
                                ),
                                label: Text(
                                  _selectedDate != null
                                      ? 'Date: ${_formatDate(_selectedDate)}'
                                      : 'Filter by Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedDate != null ? Colors.white : AppColors.primary,
                                  ),
                                ),
                                backgroundColor: _selectedDate != null
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.1),
                                onPressed: () => _pickDate(context),
                              ),

                              // Reset Date filter if set
                              if (_selectedDate != null)
                                TextButton.icon(
                                  onPressed: () => setState(() => _selectedDate = null),
                                  icon: const Icon(Icons.clear_rounded, size: 14),
                                  label: Text(
                                    'Clear Date',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                ),

                              // Count Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${filteredLessons.length} lessons found',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Database Items Table / Cards ──────────────────────────
            if (filteredLessons.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 64,
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No lessons match criteria',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try clearing search keywords or resetting the date filter.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final lesson = filteredLessons[index];
                      return _buildLessonDatabaseRow(context, lesson, isDark);
                    },
                    childCount: filteredLessons.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        );
      },
    );
  }

  Widget _buildLessonDatabaseRow(BuildContext context, Lesson lesson, bool isDark) {
    final statusColor = _statusColor(lesson.validationStatus);
    final statusLabel = _statusLabel(lesson.validationStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 720;

            if (isDesktop) {
              return Row(
                children: [
                  // Lesson Icon / Image
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        lesson.isGrammaticaLesson == true
                            ? Icons.verified_rounded
                            : Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title & Prompt preview
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lesson.prompt.isNotEmpty
                              ? lesson.prompt
                              : 'No prompt description provided.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Author
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUTHOR',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AuthorName(
                          uid: lesson.createdByUid,
                          fallbackEmail: lesson.createdByEmail,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATUS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Creation Date
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CREATED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(lesson.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _showViewContentModal(context, lesson),
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: Text(
                          'View Content',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (ctxBtn) {
                          final isSuperAdminContent = _superAdminUids.contains(lesson.createdByUid);
                          final canDelete = widget.role == UserRole.superadmin || !isSuperAdminContent;

                          if (!canDelete) {
                            return const Tooltip(
                              message: 'Only Super Admin can delete content created by Super Admin',
                              child: Opacity(
                                opacity: 0.35,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.archive_outlined,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: null,
                                ),
                              ),
                            );
                          }

                          return IconButton(
                            tooltip: 'Move to Archive (30-day retention)',
                            icon: const Icon(
                              Icons.archive_outlined,
                              color: Color(0xFFD32F2F),
                              size: 20,
                            ),
                            onPressed: () => _handleDeleteLesson(context, lesson),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              );
            }

            // Mobile / Narrow card layout
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AuthorName(
                            uid: lesson.createdByUid,
                            fallbackEmail: lesson.createdByEmail,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Created: ${_formatDate(lesson.createdAt)}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showViewContentModal(context, lesson),
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: Text('View Content', style: GoogleFonts.inter(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Builder(
                      builder: (ctxBtn) {
                        final isSuperAdminContent = _superAdminUids.contains(lesson.createdByUid);
                        final canDelete = widget.role == UserRole.superadmin || !isSuperAdminContent;

                        if (!canDelete) {
                          return Tooltip(
                            message: 'Only Super Admin can delete content created by Super Admin',
                            child: Opacity(
                              opacity: 0.4,
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.archive_outlined, color: Colors.grey, size: 16),
                                label: Text(
                                  'Archive',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return OutlinedButton.icon(
                          onPressed: () => _handleDeleteLesson(context, lesson),
                          icon: const Icon(Icons.archive_outlined, color: Color(0xFFD32F2F), size: 16),
                          label: Text(
                            'Archive',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD32F2F)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF9A9A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
