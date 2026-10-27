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
  String _selectedFilter = 'Create Date';
  final List<String> _filterOptions = ['Name', 'Status', 'Create Date'];
  final Set<String> _superAdminUids = {};
  int _activeView = 0; // 0: Lessons, 1: Playlists
  String? _activeFolder; // null: all, 'public': Public Lessons folder, 'members': Members Only Lessons folder

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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // View switcher
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
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
                                const SizedBox(width: 12),
                                // Create Playlist button
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
                                const SizedBox(width: 10),
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
                          const SizedBox(height: 16),
                          // ── 2 Folders: Public Lessons & Members Only Lessons ──
                          _buildFolderCardsRow(
                            context: context,
                            publicCount: lessons.where((l) => !l.isMembersOnly).length,
                            membersCount: lessons.where((l) => l.isMembersOnly).length,
                            isDark: isDark,
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
                else if (_activeFolder == 'public') ...[
                  // ── Folder View: Public Lessons Only ──
                  _buildLessonSectionHeader(
                    title: 'Folder: Public Lessons',
                    count: lessons.where((l) => !l.isMembersOnly).length,
                    icon: Icons.public_rounded,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    sliver: SliverLayoutBuilder(
                      builder: (context, slc) {
                        final isWide = slc.crossAxisExtent > 700;
                        final publicList = lessons.where((l) => !l.isMembersOnly).toList();
                        return _buildLessonSliverGrid(publicList, canEdit, isDark, isWide);
                      },
                    ),
                  ),
                ] else if (_activeFolder == 'members') ...[
                  // ── Folder View: Members-Only Lessons Only ──
                  _buildLessonSectionHeader(
                    title: 'Folder: Members Only Lessons',
                    count: lessons.where((l) => l.isMembersOnly).length,
                    icon: Icons.lock_rounded,
                    color: const Color(0xFF8E24AA),
                    isDark: isDark,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    sliver: SliverLayoutBuilder(
                      builder: (context, slc) {
                        final isWide = slc.crossAxisExtent > 700;
                        final membersList = lessons.where((l) => l.isMembersOnly).toList();
                        return _buildLessonSliverGrid(membersList, canEdit, isDark, isWide);
                      },
                    ),
                  ),
                ] else ...[
                  // ── Both Folders View: Separated Public & Members-Only Sections ──
                  _buildLessonSectionHeader(
                    title: 'Public Lessons Folder',
                    count: lessons.where((l) => !l.isMembersOnly).length,
                    icon: Icons.public_rounded,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, slc) {
                        final isWide = slc.crossAxisExtent > 700;
                        final publicList = lessons.where((l) => !l.isMembersOnly).toList();
                        return _buildLessonSliverGrid(publicList, canEdit, isDark, isWide);
                      },
                    ),
                  ),
                  _buildLessonSectionHeader(
                    title: 'Members Only Lessons Folder',
                    count: lessons.where((l) => l.isMembersOnly).length,
                    icon: Icons.lock_rounded,
                    color: const Color(0xFF8E24AA),
                    isDark: isDark,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    sliver: SliverLayoutBuilder(
                      builder: (context, slc) {
                        final isWide = slc.crossAxisExtent > 700;
                        final membersList = lessons.where((l) => l.isMembersOnly).toList();
                        return _buildLessonSliverGrid(membersList, canEdit, isDark, isWide);
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFolderCardsRow({
    required BuildContext context,
    required int publicCount,
    required int membersCount,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_shared_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Lesson Folders',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (_activeFolder != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filtered: ${_activeFolder == 'public' ? 'Public Lessons' : 'Members Only'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => setState(() => _activeFolder = null),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final publicCard = _buildFolderCard(
              title: 'Public Lessons',
              subtitle: 'Free & open access curriculum for all learners',
              count: publicCount,
              icon: Icons.public_rounded,
              color: AppColors.primary,
              isSelected: _activeFolder == 'public',
              isDark: isDark,
              onTap: () {
                setState(() {
                  _activeFolder = (_activeFolder == 'public') ? null : 'public';
                });
              },
            );

            final membersCard = _buildFolderCard(
              title: 'Members Only Lessons',
              subtitle: 'Exclusive lessons curated for enrolled members',
              count: membersCount,
              icon: Icons.lock_rounded,
              color: const Color(0xFF8E24AA),
              isSelected: _activeFolder == 'members',
              isDark: isDark,
              onTap: () {
                setState(() {
                  _activeFolder = (_activeFolder == 'members') ? null : 'members';
                });
              },
            );

            if (isNarrow) {
              return Column(
                children: [
                  publicCard,
                  const SizedBox(height: 12),
                  membersCard,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: publicCard),
                const SizedBox(width: 16),
                Expanded(child: membersCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFolderCard({
    required String title,
    required String subtitle,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.22 : 0.08)
                : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.folder_rounded, color: color, size: 34),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Icon(icon, color: Colors.white, size: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.folder_open_rounded : Icons.chevron_right_rounded,
                color: isSelected ? color : (isDark ? Colors.white38 : Colors.grey),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildLessonSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
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

    // Preference: Playlists can only include lessons authored by the creator (or official Grammatica lessons)
    final allowedLessons = allLessons.where((l) =>
      l.createdByUid == user.uid || l.isGrammaticaLesson == true
    ).toList();

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final selectedLessonIds = List<String>.from(existing?.lessonIds ?? []);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF242424) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            existing == null ? 'Create Lesson Playlist' : 'Edit Playlist',
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Playlist Title',
                        hintText: 'e.g. Master English Tenses in Order',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select & Arrange Lessons (${selectedLessonIds.length} selected)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lessons will be viewed sequentially in this order by learners.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: allowedLessons.isEmpty
                          ? Center(
                              child: Text(
                                'No authored or official Grammatica lessons available to add.',
                                style: GoogleFonts.inter(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: allowedLessons.length,
                              itemBuilder: (ctx, i) {
                                final lesson = allowedLessons[i];
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
                                    leading: isSelected
                                        ? CircleAvatar(
                                            radius: 14,
                                            backgroundColor: AppColors.primary,
                                            child: Text(
                                              '${orderIndex + 1}',
                                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        : const Icon(Icons.circle_outlined, size: 20, color: Colors.grey),
                                    title: Text(
                                      lesson.title,
                                      style: GoogleFonts.inter(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      lesson.isGrammaticaLesson ? 'Official Grammatica' : (lesson.createdByEmail ?? ''),
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
                              },
                            ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: selectedLessonIds.isEmpty || titleCtrl.text.trim().isEmpty
                              ? null
                              : () async {
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
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsSection(BuildContext context, List<Lesson> allLessons, bool isDark, String currentUid) {
    final stream = (widget.role == UserRole.admin || widget.role == UserRole.superadmin)
        ? DatabaseService.instance.streamAllPlaylists()
        : DatabaseService.instance.streamPlaylistsByCreator(currentUid);

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
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = playlists[index];
                return _PlaylistCard(
                  playlist: p,
                  isDark: isDark,
                  canEdit: p.createdByUid == currentUid || widget.role == UserRole.superadmin || widget.role == UserRole.admin,
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
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
                        ),
                        Text(
                          playlist.createdByEmail.isNotEmpty ? playlist.createdByEmail : 'Creator',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (canEdit) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit Playlist',
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      tooltip: 'Delete Playlist',
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                playlist.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  playlist.description.isNotEmpty ? playlist.description : 'Sequential learning playlist folder.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Start Sequential Journey',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
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
