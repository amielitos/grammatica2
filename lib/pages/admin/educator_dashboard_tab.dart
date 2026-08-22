import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_ornaments.dart';

class EducatorDashboardTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Function(int)? onTabChange;

  const EducatorDashboardTab({
    super.key,
    required this.userData,
    this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final username = (userData['username'] as String?)?.split(' ').first ?? 'Educator';
    final isPremium = (userData['subscription'] as String?)?.toLowerCase() == 'premium';

    return BackgroundWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // — Badge —
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'EDUCATOR PANEL',
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

                // — Title —
                Text(
                  'Welcome, $username!',
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
                  'Track your lessons, ratings, and teaching impact in one place.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 60),

                // — Stats Grid —
                _StatsRow(uid: uid),
                const SizedBox(height: 80),

                // — Quick Actions —
                _SectionHeader(
                  title: 'Quick Actions',
                  icon: Icons.bolt_rounded,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 28),
                _QuickActionsGrid(
                  onTabChange: onTabChange,
                  isPremium: isPremium,
                ),
                const SizedBox(height: 80),

                // — Recent Lessons —
                _SectionHeader(
                  title: 'Your Recent Lessons',
                  icon: Icons.auto_stories_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 28),
                _RecentLessonsList(uid: uid, onTabChange: onTabChange),

                const SizedBox(height: 80),

                // — My Quizzes —
                _SectionHeader(
                  title: 'My Quizzes',
                  icon: Icons.quiz_rounded,
                  color: const Color(0xFFF5A623),
                ),
                const SizedBox(height: 28),
                _MyQuizzesSection(uid: uid, onTabChange: onTabChange),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final String uid;
  const _StatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final uData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final avgRating = (uData['averageRating'] ?? 0.0).toDouble();
        final subscriberCount = (uData['subscriberCount'] ?? 0) as int;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lessons')
              .where('createdByUid', isEqualTo: uid)
              .snapshots(),
          builder: (context, lessonSnap) {
            final lessonCount = lessonSnap.data?.docs.length ?? 0;

            return Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _StatCard(
                  label: 'Total Lessons',
                  value: lessonCount.toString(),
                  icon: Icons.book_rounded,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Educator Rating',
                  value: avgRating.toStringAsFixed(1),
                  icon: Icons.star_rounded,
                  color: const Color(0xFFF5A623),
                ),
                _StatCard(
                  label: 'Subscribers',
                  value: subscriberCount.toString(),
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF4A90E2),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: color.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 56,
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
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
}

// ─── Quick Actions Grid ───────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final Function(int)? onTabChange;
  final bool isPremium;

  const _QuickActionsGrid({this.onTabChange, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        label: 'Create Lesson',
        description: 'Write & publish a new lesson',
        icon: Icons.add_circle_outline_rounded,
        color: AppColors.primary,
        onTap: () => onTabChange?.call(1),
      ),
      _ActionItem(
        label: 'My Lessons',
        description: 'View & edit existing content',
        icon: Icons.library_books_rounded,
        color: const Color(0xFF4A90E2),
        onTap: () => onTabChange?.call(2),
      ),
      _ActionItem(
        label: 'Mentorship',
        description: 'Manage student sessions',
        icon: Icons.event_rounded,
        color: const Color(0xFF9B59B6),
        onTap: () => onTabChange?.call(3),
      ),
      _ActionItem(
        label: 'My Quizzes',
        description: 'Browse & manage your quizzes',
        icon: Icons.quiz_rounded,
        color: const Color(0xFFF5A623),
        onTap: () => onTabChange?.call(1),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: actions.map((a) {
            return SizedBox(
              width: isNarrow
                  ? double.infinity
                  : (constraints.maxWidth - 20) / 2,
              child: _QuickActionCard(item: a),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionItem {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _ActionItem item;
  const _QuickActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: item.color.withValues(alpha: 0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(item.icon, color: item.color, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: item.color.withValues(alpha: 0.4), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Recent Lessons List ──────────────────────────────────────────────────────

class _RecentLessonsList extends StatelessWidget {
  final String uid;
  final Function(int)? onTabChange;

  const _RecentLessonsList({required this.uid, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamLessons(
        approvedOnly: true,
        userRole: UserRole.educator,
        userId: uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final allLessons = snapshot.data ?? [];

        // Filter for approved lessons created by this educator (or fallback to any approved lesson)
        var approvedLessons = allLessons
            .where((l) => (l.createdByUid == uid || uid.isEmpty) && l.validationStatus == 'approved')
            .toList();

        if (approvedLessons.isEmpty) {
          approvedLessons = allLessons.where((l) => l.validationStatus == 'approved').toList();
        }

        approvedLessons.sort((a, b) {
          final tA = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tB = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return tB.compareTo(tA);
        });

        final recentLessons = approvedLessons.take(5).toList();

        if (recentLessons.isEmpty) {
          return _buildEmptyLessons(context);
        }

        return Column(
          children: recentLessons
              .map((l) => _LessonRow(lesson: l, onTap: () => onTabChange?.call(2)))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyLessons(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_rounded,
              size: 56, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(
            'No approved lessons yet',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start sharing your knowledge — create your first lesson!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => onTabChange?.call(1),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create First Lesson'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── My Quizzes Section ───────────────────────────────────────────────────────

class _MyQuizzesSection extends StatelessWidget {
  final String uid;
  final Function(int)? onTabChange;

  const _MyQuizzesSection({required this.uid, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Quiz>>(
      stream: DatabaseService.instance.streamQuizzes(
        userRole: UserRole.educator,
        userId: uid,
        isAssessment: false,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final quizzes = snapshot.data ?? [];
        var myQuizzes = quizzes
            .where((q) => (q.createdByUid == uid || uid.isEmpty) && !q.isAssessment)
            .toList();

        if (myQuizzes.isEmpty) {
          myQuizzes = quizzes.where((q) => !q.isAssessment).toList();
        }

        if (myQuizzes.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.quiz_rounded,
                    size: 56, color: const Color(0xFFF5A623).withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  'No Quizzes Found',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create interactive quizzes to test student comprehension.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => onTabChange?.call(1),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: myQuizzes.take(6).map((quiz) {
            return SizedBox(
              width: 320,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5A623).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.quiz_rounded,
                              color: Color(0xFFF5A623), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            quiz.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      quiz.description.isNotEmpty
                          ? quiz.description
                          : 'Interactive practice quiz.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${quiz.questions.length} Questions',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => onTabChange?.call(1),
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}


class _LessonRow extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;

  const _LessonRow({required this.lesson, required this.onTap});

  Color get _statusColor {
    switch (lesson.validationStatus) {
      case 'approved':
        return AppColors.primary;
      case 'awaiting_approval':
        return const Color(0xFFF5A623);
      case 'rejected':
        return const Color(0xFFD32F2F);
      default:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (lesson.validationStatus) {
      case 'approved':
        return 'Published';
      case 'awaiting_approval':
        return 'Pending Review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Draft';
    }
  }

  IconData get _statusIcon {
    switch (lesson.validationStatus) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'awaiting_approval':
        return Icons.hourglass_top_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
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
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 20),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(_statusIcon, color: _statusColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.divider, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
