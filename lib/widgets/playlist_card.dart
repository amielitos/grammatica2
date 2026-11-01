import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/playlist.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/navigation_service.dart';
import '../services/role_service.dart';
import '../theme/app_colors.dart';
import '../pages/educator_profile_page.dart';
import 'author_name_widget.dart';

/// Reusable playlist card for learners, educators, and admins.
class PlaylistCard extends StatelessWidget {
  final LessonPlaylist playlist;
  final bool isDark;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.isDark,
    this.canEdit = false,
    this.onEdit,
    this.onDelete,
  });

  Future<void> _handleTap(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => PlaylistDetailModal(
        playlist: playlist,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
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
                            '${playlist.lessonIds.length} Lessons Sequence',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          AuthorName(
                            uid: playlist.createdByUid,
                            fallbackEmail: playlist.createdByEmail,
                            isClickable: true,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canEdit) ...[
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          tooltip: 'Edit Collection',
                          onPressed: onEdit,
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          tooltip: 'Delete Collection',
                          onPressed: onDelete,
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  playlist.title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (playlist.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    playlist.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81B655).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.route_rounded, size: 14, color: Color(0xFF81B655)),
                          const SizedBox(width: 4),
                          Text(
                            'Learning Path',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF81B655),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                      ],
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
}

class _SequenceItem {
  final String lessonId;
  final Lesson? lesson;
  final int orderNumber;
  final bool isPending;

  const _SequenceItem({
    required this.lessonId,
    required this.lesson,
    required this.orderNumber,
    required this.isPending,
  });
}

/// Modal showing playlist breakdown and allowing learners to jump in.
class PlaylistDetailModal extends StatelessWidget {
  final LessonPlaylist playlist;
  final bool isDark;

  const PlaylistDetailModal({
    super.key,
    required this.playlist,
    required this.isDark,
  });

