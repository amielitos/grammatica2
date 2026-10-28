import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../widgets/author_name_widget.dart';
import '../../theme/app_colors.dart';
import '../../widgets/application_preview_widgets.dart';
import '../../widgets/pagination_bar.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/auth_service.dart';

// ─────────────────────────────────────────────
//  Status label helpers
// ─────────────────────────────────────────────
const _kPending = Color(0xFFE8A838);
const _kRejected = Color(0xFFE05050);

String _formatDateTime(dynamic ts) {
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
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
  final minute = d.minute.toString().padLeft(2, '0');
  final amPm = d.hour >= 12 ? 'PM' : 'AM';
  return '${months[d.month - 1]} ${d.day}, ${d.year} at $hour:$minute $amPm';
}

class ValidatorDashboardTab extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? userData;
  final Function(int)? onReviewRequests;
  const ValidatorDashboardTab({
    super.key,
    this.user,
    this.userData,
    this.onReviewRequests,
  });

  @override
  State<ValidatorDashboardTab> createState() => _ValidatorDashboardTabState();
}

class _ValidatorDashboardTabState extends State<ValidatorDashboardTab> {
  bool _isUploadingPrc = false;
  bool _isDeletingPrc = false;
  int _lessonsPage = 1;
  static const int _lessonsPageSize = 5;
  int _validatorAppsPage = 1;
  static const int _validatorAppsPageSize = 5;
  int _educatorAppsPage = 1;
  static const int _educatorAppsPageSize = 5;

