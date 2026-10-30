import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../services/navigation_service.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';
import '../../widgets/content_denial_dialog.dart';
import '../../widgets/archive_management_dialog.dart';
import '../../widgets/author_name_widget.dart';
import '../../models/playlist.dart';

class LessonsListTab extends StatefulWidget {
  final UserRole role;
  final Function(Lesson)? onEdit;
  final Function(Lesson)? onEditQuiz;
  const LessonsListTab({
    super.key,
    this.role = UserRole.learner,
    this.onEdit,
    this.onEditQuiz,
  });
  @override
  State<LessonsListTab> createState() => _LessonsListTabState();
}

class _LessonsListTabState extends State<LessonsListTab> {
  String _searchQuery = '';
  String _selectedFilter = 'Date Created';
  final List<String> _filterOptions = ['Name', 'Status', 'Date Created'];
  final Set<String> _superAdminUids = {};
  int _activeView = 0; // 0: Lessons, 1: Playlists
  String _selectedCategory = 'All Lessons';
  final List<String> _categoryOptions = [
    'All Lessons',
    'Public Lessons',
    'Members Only Lessons',
    'Rejected Lessons',
  ];
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

            var lessons = snapshot.data!.where((l) {
              if (l.validationStatus == 'approved') return true;
              final isAuthor = user != null && l.createdByUid == user.uid;
              final isValidator = role == UserRole.validator;
              return isAuthor || isValidator;
            }).toList();

            // Admin / Superadmin only see official Grammatica lessons
            if (role == UserRole.admin || role == UserRole.superadmin) {
              lessons = lessons.where((l) => l.isGrammaticaLesson == true).toList();
            }
            if (role == UserRole.admin) {
              lessons = lessons.where((l) => l.validationStatus != 'awaiting_approval').toList();
            }

            // Educators only see their own lessons
            if (role == UserRole.educator && user != null) {
              lessons = lessons.where((l) => l.createdByUid == user.uid).toList();
            }

