import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../widgets/author_name_widget.dart';
import '../../theme/app_colors.dart';
import '../../widgets/application_preview_widgets.dart';

// ─────────────────────────────────────────────
//  Status label helpers
// ─────────────────────────────────────────────
const _kPending = Color(0xFFE8A838);
const _kRejected = Color(0xFFE05050);

class ValidatorDashboardTab extends StatelessWidget {
  final Function(int)? onReviewRequests;
  const ValidatorDashboardTab({super.key, this.onReviewRequests});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2C3E50);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF7F8C8D);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF9F6);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Badge ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'OFFICIAL VALIDATOR PANEL',
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Headline ───────────────────────────────────────────
                Text(
                  'Validator Dashboard',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Review and verify educational content to maintain platform quality.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 60),

                // ── Stats row (pending + rejected) ─────────────────────
                _StatsGrid(onReviewRequests: onReviewRequests, isDark: isDark),

                const SizedBox(height: 60),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 40),

                // ── Pending sections ───────────────────────────────────
                _buildSectionHeader('Pending Lessons & Material Packages', Icons.auto_stories, _kPending, textPrimary),
                const SizedBox(height: 16),
                _buildLessonsList(context, showRejected: false, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary),
                const SizedBox(height: 40),

                _buildSectionHeader('Pending Educator Applications', Icons.how_to_reg, Colors.teal, textPrimary),
                const SizedBox(height: 16),
                _buildApplicationsList(context, showRejected: false, cardColor: cardColor, textPrimary: textPrimary),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // ── Content lists ──────────────────────────────────────────────────────────
  Widget _buildLessonsList(BuildContext context, {required bool showRejected, required Color cardColor, required Color textPrimary, required Color textSecondary}) {
    final stream = showRejected
        ? DatabaseService.instance.streamRejectedLessons()
        : DatabaseService.instance.streamAwaitingApprovalLessons();
    return StreamBuilder<List<Lesson>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingShimmer();
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyState(
            showRejected ? 'No rejected lessons' : 'No pending lessons to validate',
            showRejected ? Icons.check_circle_outlined : Icons.done_all_rounded,
            showRejected ? _kRejected : _kPending,
            textSecondary,
          );
        }
        return Column(
          children: items.map((l) => _buildContentCard(
            context,
            title: l.title,
            subtitleWidget: AuthorName(
              uid: l.createdByUid,
              fallbackEmail: l.createdByEmail,
              style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
            ),
            icon: Icons.description_rounded,
            iconColor: showRejected ? _kRejected : _kPending,
            status: showRejected ? 'rejected' : 'pending',
            onTap: () => onReviewRequests?.call(showRejected ? 2 : 0),
            cardColor: cardColor,
            textPrimary: textPrimary,
          )).toList(),
        );
      },
    );
  }

  Widget _buildApplicationsList(BuildContext context, {required bool showRejected, required Color cardColor, required Color textPrimary}) {
    final stream = showRejected
        ? DatabaseService.instance.streamRejectedApplications()
        : DatabaseService.instance.streamEducatorApplications(type: 'educator');
    return StreamBuilder<List<EducatorApplication>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingShimmer();
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _buildEmptyState(
            showRejected ? 'No rejected applications' : 'No pending educator applications',
            showRejected ? Icons.check_circle_outlined : Icons.verified_user_rounded,
            showRejected ? _kRejected : Colors.teal,
            textPrimary,
          );
        }
        return Column(
          children: items.map((a) => _buildApplicationCard(
            context,
            app: a,
            showRejected: showRejected,
            onTap: () => onReviewRequests?.call(showRejected ? 2 : 1),
            cardColor: cardColor,
            textPrimary: textPrimary,
          )).toList(),
        );
      },
    );
  }

  // ── Generic content card ───────────────────────────────────────────────────
  Widget _buildContentCard(
    BuildContext context, {
    required String title,
    required Widget subtitleWidget,
    required IconData icon,
    required Color iconColor,
    required String status,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textPrimary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == 'rejected'
              ? _kRejected.withValues(alpha: 0.2)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      subtitleWidget,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(status: status),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: AppColors.divider, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Application card (with credential thumbnails) ──────────────────────────
  Widget _buildApplicationCard(
    BuildContext context, {
    required EducatorApplication app,
    required bool showRejected,
    VoidCallback? onTap,
    required Color cardColor,
    required Color textPrimary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: showRejected
              ? _kRejected.withValues(alpha: 0.18)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with applicant details
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users').doc(app.applicantUid).snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final firstName = (data?['first_name'] as String?)?.trim() ?? '';
                    final lastName = (data?['last_name'] as String?)?.trim() ?? '';
                    final fullName = '$firstName $lastName'.trim();
                    final username = (data?['username'] as String?)?.trim();
                    final photoUrl = data?['photoUrl'] as String?;
                    final dob = data?['date_of_birth'] as Timestamp?;
                    final createdAt = data?['createdAt'] as Timestamp?;

                    final displayName = fullName.isNotEmpty
                        ? fullName
                        : (username != null && username.isNotEmpty ? username : app.applicantEmail);

                    int? age;
                    if (dob != null) {
                      final bDate = dob.toDate();
                      final now = DateTime.now();
                      age = now.year - bDate.year;
                      if (now.month < bDate.month || (now.month == bDate.month && now.day < bDate.day)) age--;
                    }

                    String joinedStr = 'N/A';
                    if (createdAt != null) {
                      final d = createdAt.toDate();
                      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                      joinedStr = '${months[d.month - 1]} ${d.day}, ${d.year}';
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: (showRejected ? _kRejected : Colors.teal).withValues(alpha: 0.12),
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Icon(
                                  Icons.person_rounded,
                                  color: showRejected ? _kRejected : Colors.teal,
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${app.applicantEmail} • Applied as ${app.applicationType.toUpperCase()}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      age != null ? 'Age: $age yrs old' : 'Age: Not set',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      'Member since: $joinedStr',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                                    ),
                                  ),
                                  if (app.appliedAt != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF81B655).withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        'Applied: ${_CredentialThumbnailRow._formatWordDate(app.appliedAt!)}',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF81B655)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: showRejected ? 'rejected' : 'pending'),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: AppColors.divider, size: 24),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Credential thumbnails (only for pending, since URLs are cleared on rejection)
          if (!showRejected) ...[
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _CredentialThumbnailRow(app: app),
            ),
          ] else ...[
            Divider(height: 1, color: _kRejected.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: _kRejected.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Text(
                    'Credential files removed after rejection.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _kRejected.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(String msg, IconData icon, Color color, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stats grid — pending counts only
// ─────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final Function(int)? onReviewRequests;
  final bool isDark;
  const _StatsGrid({this.onReviewRequests, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamAwaitingApprovalLessons(),
      builder: (ctx, lessonSnap) {
        return StreamBuilder<List<EducatorApplication>>(
          stream: DatabaseService.instance.streamEducatorApplications(type: 'educator'),
          builder: (ctx, appSnap) {
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _StatCard(
                  label: 'Pending Lessons & Materials',
                  value: lessonSnap.data?.length ?? 0,
                  icon: Icons.auto_stories_rounded,
                  color: _kPending,
                  onTap: () => onReviewRequests?.call(0),
                ),
                _StatCard(
                  label: 'Pending Educator Applications',
                  value: appSnap.data?.length ?? 0,
                  icon: Icons.how_to_reg_rounded,
                  color: Colors.teal,
                  onTap: () => onReviewRequests?.call(1),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


// ─────────────────────────────────────────────
//  Stat card widget
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? Colors.white60 : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              '$value',
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Credential thumbnail row
// ─────────────────────────────────────────────
class _CredentialThumbnailRow extends StatelessWidget {
  final EducatorApplication app;
  const _CredentialThumbnailRow({required this.app});

  void _preview(BuildContext context, String url, String label) {
    String ext = 'pdf';
    final lower = url.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].any((e) => lower.contains('.$e'))) {
      ext = 'png';
    } else if (['mp4', 'mov', 'avi', 'webm', 'mkv'].any((e) => lower.contains('.$e'))) {
      ext = 'mp4';
    }
    final fileName = '${label.toLowerCase().replaceAll(' ', '_')}.$ext';
    showFilePreviewModal(context, url, fileName);
  }

  Widget _buildRequirementItem({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Map<String, String>> files,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: files.isNotEmpty
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  files.isNotEmpty ? '${files.length} Submitted' : 'Missing',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: files.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Submitted File Card(s) Below Title
          if (files.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'No document submitted for this requirement.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            ...files.map((file) {
              final label = file['label'] ?? title;
              final url = file['url'] ?? '';
              final ext = file['ext'] ?? 'DOCUMENT';

              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ext.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Click preview to review applicant submission',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _preview(context, url, label),
                        icon: const Icon(Icons.visibility_rounded, size: 14),
                        label: const Text('Preview File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor.withValues(alpha: 0.15),
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static String _formatWordDate(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _extractFileName(String url, String? savedName, String fallback) {
    if (savedName != null && savedName.trim().isNotEmpty) {
      return savedName.trim();
    }
    if (url.isEmpty) return fallback;
    try {
      final uri = Uri.parse(url);
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      var decoded = Uri.decodeComponent(segment);
      if (decoded.contains('/')) decoded = decoded.split('/').last;
      final regex = RegExp(r'^\d{10,14}_(.+)$');
      final match = regex.firstMatch(decoded);
      if (match != null && match.group(1) != null) {
        decoded = match.group(1)!;
      }
      return decoded.isNotEmpty ? decoded : fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String _getFileExt(String fileName, String fallback) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'PDF';
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'IMG';
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') || lower.endsWith('.webm')) return 'VIDEO';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'DOC';
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cvLabel = _extractFileName(app.cvUrl, app.cvFileName, 'Applicant_CV_Resume.pdf');
    final cvFiles = <Map<String, String>>[
      if (app.cvUrl.isNotEmpty) {
        'label': cvLabel,
        'url': app.cvUrl,
        'ext': _getFileExt(cvLabel, 'PDF'),
      },
    ];

    final certFiles = app.certificateUrls
        .asMap()
        .entries
        .where((e) => e.value.isNotEmpty)
        .map((e) {
          final saved = (app.certificateFileNames != null && e.key < app.certificateFileNames!.length)
              ? app.certificateFileNames![e.key]
              : null;
          final certLabel = _extractFileName(e.value, saved, 'Teaching_Certificate_${e.key + 1}');
          return {
            'label': certLabel,
            'url': e.value,
            'ext': _getFileExt(certLabel, 'CERT'),
          };
        }).toList();

    final videoLabel = _extractFileName(app.videoUrl, app.videoFileName, 'Teaching_Demonstration.mp4');
    final videoFiles = <Map<String, String>>[
      if (app.videoUrl.isNotEmpty) {
        'label': videoLabel,
        'url': app.videoUrl,
        'ext': _getFileExt(videoLabel, 'VIDEO'),
      },
    ];

    final syllabusLabel = _extractFileName(app.syllabusUrl, app.syllabusFileName, 'Course_Syllabus.pdf');
    final syllabusFiles = <Map<String, String>>[
      if (app.syllabusUrl.isNotEmpty) {
        'label': syllabusLabel,
        'url': app.syllabusUrl,
        'ext': _getFileExt(syllabusLabel, 'SYLLABUS'),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'APPLICATION REQUIREMENTS & CREDENTIALS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF81B655).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'REQUIREMENTS VIEW',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF81B655)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Curriculum Vitae
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Curriculum Vitae (CV / Résumé)',
          subtitle: 'Educational background, employment history, and teaching experience',
          icon: Icons.description_rounded,
          accentColor: const Color(0xFF10B981),
          files: cvFiles,
        ),

        // 2. Teaching Certificates
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Teaching & Accreditation Certificates',
          subtitle: 'Accreditation certificates, teaching licenses, and academic diplomas',
          icon: Icons.verified_rounded,
          accentColor: const Color(0xFF3B82F6),
          files: certFiles,
        ),

        // 3. Teaching Demo Video
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Teaching Demonstration Video',
          subtitle: 'Recorded teaching demonstration showcasing instruction methodology',
          icon: Icons.videocam_rounded,
          accentColor: const Color(0xFF8B5CF6),
          files: videoFiles,
        ),

        // 4. Course Syllabus
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Course Syllabus / Instructional Plan',
          subtitle: 'Structured curriculum plan, lesson topics, and learning objectives',
          icon: Icons.menu_book_rounded,
          accentColor: const Color(0xFF0EA5E9),
          files: syllabusFiles,
        ),
      ],
    );
  }
}



// ─────────────────────────────────────────────
//  Status badge
// ─────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'rejected':
        color = _kRejected;
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      case 'approved':
        color = const Color(0xFF52A97B);
        label = 'Approved';
        icon = Icons.check_circle_rounded;
        break;
      default:
        color = _kPending;
        label = 'Pending';
        icon = Icons.access_time_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Loading shimmer placeholder
// ─────────────────────────────────────────────
class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: List.generate(2, (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
      )),
    );
  }
}