  Future<void> _deletePrc(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Document?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete your submitted PRC document? Your pending verification document will be removed and you can upload a new one.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text('Delete Document', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isDeletingPrc = true);
      await DatabaseService.instance.deleteValidatorApplication(uid);
      if (!mounted) return;
      setState(() => _isDeletingPrc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PRC Document deleted successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingPrc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete PRC document: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _uploadPrc(String uid, String email) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read file data. Please try again.')),
        );
        return;
      }
      if (file.size > 20 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File size must be under 20MB.')),
        );
        return;
      }

      setState(() => _isUploadingPrc = true);
      final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
      String contentType = 'application/pdf';
      if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'png') {
        contentType = 'image/png';
      }

      final downloadUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: uid,
        fileBytes: file.bytes!,
        fileName: file.name,
        contentType: contentType,
      );

      await DatabaseService.instance.submitValidatorApplication(
        uid: uid,
        email: email,
        prcUrl: downloadUrl,
        prcFileName: file.name,
      );

      if (!mounted) return;
      setState(() => _isUploadingPrc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PRC Document uploaded successfully! Your document is being reviewed.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPrc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload PRC Document: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? AuthService.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2C3E50);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF7F8C8D);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF9F6);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (user == null) {
      return Container(
        color: bgColor,
        child: const Center(child: Text('Please log in')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? widget.userData ?? {};
        final isVerified = data['isVerified'] == true;
        final statusStr = ((data['status'] as String?) ?? '').toLowerCase();
        final isUnderReview = statusStr == 'validator in review' || !isVerified;

        return Container(
          color: bgColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Header Banner ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1B2838), const Color(0xFF0D1117)]
                              : [const Color(0xFF6AAF3D), const Color(0xFF4A8A24)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? Colors.black : const Color(0xFF6AAF3D))
                                .withValues(alpha: 0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isUnderReview ? Icons.hourglass_top_rounded : Icons.verified_rounded,
                                        color: isUnderReview ? Colors.amberAccent : Colors.white,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isUnderReview ? 'APPLICATION UNDER REVIEW' : 'VALIDATOR DASHBOARD',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isUnderReview ? 'Verification in Progress' : 'Validator Hub',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Review and verify educational content to maintain platform quality and standards.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isUnderReview ? Icons.hourglass_top_rounded : Icons.verified_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (isUnderReview) ...[
                      // ── Review Notice & PRC Upload Section Inside Dashboard ──
                      StreamBuilder<EducatorApplication?>(
                        stream: DatabaseService.instance.streamUserApplication(user.uid),
                        builder: (context, appSnapshot) {
                          final app = appSnapshot.data;
                          final userPrcUrl = data['prc_url'] as String? ?? data['prcUrl'] as String?;
                          final userPrcName = (data['prc_file_name'] as String?) ?? (data['prcFileName'] as String?);

                          final effectivePrcUrl = (userPrcUrl != null && userPrcUrl.isNotEmpty)
                              ? userPrcUrl
                              : (app != null && app.applicationType == 'validator' && app.prcUrl.isNotEmpty ? app.prcUrl : null);
                          final effectivePrcFileName = userPrcName ??
                              (app != null && app.applicationType == 'validator' ? app.prcFileName : null) ??
                              'PRC_Teacher_Certificate';

                          return Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 760),
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? Colors.amber.shade800.withValues(alpha: 0.4) : Colors.amber.shade300,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 36),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Verification in Progress',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'You are not yet verified as a Validator, your document is still being reviewed by our team and can take 3-5 business days. Thank you for your patience with Grammatica.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                if (effectivePrcUrl != null && effectivePrcUrl.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.description_rounded,
                                                color: AppColors.primary,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'SUBMITTED VERIFICATION DOCUMENT',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.primary,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    effectivePrcFileName,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: textPrimary,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.pending_actions_rounded, size: 13, color: Colors.amber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'IN REVIEW',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.amber.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            FilledButton.tonalIcon(
                                              onPressed: () => showFilePreviewModal(
                                                context,
                                                effectivePrcUrl,
                                                effectivePrcFileName,
                                              ),
                                              icon: const Icon(Icons.visibility_rounded, size: 16),
                                              label: Text(
                                                'View Document',
                                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                                foregroundColor: AppColors.primary,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: _isDeletingPrc ? null : () => _deletePrc(user.uid),
                                              icon: _isDeletingPrc
                                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                                  : const Icon(Icons.delete_outline_rounded, size: 16),
                                              label: Text(
                                                _isDeletingPrc ? 'Deleting...' : 'Delete Document',
                                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                FilledButton.icon(
                                  onPressed: (_isUploadingPrc || _isDeletingPrc) ? null : () => _uploadPrc(user.uid, user.email ?? ''),
                                  icon: _isUploadingPrc
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.upload_file_rounded),
                                  label: Text(
                                    _isUploadingPrc
                                        ? 'Uploading PRC Document...'
                                        : (effectivePrcUrl != null && effectivePrcUrl.isNotEmpty ? 'Update PRC Document' : 'Upload PRC Document'),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ] else ...[
                      // ── Verified Validator View: Stats row + pending lessons ──
                      _StatsGrid(onReviewRequests: widget.onReviewRequests, isDark: isDark),

                      const SizedBox(height: 24),

                      _buildSectionHeader('Pending Lessons', Icons.auto_stories, _kPending, textPrimary),
                      const SizedBox(height: 12),
                      _buildLessonsList(context, showRejected: false, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Pending Educator Applications', Icons.how_to_reg, Colors.teal, textPrimary),
                      const SizedBox(height: 12),
                      _buildApplicationsList(context, type: 'educator', showRejected: false, cardColor: cardColor, textPrimary: textPrimary),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF81B655),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.3,
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

        final startIndex = (_lessonsPage - 1) * _lessonsPageSize;
        final clampedStart = startIndex >= items.length ? 0 : startIndex;
        if (startIndex >= items.length && _lessonsPage != 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _lessonsPage = 1);
          });
        }
        final endIndex = (clampedStart + _lessonsPageSize).clamp(0, items.length);
        final pageItems = items.sublist(clampedStart, endIndex);

        return Column(
          children: [
            ...pageItems.map((l) => _buildContentCard(
              context,
              title: l.title,
              subtitleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthorName(
                    uid: l.createdByUid,
                    fallbackEmail: l.createdByEmail,
                    style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                  ),
                  if (l.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: textSecondary.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text(
                          'Submitted: ${_formatDateTime(l.createdAt!)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: textSecondary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (l.isUpdate) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Creator wants to update already existing lesson.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              icon: Icons.description_rounded,
              iconColor: showRejected ? _kRejected : _kPending,
              status: showRejected ? 'rejected' : 'pending',
              onTap: () => widget.onReviewRequests?.call(showRejected ? 2 : 0),
              cardColor: cardColor,
              textPrimary: textPrimary,
            )),
            PaginationBar(
              currentPage: _lessonsPage,
              totalItems: items.length,
              pageSize: _lessonsPageSize,
              itemName: 'lessons',
              onPageChanged: (newPage) => setState(() => _lessonsPage = newPage),
            ),
          ],
        );
      },
    );
  }

  Widget _buildApplicationsList(
    BuildContext context, {
    String type = 'educator',
    required bool showRejected,
    required Color cardColor,
    required Color textPrimary,
  }) {
    final stream = showRejected
        ? DatabaseService.instance.streamRejectedApplications()
        : DatabaseService.instance.streamEducatorApplications(type: type);
    return StreamBuilder<List<EducatorApplication>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingShimmer();
        final items = snap.data ?? [];
        if (items.isEmpty) {
          final typeStr = type == 'validator' ? 'validator' : 'educator';
          return _buildEmptyState(
            showRejected ? 'No rejected $typeStr applications' : 'No pending $typeStr applications',
            showRejected ? Icons.check_circle_outlined : Icons.verified_user_rounded,
            showRejected ? _kRejected : (type == 'validator' ? Colors.indigo : Colors.teal),
            textPrimary,
          );
        }

        final isValidator = type == 'validator';
        final currentPage = isValidator ? _validatorAppsPage : _educatorAppsPage;
        final pageSize = isValidator ? _validatorAppsPageSize : _educatorAppsPageSize;

        final startIndex = (currentPage - 1) * pageSize;
        final clampedStart = startIndex >= items.length ? 0 : startIndex;
        if (startIndex >= items.length && currentPage != 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                if (isValidator) {
                  _validatorAppsPage = 1;
                } else {
                  _educatorAppsPage = 1;
                }
              });
            }
          });
        }
        final endIndex = (clampedStart + pageSize).clamp(0, items.length);
        final pageItems = items.sublist(clampedStart, endIndex);

        return Column(
          children: [
            ...pageItems.map((a) => _buildApplicationCard(
              context,
              app: a,
              showRejected: showRejected,
              onTap: () => widget.onReviewRequests?.call(showRejected ? 2 : 1),
              cardColor: cardColor,
              textPrimary: textPrimary,
            )),
            PaginationBar(
              currentPage: currentPage,
              totalItems: items.length,
              pageSize: pageSize,
              itemName: '$type applications',
              onPageChanged: (newPage) {
                setState(() {
                  if (isValidator) {
                    _validatorAppsPage = newPage;
                  } else {
                    _educatorAppsPage = newPage;
                  }
                });
              },
            ),
          ],
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
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF81B655)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Applied: ${_formatDateTime(app.appliedAt!)}',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF81B655)),
                                          ),
                                        ],
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
          builder: (ctx, eduSnap) {
            return StreamBuilder<List<Lesson>>(
              stream: DatabaseService.instance.streamRejectedLessons(),
              builder: (ctx, rejSnap) {
                final items = [
                  _StatCard(
                    label: 'Pending Lessons',
                    value: lessonSnap.data?.length ?? 0,
                    icon: Icons.auto_stories_rounded,
                    color: _kPending,
                    onTap: () => onReviewRequests?.call(0),
                  ),
                  _StatCard(
                    label: 'Educator Requests',
                    value: eduSnap.data?.length ?? 0,
                    icon: Icons.how_to_reg_rounded,
                    color: Colors.teal,
                    onTap: () => onReviewRequests?.call(1),
                  ),
                  _StatCard(
                    label: 'Rejected Content',
                    value: rejSnap.data?.length ?? 0,
                    icon: Icons.block_rounded,
                    color: _kRejected,
                    onTap: () => onReviewRequests?.call(2),
                  ),
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    if (isNarrow) {
                      return Column(
                        children: items
                            .map((w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: w,
                                ))
                            .toList(),
                      );
                    }

                    return Row(
                      children: items
                          .map((w) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: w,
                                ),
                              ))
                          .toList(),
                    );
                  },
                );
              },
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

    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$value',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ),
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