            // Search filter
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              lessons = lessons.where((l) {
                if (role == UserRole.educator) {
                  return l.title.toLowerCase().contains(q);
                }
                return l.title.toLowerCase().contains(q) ||
                    (l.createdByEmail ?? '').toLowerCase().contains(q);
              }).toList();
            }

            // Category filter dropdown: 'All Lessons', 'Public Lessons', 'Members Only Lessons', 'Rejected Lessons'
            if (_selectedCategory == 'Public Lessons') {
              lessons = lessons.where((l) => !l.isMembersOnly && l.validationStatus != 'rejected').toList();
            } else if (_selectedCategory == 'Members Only Lessons') {
              lessons = lessons.where((l) => l.isMembersOnly && l.validationStatus != 'rejected').toList();
            } else if (_selectedCategory == 'Rejected Lessons') {
              lessons = lessons.where((l) => l.validationStatus == 'rejected').toList();
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
              key: const PageStorageKey('admin_lessons_list_scroll_view'),
              controller: _scrollController,
              slivers: [
                // ── Top Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 20,
                          runSpacing: 14,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _activeView == 0 ? 'Lessons' : 'Playlists',
                                  style: GoogleFonts.outfit(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _activeView == 0
                                      ? '${lessons.length} lesson${lessons.length == 1 ? '' : 's'} found'
                                      : 'Ordered learning journeys curated for students',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // View switcher
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Lessons'),
                                        selected: _activeView == 0,
                                        onSelected: (val) {
                                          if (val) setState(() => _activeView = 0);
                                        },
                                        selectedColor: AppColors.primary,
                                        labelStyle: TextStyle(
                                          color: _activeView == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        showCheckmark: false,
                                      ),
                                      const SizedBox(width: 4),
                                      ChoiceChip(
                                        label: const Text('Playlists'),
                                        selected: _activeView == 1,
                                        onSelected: (val) {
                                          if (val) setState(() => _activeView = 1);
                                        },
                                        selectedColor: AppColors.primary,
                                        labelStyle: TextStyle(
                                          color: _activeView == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        showCheckmark: false,
                                      ),
                                    ],
                                  ),
                                ),
                                // Create Playlist button (only visible when in Playlists view)
                                if (_activeView == 1)
                                  FilledButton.icon(
                                    onPressed: () => _showPlaylistDialog(context, lessons),
                                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                                    label: const Text('New Playlist'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                // Archive dialog button
                                OutlinedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => ArchiveManagementDialog(role: widget.role),
                                    );
                                  },
                                  icon: const Icon(Icons.archive_outlined, size: 18),
                                  label: const Text('Archive'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber.shade700,
                                    side: BorderSide(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        if (_activeView == 0) ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 650;

                              final searchField = Container(
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
                                          hintText: 'Search by title…',
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
                                    // Sort Filter Dropdown
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedFilter,
                                          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          icon: const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                                          ),
                                          items: _filterOptions.map((opt) {
                                            return DropdownMenuItem<String>(
                                              value: opt,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    opt == 'Name'
                                                        ? Icons.sort_by_alpha_rounded
                                                        : (opt == 'Status' ? Icons.traffic_rounded : Icons.calendar_today_rounded),
                                                    size: 14,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    opt,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedFilter = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              final categoryDropdown = Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategory,
                                    dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    icon: const Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 20),
                                    items: _categoryOptions.map((opt) {
                                      Color color = AppColors.primary;
                                      IconData icon = Icons.apps_rounded;
                                      if (opt == 'Public Lessons') {
                                        color = AppColors.primary;
                                        icon = Icons.public_rounded;
                                      } else if (opt == 'Members Only Lessons') {
                                        color = const Color(0xFF9B59B6);
                                        icon = Icons.lock_rounded;
                                      } else if (opt == 'Rejected Lessons') {
                                        color = const Color(0xFFD32F2F);
                                        icon = Icons.cancel_rounded;
                                      }
                                      return DropdownMenuItem<String>(
                                        value: opt,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(icon, size: 16, color: color),
                                            const SizedBox(width: 8),
                                            Text(
                                              opt,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCategory = val);
                                    },
                                  ),
                                ),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    searchField,
                                    const SizedBox(height: 12),
                                    categoryDropdown,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: searchField),
                                  const SizedBox(width: 14),
                                  categoryDropdown,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),

                if (_activeView == 1)
                  _buildPlaylistsSection(context, lessons, isDark, user?.uid ?? '')
                else if (lessons.isEmpty)
                  // ── Empty State ──
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
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    sliver: SliverLayoutBuilder(
                      builder: (context, slc) {
                        final isWide = slc.crossAxisExtent > 700;
                        return _buildLessonSliverGrid(lessons, canEdit, isDark, isWide);
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





  Widget _buildLessonSliverGrid(
    List<Lesson> list,
    bool canEdit,
    bool isDark,
    bool isWide,
  ) {
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No lessons found in this section',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        childAspectRatio: isWide ? 1.85 : 1.45,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final l = list[index];
          final isSuperAdminContent = _superAdminUids.contains(l.createdByUid);
          final isDeleteBlocked = widget.role == UserRole.admin && isSuperAdminContent;

          return _LessonCard(
            lesson: l,
            canEdit: canEdit,
            isDark: isDark,
            statusColor: _statusColor(l.validationStatus, l.isMembersOnly),
            statusLabel: _statusLabel(l.validationStatus, l.isMembersOnly),
            statusIcon: _statusIcon(l.validationStatus, l.isMembersOnly),
            dateStr: _formatTs(l.createdAt),
            onTap: () {
              NavigationService.instance.goToLesson(context, l);
            },
            onEdit: canEdit ? () => widget.onEdit?.call(l) : null,
            onEditQuiz: (canEdit && l.quizId != null)
                ? () => widget.onEditQuiz?.call(l)
                : null,
            isDeleteDisabled: isDeleteBlocked,
            deleteTooltip: isDeleteBlocked
                ? 'Only Super Admin can delete content created by Super Admin'
                : 'Archive Lesson',
            onDelete: (canEdit && !isDeleteBlocked) ? () => _confirmDelete(context, l) : null,
          );
        },
        childCount: list.length,
      ),
    );
  }



  Future<void> _confirmDelete(BuildContext context, Lesson lesson) async {
    final user = AuthService.instance.currentUser;
    final isOwner = user != null && lesson.createdByUid == user.uid;

    if (!isOwner) {
      // Admin/Validator deleting content created by another author -> use overhauled denial dialog
      final result = await showContentDenialDialog(
        context,
        contentTitle: lesson.title,
        authorName: lesson.createdByEmail,
        isPermanentDeletion: true,
      );

      if (result != null) {
        try {
          await DatabaseService.instance.archiveLesson(lesson.id);

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
              const SnackBar(
                content: Text('Lesson moved to archive. After 30 days, the content will be permanently deleted from Grammatica.'),
                backgroundColor: Color(0xFFD32F2F),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error archiving lesson: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
      return;
    }

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
              child: const Icon(Icons.archive_outlined,
                  color: Color(0xFFD32F2F), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Archive Lesson?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${lesson.title}"? After 30 days, the content will be permanently deleted from Grammatica.',
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
            child: Text('Archive',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await DatabaseService.instance.archiveLesson(lesson.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson moved to archive. After 30 days, the content will be permanently deleted from Grammatica.')),
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

  void _showPlaylistDialog(BuildContext context, List<Lesson> allLessons, {LessonPlaylist? existing}) {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // Preference: Playlists can only include approved lessons authored by the creator (or official Grammatica lessons)
    final userEmail = user.email?.toLowerCase();
    final allowedLessons = allLessons.where((l) {
      final matchesUid = l.createdByUid == user.uid;
      final matchesEmail = userEmail != null && l.createdByEmail?.toLowerCase() == userEmail;
      final isOfficial = l.isGrammaticaLesson == true;
      return (matchesUid || matchesEmail || isOfficial) && l.validationStatus == 'approved';
    }).toList();

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final selectedLessonIds = List<String>.from(existing?.lessonIds ?? []);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> confirmCancel() async {
            final shouldDiscard = await showDialog<bool>(
              context: dialogCtx,
              builder: (ctx) => AlertDialog(
                backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        existing == null ? 'Cancel Playlist Creation?' : 'Discard Changes?',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  existing == null
                      ? 'Are you sure you want to cancel creating this playlist? Any entered information will be lost.'
                      : 'Are you sure you want to discard your changes? Any unsaved modifications will be lost.',
                  style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Keep Editing', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            if (shouldDiscard == true && dialogCtx.mounted) {
              Navigator.pop(dialogCtx);
            }
          }

          final mediaQuery = MediaQuery.of(dialogCtx);
          final isMobile = mediaQuery.size.width < 600;
          final maxHeight = mediaQuery.size.height * (isMobile ? 0.92 : 0.85);

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) confirmCancel();
            },
            child: Dialog(
              backgroundColor: isDark ? const Color(0xFF242424) : Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 40,
                vertical: isMobile ? 16 : 40,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 650,
                  maxHeight: maxHeight,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 28,
                    isMobile ? 16 : 28,
                    isMobile ? 16 : 28,
                    isMobile ? 16 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top Header ──
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              existing == null ? 'Create Lesson Playlist' : 'Edit Playlist',
                              style: GoogleFonts.outfit(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: confirmCancel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Inputs ──
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Playlist Title',
                          hintText: 'e.g. Master English Tenses in Order',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Describe the sequence or goal of this playlist',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select & Arrange Lessons (${selectedLessonIds.length} selected)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lessons will be viewed sequentially in this order by learners.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      if (allowedLessons.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No authored or official Grammatica lessons available to add.',
                              style: GoogleFonts.inter(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ...allowedLessons.map((lesson) {
                          final isSelected = selectedLessonIds.contains(lesson.id);
                          final orderIndex = selectedLessonIds.indexOf(lesson.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? Colors.white12 : Colors.black12),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              onTap: isSelected
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        selectedLessonIds.add(lesson.id);
                                      });
                                    },
                              leading: isSelected
                                  ? CircleAvatar(
                                      radius: 13,
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        '${orderIndex + 1}',
                                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : null,
                              title: Text(
                                lesson.title,
                                style: GoogleFonts.inter(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: lesson.isGrammaticaLesson
                                  ? Text(
                                      'Official Grammatica',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                    )
                                  : AuthorName(
                                      uid: lesson.createdByUid,
                                      fallbackEmail: lesson.createdByEmail,
                                      prefix: '',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                              trailing: isSelected
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (orderIndex > 0)
                                          IconButton(
                                            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                                            tooltip: 'Move up',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                            onPressed: () {
                                              setDialogState(() {
                                                final id = selectedLessonIds.removeAt(orderIndex);
                                                selectedLessonIds.insert(orderIndex - 1, id);
                                              });
                                            },
                                          ),
                                        if (orderIndex < selectedLessonIds.length - 1)
                                          IconButton(
                                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                                            tooltip: 'Move down',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                            onPressed: () {
                                              setDialogState(() {
                                                final id = selectedLessonIds.removeAt(orderIndex);
                                                selectedLessonIds.insert(orderIndex + 1, id);
                                              });
                                            },
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                                          tooltip: 'Remove',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          onPressed: () {
                                            setDialogState(() {
                                              selectedLessonIds.remove(lesson.id);
                                            });
                                          },
                                        ),
                                      ],
                                    )
                                  : TextButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedLessonIds.add(lesson.id);
                                        });
                                      },
                                      child: const Text('Add'),
                                    ),
                            ),
                          );
                        }),
                      const SizedBox(height: 18),

                      // ── Actions (Positioned directly beneath lessons list) ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: confirmCancel,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: selectedLessonIds.isEmpty || titleCtrl.text.trim().isEmpty
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: dialogCtx,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.playlist_add_check_rounded, color: AppColors.primary, size: 22),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                existing == null ? 'Create Playlist?' : 'Save Changes?',
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          existing == null
                                              ? 'Are you sure you want to create "${titleCtrl.text.trim()}" with ${selectedLessonIds.length} lesson${selectedLessonIds.length == 1 ? '' : 's'}?'
                                              : 'Are you sure you want to save changes to "${titleCtrl.text.trim()}"?',
                                          style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            child: Text(existing == null ? 'Create' : 'Save',
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;

                                    try {
                                      if (existing == null) {
                                        await DatabaseService.instance.createPlaylist(
                                          title: titleCtrl.text.trim(),
                                          description: descCtrl.text.trim(),
                                          createdByUid: user.uid,
                                          createdByEmail: user.email ?? '',
                                          lessonIds: selectedLessonIds,
                                        );
                                      } else {
                                        await DatabaseService.instance.updatePlaylist(
                                          id: existing.id,
                                          title: titleCtrl.text.trim(),
                                          description: descCtrl.text.trim(),
                                          lessonIds: selectedLessonIds,
                                        );
                                      }
                                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(existing == null ? 'Playlist created!' : 'Playlist updated!'),
                                            backgroundColor: AppColors.primary,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error saving playlist: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text(existing == null ? 'Create Playlist' : 'Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsSection(BuildContext context, List<Lesson> allLessons, bool isDark, String currentUid) {
    final stream = (widget.role == UserRole.admin || widget.role == UserRole.superadmin)
        ? DatabaseService.instance.streamAllPlaylists()
        : DatabaseService.instance.streamPlaylistsByCreator(currentUid, email: AuthService.instance.currentUser?.email);

    return StreamBuilder<List<LessonPlaylist>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final playlists = snap.data!;
        if (playlists.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.playlist_play_rounded, size: 72, color: AppColors.primary.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No playlists created yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Organize your lessons into ordered playlist folders for sequential student learning.',
                      textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _showPlaylistDialog(context, allLessons),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Playlist'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          sliver: SliverLayoutBuilder(
            builder: (context, slc) {
              final isMobile = slc.crossAxisExtent < 650;
              final isWide = slc.crossAxisExtent > 1100;
              final crossAxisCount = isMobile ? 1 : (isWide ? 3 : 2);
              final childAspectRatio = isMobile ? 1.6 : 1.5;

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = playlists[index];
                    final curEmail = AuthService.instance.currentUser?.email?.toLowerCase();
                    final canEdit = p.createdByUid == currentUid ||
                        (curEmail != null && p.createdByEmail.toLowerCase() == curEmail) ||
                        widget.role == UserRole.superadmin ||
                        widget.role == UserRole.admin;

                    return _PlaylistCard(
                      playlist: p,
                      isDark: isDark,
                      canEdit: canEdit,
                      onEdit: () => _showPlaylistDialog(context, allLessons, existing: p),
                      onDelete: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Playlist?'),
                            content: Text('Are you sure you want to delete playlist "${p.title}"? Lessons inside the playlist will NOT be deleted.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await DatabaseService.instance.deletePlaylist(p.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playlist deleted.')));
                          }
                        }
                      },
                      onTap: () async {
                        if (p.lessonIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This playlist has no lessons yet.')));
                          return;
                        }
                        final firstLessonId = p.lessonIds.first;
                        final matches = allLessons.where((l) => l.id == firstLessonId);
                        final Lesson? lesson = matches.isNotEmpty
                            ? matches.first
                            : await DatabaseService.instance.getLesson(firstLessonId);
                        if (lesson == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load the first lesson in this playlist.')));
                          }
                          return;
                        }
                        if (context.mounted) {
                          NavigationService.instance.goToLesson(context, lesson, playlist: p);
                        }
                      },
                    );
                  },
                  childCount: playlists.length,
                ),
              );
            },
          ),
        );
      },
    );
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
  final bool isDeleteDisabled;
  final String? deleteTooltip;

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
    this.isDeleteDisabled = false,
    this.deleteTooltip,
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
            padding: const EdgeInsets.all(18),
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
                          if (widget.isDeleteDisabled) ...[
                            const SizedBox(width: 6),
                            _iconBtn(
                              Icons.delete_outline_rounded,
                              Colors.grey.shade400,
                              () {},
                              tooltip: widget.deleteTooltip ?? 'Delete',
                            ),
                          ] else if (widget.onDelete != null) ...[
                            const SizedBox(width: 6),
                            _iconBtn(
                              Icons.delete_outline_rounded,
                              const Color(0xFFD32F2F),
                              widget.onDelete!,
                              tooltip: widget.deleteTooltip ?? 'Delete',
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
                if (widget.lesson.imageUrl != null && widget.lesson.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.lesson.imageUrl!,
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // ── Title ──
                Text(
                  widget.lesson.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: widget.isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // ── Prompt preview ──
                Expanded(
                  child: Text(
                    widget.lesson.prompt.isNotEmpty ? widget.lesson.prompt : 'No description provided.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

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

// ─── Playlist Card ────────────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final LessonPlaylist playlist;
  final bool isDark;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaylistCard({
    required this.playlist,
    required this.isDark,
    required this.canEdit,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${playlist.lessonIds.length} Lessons',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AuthorName(
                          uid: playlist.createdByUid,
                          fallbackEmail: playlist.createdByEmail,
                          prefix: '',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit Playlist',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      tooltip: 'Delete Playlist',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                playlist.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  playlist.description.isNotEmpty ? playlist.description : 'Sequential learning playlist folder.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Start Sequential Journey',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
