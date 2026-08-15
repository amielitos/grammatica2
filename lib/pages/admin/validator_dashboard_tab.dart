import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../widgets/author_name_widget.dart';
import '../../widgets/design_ornaments.dart';
import '../../theme/app_colors.dart';

class ValidatorDashboardTab extends StatelessWidget {
  final Function(int)? onReviewRequests;
  const ValidatorDashboardTab({super.key, this.onReviewRequests});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Premium Badge
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
                // Main Header
                Text(
                  'Validator Dashboard',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Review and verify educational content to maintain platform quality.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 60),
                
                // Stats Grid
                StreamBuilder<List<Lesson>>(
                  stream: DatabaseService.instance.streamAwaitingApprovalLessons(),
                  builder: (context, lessonSnap) {
                    final lessonCount = lessonSnap.data?.length ?? 0;
                    return StreamBuilder<List<Quiz>>(
                      stream: DatabaseService.instance.streamAwaitingApprovalQuizzes(),
                      builder: (context, quizSnap) {
                        final quizCount = quizSnap.data?.length ?? 0;
                        return StreamBuilder<List<Quiz>>(
                          stream: DatabaseService.instance.streamAwaitingApprovalAssessments(),
                          builder: (context, assessSnap) {
                            final assessCount = assessSnap.data?.length ?? 0;
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'EDUCATOR').snapshots(),
                              builder: (context, educSnap) {
                                final educCount = educSnap.data?.docs.length ?? 0;

                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Wrap(
                                      spacing: 20,
                                      runSpacing: 20,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildStatCard('Pending Lessons', lessonCount.toString(), Icons.menu_book_rounded, AppColors.secondary),
                                        _buildStatCard('Pending Quizzes', quizCount.toString(), Icons.quiz_rounded, const Color(0xFF4A90E2)),
                                        _buildStatCard('Pending Assessments', assessCount.toString(), Icons.assignment_turned_in_rounded, Colors.purple),
                                        _buildStatCard('Active Educators', educCount.toString(), Icons.school_rounded, AppColors.primary),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                
                const SizedBox(height: 60),
                
                // Content Layout Sections
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Lesson Requests', Icons.auto_stories, AppColors.primary),
                    const SizedBox(height: 16),
                    _buildLessonsList(context),
                    const SizedBox(height: 40),

                    _buildSectionHeader('Quizzes Requests', Icons.quiz_rounded, const Color(0xFF4A90E2)),
                    const SizedBox(height: 16),
                    _buildQuizzesList(context),
                    const SizedBox(height: 40),

                    _buildSectionHeader('Assessments Requests', Icons.assignment_turned_in_rounded, Colors.purple),
                    const SizedBox(height: 16),
                    _buildAssessmentsList(context),
                    const SizedBox(height: 40),

                    _buildSectionHeader('Verification Requests', Icons.how_to_reg, Colors.teal),
                    const SizedBox(height: 16),
                    _buildApplicationsList(context),
                  ],
                ),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.05), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamAwaitingApprovalLessons(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final lessons = snapshot.data ?? [];
        if (lessons.isEmpty) {
          return _buildEmptyState('No pending lessons to validate', Icons.done_all_rounded);
        }

        return Column(
          children: lessons.map((l) => _buildReviewCard(
            context,
            title: l.title,
            subtitle: AuthorName(
              uid: l.createdByUid,
              fallbackEmail: l.createdByEmail,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            icon: Icons.description_rounded,
            iconColor: AppColors.secondary,
            onTap: () => onReviewRequests?.call(0),
          )).toList(),
        );
      },
    );
  }

  Widget _buildQuizzesList(BuildContext context) {
    return StreamBuilder<List<Quiz>>(
      stream: DatabaseService.instance.streamAwaitingApprovalQuizzes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final quizzes = snapshot.data ?? [];
        if (quizzes.isEmpty) {
          return _buildEmptyState('No pending quizzes to validate', Icons.quiz_rounded);
        }

        return Column(
          children: quizzes.map((q) => _buildReviewCard(
            context,
            title: q.title,
            subtitle: AuthorName(
              uid: q.createdByUid,
              fallbackEmail: q.createdByEmail,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            icon: Icons.quiz_rounded,
            iconColor: const Color(0xFF4A90E2),
            onTap: () => onReviewRequests?.call(1),
          )).toList(),
        );
      },
    );
  }

  Widget _buildAssessmentsList(BuildContext context) {
    return StreamBuilder<List<Quiz>>(
      stream: DatabaseService.instance.streamAwaitingApprovalAssessments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final assessments = snapshot.data ?? [];
        if (assessments.isEmpty) {
          return _buildEmptyState('No pending assessments to validate', Icons.assignment_turned_in_rounded);
        }

        return Column(
          children: assessments.map((q) => _buildReviewCard(
            context,
            title: q.title,
            subtitle: AuthorName(
              uid: q.createdByUid,
              fallbackEmail: q.createdByEmail,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            icon: Icons.assignment_turned_in_rounded,
            iconColor: Colors.purple,
            onTap: () => onReviewRequests?.call(2),
          )).toList(),
        );
      },
    );
  }

  Widget _buildApplicationsList(BuildContext context) {
    return StreamBuilder<List<EducatorApplication>>(
      stream: DatabaseService.instance.streamEducatorApplications(type: 'educator'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final apps = snapshot.data ?? [];
        if (apps.isEmpty) {
          return _buildEmptyState('No pending educator applications', Icons.verified_user_rounded);
        }

        return Column(
          children: apps.map((a) => _buildReviewCard(
            context,
            title: a.applicantEmail,
            subtitle: Text(
              'Requested ${a.applicationType.toUpperCase()} role',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            icon: Icons.badge_rounded,
            iconColor: Colors.teal,
            onTap: () => onReviewRequests?.call(3),
          )).toList(),
        );
      },
    );
  }

  Widget _buildReviewCard(
    BuildContext context, {
    required String title,
    required Widget subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 20),
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
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      subtitle,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded, color: AppColors.divider, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
