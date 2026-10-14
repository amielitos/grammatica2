import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: (showRejected ? _kRejected : Colors.teal).withValues(alpha: 0.1),
                      child: Icon(
                        Icons.person_rounded,
                        color: showRejected ? _kRejected : Colors.teal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.applicantEmail,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Applied as ${app.applicationType.toUpperCase()}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: showRejected ? 'rejected' : 'pending'),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: AppColors.divider, size: 24),
                  ],
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

  @override
  Widget build(BuildContext context) {
    final credentials = <Map<String, dynamic>>[
      {'label': 'CV / Résumé', 'url': app.cvUrl, 'icon': Icons.description_rounded},
      ...app.certificateUrls.asMap().entries.map(
        (e) => {'label': 'Certificate ${e.key + 1}', 'url': e.value, 'icon': Icons.verified_rounded},
      ),
      {'label': 'Teaching Demo', 'url': app.videoUrl, 'icon': Icons.videocam_rounded},
      {'label': 'Syllabus', 'url': app.syllabusUrl, 'icon': Icons.book_rounded},
    ].where((c) => (c['url'] as String).isNotEmpty).toList();

    if (credentials.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CREDENTIALS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: credentials.map((c) {
              return _CredentialThumbnail(
                label: c['label'] as String,
                url: c['url'] as String,
                fallbackIcon: c['icon'] as IconData,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Single credential thumbnail
// ─────────────────────────────────────────────
class _CredentialThumbnail extends StatelessWidget {
  final String label;
  final String url;
  final IconData fallbackIcon;

  const _CredentialThumbnail({
    required this.label,
    required this.url,
    required this.fallbackIcon,
  });

  bool get _isImage {
    final lower = url.toLowerCase();
    final clean = lower.split('?').first;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].any(
      (ext) => clean.endsWith('.$ext') || lower.contains('.$ext?') || lower.contains('format=$ext'),
    );
  }

  bool get _isVideo {
    final lower = url.toLowerCase();
    final clean = lower.split('?').first;
    return ['mp4', 'mov', 'avi', 'webm', 'm4v', 'mkv', 'ogv'].any(
      (ext) => clean.endsWith('.$ext') || lower.contains('.$ext?') || lower.contains('/video'),
    );
  }

  bool get _isPdf {
    final lower = url.toLowerCase();
    final clean = lower.split('?').first;
    return clean.endsWith('.pdf') || lower.contains('.pdf?') || lower.contains('pdf');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final labelTextColor = isDark ? Colors.white : AppColors.textPrimary;

    return GestureDetector(
      onTap: () => _previewFile(context),
      child: Container(
        width: 170,
        height: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildContentTile(isDark),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.18)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.open_in_full_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: cardBg,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: labelTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTile(bool isDark) {
    if (_isImage) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : _placeholder(isDark),
        errorBuilder: (context, error, stackTrace) => _placeholder(isDark),
      );
    }
    if (_isVideo) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill, size: 46, color: Color(0xFF81B655)),
              SizedBox(height: 6),
              Text('VIDEO DEMO', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ],
          ),
        ),
      );
    }
    if (_isPdf) {
      return Container(
        color: isDark ? const Color(0xFF2C1515) : const Color(0xFFFEF2F2),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_rounded, size: 46, color: Color(0xFFDC2626)),
              SizedBox(height: 6),
              Text('PDF DOC', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ],
          ),
        ),
      );
    }
    return Container(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(fallbackIcon, size: 46, color: isDark ? Colors.white38 : Colors.grey.shade400),
            const SizedBox(height: 6),
            Text('DOCUMENT', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isDark) => Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        child: Center(
          child: Icon(fallbackIcon, size: 36, color: isDark ? Colors.white30 : Colors.grey.shade300),
        ),
      );

  void _previewFile(BuildContext context) {
    String ext = 'pdf';
    if (_isImage) {
      ext = 'png';
    } else if (_isVideo) {
      ext = 'mp4';
    } else if (_isPdf) {
      ext = 'pdf';
    }
    final fileName = '${label.toLowerCase().replaceAll(' ', '_')}.$ext';
    showFilePreviewModal(context, url, fileName);
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
