import 'dart:async';
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
import '../../widgets/pagination_bar.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _currentPage = 1;
  static const int _pageSize = 8;
  String _statusFilter = 'all'; // 'all', 'approved', 'awaiting_approval', 'rejected'
  String _authorFilter = 'all'; // 'all' or specific author email
  DateTime? _selectedDate;
  final Set<String> _superAdminUids = {};
  late final Stream<List<Lesson>> _lessonsStream;

  @override
  void initState() {
    super.initState();
    _lessonsStream = DatabaseService.instance.streamAllLessonsDatabase();
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

  static final Map<String, String> _authorNameCache = {};

  String _getAuthorDisplayName(String uid, String? email, bool isGrammatica) {
    if (isGrammatica || (email != null && email.toLowerCase().contains('admin@'))) {
      return 'Grammatica Official';
    }
    if (uid.isNotEmpty && _authorNameCache.containsKey(uid)) {
      return _authorNameCache[uid]!;
    }
    if (uid.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          final fn = (d['first_name'] as String?)?.trim() ?? '';
          final ln = (d['last_name'] as String?)?.trim() ?? '';
          final full = [fn, ln].where((s) => s.isNotEmpty).join(' ');
          final display = (d['displayName'] as String?)?.trim() ?? (d['username'] as String?)?.trim() ?? '';
          final name = full.isNotEmpty ? full : (display.isNotEmpty ? display : (email?.split('@').first ?? 'Educator'));
          if (mounted && _authorNameCache[uid] != name) {
            setState(() {
              _authorNameCache[uid] = name;
            });
          }
        }
      }).catchError((_) {});
    }
    if (email != null && email.contains('@')) {
      final handle = email.split('@').first;
      return handle.isNotEmpty ? handle : 'Educator';
    }
    return email ?? 'Educator';
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
      setState(() {
        _selectedDate = picked;
        _currentPage = 1;
      });
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
      stream: _lessonsStream,
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

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allLessons = snapshot.data ?? [];

        // Extract unique authors for filtering
        final Map<String, _AuthorFilterItem> authorMap = {};
        for (final l in allLessons) {
          final key = (l.createdByUid != null && l.createdByUid!.isNotEmpty)
              ? l.createdByUid!
              : (l.createdByEmail?.trim() ?? '');
          if (key.isNotEmpty && !authorMap.containsKey(key)) {
            final name = _getAuthorDisplayName(l.createdByUid ?? '', l.createdByEmail, l.isGrammaticaLesson);
            authorMap[key] = _AuthorFilterItem(key, name);
          }
        }
        final sortedAuthors = authorMap.values.toList()
          ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

        // Apply Search & Filters
        var filteredLessons = allLessons.where((lesson) {
          // Admin (non-superadmin) should not view lessons for approval
          if (widget.role == UserRole.admin && lesson.validationStatus == 'awaiting_approval') {
            return false;
          }

          // Author filter
          if (_authorFilter != 'all') {
            final authorKey = (lesson.createdByUid != null && lesson.createdByUid!.isNotEmpty)
                ? lesson.createdByUid!
                : (lesson.createdByEmail ?? '');
            if (authorKey.toLowerCase() != _authorFilter.toLowerCase() &&
                (lesson.createdByEmail ?? '').toLowerCase() != _authorFilter.toLowerCase()) {
              return false;
            }
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

          // Text Search filter (searches across all lesson fields)
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            final titleMatch = lesson.title.toLowerCase().contains(q);
            final authorMatch = (lesson.createdByEmail ?? '').toLowerCase().contains(q);
            final promptMatch = lesson.prompt.toLowerCase().contains(q);
            final contentMatch = lesson.answer.toLowerCase().contains(q);

            if (!(titleMatch || authorMatch || promptMatch || contentMatch)) {
              return false;
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

                    // ── Clean Search Bar ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
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
                      child: Row(
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
                                controller: _searchController,
                                onChanged: (val) {
                                  _searchDebounce?.cancel();
                                  _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                                    if (mounted) {
                                      setState(() {
                                        _searchQuery = val;
                                        _currentPage = 1;
                                      });
                                    }
                                  });
                                },
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
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchDebounce?.cancel();
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                              _currentPage = 1;
                                            });
                                          },
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
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${filteredLessons.length} lessons',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Table Header With Column Filters ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: _buildTableHeader(context, isDark, sortedAuthors),
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
                          'Try clearing search keywords or resetting table filters.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_authorFilter != 'all' || _statusFilter != 'all' || _selectedDate != null || _searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _searchDebounce?.cancel();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _authorFilter = 'all';
                                _statusFilter = 'all';
                                _selectedDate = null;
                                _currentPage = 1;
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset All Filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              Builder(
                builder: (context) {
                  final totalItems = filteredLessons.length;
                  final maxPage = (totalItems / _pageSize).ceil().clamp(1, 9999);
                  final currentPageSafe = _currentPage.clamp(1, maxPage);
                  final startIndex = (currentPageSafe - 1) * _pageSize;
                  final pageLessons = filteredLessons.skip(startIndex).take(_pageSize).toList();

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final lesson = pageLessons[index];
                          return _buildLessonDatabaseRow(context, lesson, isDark);
                        },
                        childCount: pageLessons.length,
                      ),
                    ),
                  );
                },
              ),
              if (filteredLessons.length > _pageSize)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: PaginationBar(
                      currentPage: _currentPage,
                      totalItems: filteredLessons.length,
                      pageSize: _pageSize,
                      itemName: 'lessons',
                      onPageChanged: (newPage) {
                        setState(() => _currentPage = newPage);
                      },
                    ),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        );
      },
    );
  }

  Widget _buildTableHeader(BuildContext context, bool isDark, List<_AuthorFilterItem> authors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 720;
          if (!isDesktop) {
            // Mobile compact filters
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterDropdown(isDark),
                  const SizedBox(width: 8),
                  _buildAuthorFilterDropdown(isDark, authors),
                  const SizedBox(width: 8),
                  _buildDateFilterChip(context, isDark),
                ],
              ),
            );
          }

          return Row(
            children: [
              // Icon spacer 44 + 16
              const SizedBox(width: 60),
              // Lesson Title column (flex 4)
              Expanded(
                flex: 4,
                child: Text(
                  'LESSON DETAILS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Author column (flex 3) with Author Filter Dropdown
              Expanded(
                flex: 3,
                child: _buildAuthorFilterDropdown(isDark, authors),
              ),
              const SizedBox(width: 16),
              // Status column (flex 2) with Status Filter Dropdown
              Expanded(
                flex: 2,
                child: _buildStatusFilterDropdown(isDark),
              ),
              const SizedBox(width: 16),
              // Created Date column (flex 2) with Date Filter Picker
              Expanded(
                flex: 2,
                child: _buildDateFilterChip(context, isDark),
              ),
              const SizedBox(width: 16),
              // Actions column header (approx width matching action buttons)
              SizedBox(
                width: 155,
                child: Center(
                  child: Text(
                    'ACTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthorFilterDropdown(bool isDark, List<_AuthorFilterItem> authors) {
    final selectedItem = authors.firstWhere(
      (a) => a.key.toLowerCase() == _authorFilter.toLowerCase(),
      orElse: () => _AuthorFilterItem('all', 'All Authors'),
    );

    return PopupMenuButton<String>(
      tooltip: 'Filter by author',
      onSelected: (val) {
        setState(() {
          _authorFilter = val;
          _currentPage = 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _authorFilter != 'all' ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _authorFilter == 'all'
                    ? 'AUTHOR'
                    : 'AUTHOR: ${selectedItem.displayName.toUpperCase()}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _authorFilter != 'all' ? AppColors.primary : AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.filter_list_rounded,
              size: 14,
              color: _authorFilter != 'all' ? AppColors.primary : AppColors.textSecondary,
            ),
            if (_authorFilter != 'all') ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() {
                  _authorFilter = 'all';
                  _currentPage = 1;
                }),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'all', child: Text('All Authors')),
        ...authors.map((a) => PopupMenuItem(value: a.key, child: Text(a.displayName))),
      ],
    );
  }

  Widget _buildStatusFilterDropdown(bool isDark) {
    return PopupMenuButton<String>(
      tooltip: 'Filter by status',
      onSelected: (val) {
        setState(() {
          _statusFilter = val;
          _currentPage = 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _statusFilter != 'all' ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusFilter == 'all' ? 'STATUS' : 'STATUS: ${_statusFilter.toUpperCase()}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _statusFilter != 'all' ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.filter_alt_outlined,
              size: 14,
              color: _statusFilter != 'all' ? AppColors.primary : AppColors.textSecondary,
            ),
            if (_statusFilter != 'all') ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() {
                  _statusFilter = 'all';
                  _currentPage = 1;
                }),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'all', child: Text('All Statuses')),
        const PopupMenuItem(value: 'approved', child: Text('Published')),
        if (widget.role != UserRole.admin)
          const PopupMenuItem(value: 'awaiting_approval', child: Text('Pending Review')),
        const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
      ],
    );
  }

  Widget _buildDateFilterChip(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _selectedDate != null ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedDate == null ? 'CREATED' : 'CREATED: ${_formatDate(_selectedDate)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _selectedDate != null ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: _selectedDate != null ? AppColors.primary : AppColors.textSecondary,
            ),
            if (_selectedDate != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = null;
                  _currentPage = 1;
                }),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
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

class _AuthorFilterItem {
  final String key;
  final String displayName;
  _AuthorFilterItem(this.key, this.displayName);
}