  Future<void> _startAtLesson(BuildContext context, String lessonId) async {
    final lesson = await DatabaseService.instance.getLesson(lessonId);
    final currentUid = AuthService.instance.currentUser?.uid;
    final role = currentUid != null
        ? await RoleService.instance.getRole(currentUid)
        : UserRole.learner;
    if (!context.mounted) return;
    if (lesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load this lesson.')),
      );
      return;
    }
    final currentEmail = AuthService.instance.currentUser?.email?.toLowerCase();
    final canAccess = !lesson.isArchived &&
        (lesson.validationStatus == 'approved' ||
            (currentUid != null && lesson.createdByUid == currentUid) ||
            (currentEmail != null && lesson.createdByEmail?.toLowerCase() == currentEmail) ||
            (currentUid != null && playlist.createdByUid == currentUid) ||
            (currentEmail != null && playlist.createdByEmail.toLowerCase() == currentEmail) ||
            role == UserRole.validator ||
            role == UserRole.admin ||
            role == UserRole.superadmin ||
            role == UserRole.educator);
    if (!canAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This lesson is awaiting approval and is not yet available.')),
      );
      return;
    }
    Navigator.of(context).pop();
    NavigationService.instance.goToLesson(context, lesson, playlist: playlist);
  }

  Future<Map<String, dynamic>> _loadSequenceData() async {
    final currentUid = AuthService.instance.currentUser?.uid;
    final role = currentUid != null
        ? await RoleService.instance.getRole(currentUid)
        : UserRole.learner;
    final lessons = await Future.wait(
      playlist.lessonIds.map((id) => DatabaseService.instance.getLesson(id)),
    );
    return {
      'role': role,
      'lessons': lessons,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white60 : AppColors.textSecondary;

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadSequenceData(),
          builder: (context, snapshot) {
            final currentUid = AuthService.instance.currentUser?.uid;
            final currentEmail = AuthService.instance.currentUser?.email?.toLowerCase();
            final role = (snapshot.data?['role'] as UserRole?) ?? UserRole.learner;
            final lessons = (snapshot.data?['lessons'] as List<Lesson?>?) ?? [];

            final isEducatorOrStaff = role == UserRole.educator ||
                role == UserRole.admin ||
                role == UserRole.superadmin ||
                role == UserRole.validator ||
                (currentUid != null && playlist.createdByUid == currentUid) ||
                (currentEmail != null && playlist.createdByEmail.toLowerCase() == currentEmail);

            final items = <_SequenceItem>[];
            for (int i = 0; i < playlist.lessonIds.length; i++) {
              final lessonId = playlist.lessonIds[i];
              final lesson = i < lessons.length ? lessons[i] : null;
              final isApproved = lesson != null && !lesson.isArchived && lesson.validationStatus == 'approved';

              if (isEducatorOrStaff) {
                // Educators and staff can view the full sequence, with pending lessons marked clearly
                items.add(_SequenceItem(
                  lessonId: lessonId,
                  lesson: lesson,
                  orderNumber: i + 1,
                  isPending: !isApproved,
                ));
              } else {
                // Learners ONLY see approved, active lessons. Pending lessons are completely hidden!
                if (isApproved) {
                  items.add(_SequenceItem(
                    lessonId: lessonId,
                    lesson: lesson,
                    orderNumber: items.length + 1,
                    isPending: false,
                  ));
                }
              }
            }

            final visibleCount = snapshot.hasData ? items.length : null;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.title,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                AuthorName(
                                  uid: playlist.createdByUid,
                                  fallbackEmail: playlist.createdByEmail,
                                  prefix: 'By: ',
                                  isClickable: true,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF81B655),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                Text(
                                  visibleCount != null
                                      ? '• $visibleCount ${visibleCount == 1 ? "Lesson" : "Lessons"}'
                                      : '• ... Lessons',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                                if (playlist.createdByUid.isNotEmpty)
                                  InkWell(
                                    onTap: () async {
                                      final currentUser = FirebaseAuth.instance.currentUser;
                                      if (currentUser == null) return;
                                      final doc = await FirebaseFirestore.instance.collection('users').doc(playlist.createdByUid).get();
                                      final eduData = doc.data() ?? {'uid': playlist.createdByUid, 'email': playlist.createdByEmail};
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EducatorProfilePage(
                                              educator: {'uid': playlist.createdByUid, ...eduData},
                                              currentUser: currentUser,
                                              initialTab: 1, // Open directly to Playlists!
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF81B655).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.playlist_play_rounded, size: 14, color: Color(0xFF81B655)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Educator\'s Collections',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF81B655),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  if (playlist.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        playlist.description,
                        style: GoogleFonts.inter(fontSize: 13, color: textSecondary, height: 1.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Lessons in this sequence',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List of lessons
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.menu_book_rounded,
                                          size: 36,
                                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'No available lessons yet',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Lessons in this collection are currently awaiting review and will appear once approved.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final lesson = item.lesson;
                                  final isPending = item.isPending;

                                  final title = isPending
                                      ? (lesson?.title.isNotEmpty == true
                                          ? '${lesson!.title} (Pending Approval)'
                                          : 'Lesson ${item.orderNumber} (Pending Approval)')
                                      : (lesson?.title ?? 'Lesson ${item.orderNumber}');

                                  final prompt = isPending
                                      ? 'Awaiting validator approval • Visible only to educators'
                                      : (lesson?.prompt ?? 'Interactive lesson content');

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? (isDark ? const Color(0xFF2C2411) : const Color(0xFFFEFCE8))
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isPending
                                            ? const Color(0xFFE8A838).withValues(alpha: 0.4)
                                            : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () => _startAtLesson(context, item.lessonId),
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isPending
                                            ? const Color(0xFFE8A838).withValues(alpha: 0.2)
                                            : AppColors.primary.withValues(alpha: 0.15),
                                        child: Text(
                                          '${item.orderNumber}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isPending ? const Color(0xFFE8A838) : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isPending
                                              ? (isDark ? Colors.amber.shade300 : const Color(0xFFB45309))
                                              : textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        prompt,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: isPending
                                              ? (isDark ? Colors.amber.shade200 : const Color(0xFF92400E))
                                              : textSecondary,
                                        ),
                                      ),
                                      trailing: Icon(
                                        isPending ? Icons.hourglass_top_rounded : Icons.play_circle_fill_rounded,
                                        color: isPending ? const Color(0xFFE8A838) : AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startAtLesson(context, items.first.lessonId),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          'Start Collection Journey',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
