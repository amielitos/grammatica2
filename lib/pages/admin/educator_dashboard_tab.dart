import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/navigation_service.dart';
import '../../services/role_service.dart';
import '../../widgets/design_ornaments.dart';

class EducatorDashboardTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Function(int)? onTabChange;
  final Function(String)? onNamedNavigation;

  const EducatorDashboardTab({
    super.key,
    required this.userData,
    this.onTabChange,
    this.onNamedNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final username = (userData['username'] as String?)?.split(' ').first ?? 'Educator';
    final isPremium = (userData['subscription'] as String?)?.toLowerCase() == 'premium';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackgroundWrapper(
      child: SingleChildScrollView(
        key: const PageStorageKey('educator_dashboard_scroll_view'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Header Banner (Uniform with Learner Dashboard)
                _buildHeroHeader(context, username: username, isDark: isDark),
                const SizedBox(height: 16),

                // 2. Live Stats Overview (4 cards in responsive grid matching Learner Dashboard)
                _StatsOverview(uid: uid, isDark: isDark),
                const SizedBox(height: 24),

                // 3. Quick Actions
                _buildSectionTitle('Quick Actions', isDark),
                const SizedBox(height: 12),
                QuickActionsGrid(
                  onTabChange: onTabChange,
                  onNamedNavigation: onNamedNavigation,
                  isPremium: isPremium,
                ),
                const SizedBox(height: 24),

                // 4. Your Recent Lessons
                _buildSectionTitle('Your Recent Lessons', isDark),
                const SizedBox(height: 12),
                _RecentLessonsList(
                  uid: uid,
                  onTabChange: onTabChange,
                  onNamedNavigation: onNamedNavigation,
                ),
                const SizedBox(height: 24),

                // 5. My Quizzes
                _buildSectionTitle('My Quizzes', isDark),
                const SizedBox(height: 12),
                _MyQuizzesSection(
                  uid: uid,
                  onTabChange: onTabChange,
                  onNamedNavigation: onNamedNavigation,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
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
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(
    BuildContext context, {
    required String username,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF81B655),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_rounded, color: Colors.amberAccent, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'EDUCATOR DASHBOARD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome back, $username',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your curriculum, create interactive quizzes, and engage your learners.',
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
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Overview ──────────────────────────────────────────────────────────

class _StatsOverview extends StatelessWidget {
  final String uid;
  final bool isDark;

  const _StatsOverview({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final uData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final avgRating = (uData['averageRating'] ?? 0.0).toDouble();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lessons')
              .where('createdByUid', isEqualTo: uid)
              .snapshots(),
          builder: (context, lessonSnap) {
            final lessonDocs = lessonSnap.data?.docs ?? [];
            final approvedLessonCount = lessonDocs.where((d) {
              final data = d.data() as Map<String, dynamic>?;
              return data?['validationStatus'] == 'approved';
            }).length;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('quizzes')
                  .where('createdByUid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, quizSnap) {
                final quizCount = quizSnap.data?.docs.length ?? 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('subscribers')
                      .snapshots(),
                  builder: (context, subSnap) {
                    final subscriberCount = subSnap.data?.docs.length ?? 0;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;

                        Widget buildStatItem({
                          required IconData icon,
                          required Color color,
                          required String label,
                          required String value,
                        }) {
                          return Container(
                            height: 85,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isNarrow ? 7 : 10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: isNarrow ? 17 : 20),
                                ),
                                SizedBox(width: isNarrow ? 8 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: isNarrow ? 15 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        label,
                                        style: GoogleFonts.inter(
                                          fontSize: isNarrow ? 10 : 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final items = [
                          buildStatItem(
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF10B981),
                            label: 'Published Lessons',
                            value: '$approvedLessonCount',
                          ),
                          buildStatItem(
                            icon: Icons.quiz_rounded,
                            color: const Color(0xFFF59E0B),
                            label: 'My Quizzes',
                            value: '$quizCount',
                          ),
                          buildStatItem(
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF8B5CF6),
                            label: 'Enrolled Learners',
                            value: '$subscriberCount',
                          ),
                          buildStatItem(
                            icon: Icons.star_rounded,
                            color: const Color(0xFFEAB308),
                            label: 'Educator Rating',
                            value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '5.0',
                          ),
                        ];

                        if (isNarrow) {
                          return GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.15,
                            children: items,
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
      },
    );
  }
}

// ─── Quick Actions Grid ───────────────────────────────────────────────────────

class QuickActionsGrid extends StatelessWidget {
  final Function(int)? onTabChange;
  final Function(String)? onNamedNavigation;
  final bool isPremium;

  const QuickActionsGrid({
    super.key,
    this.onTabChange,
    this.onNamedNavigation,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        label: 'AI Notebooks',
        description: 'Generate lessons, quizzes & study aids with AI',
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF81B655),
        onTap: () {
          if (onNamedNavigation != null) {
            onNamedNavigation!('AI Notebooks');
          } else {
            onTabChange?.call(4);
          }
        },
      ),
      _ActionItem(
        label: 'My Lessons',
        description: 'Manage curriculum modules and publish content',
        icon: Icons.library_books_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () {
          if (onNamedNavigation != null) {
            onNamedNavigation!('Lessons');
          } else {
            onTabChange?.call(1);
          }
        },
      ),
      _ActionItem(
        label: 'Mentorship',
        description: 'Review and schedule 1-on-1 student sessions',
        icon: Icons.event_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () {
          if (onNamedNavigation != null) {
            onNamedNavigation!('Mentorship');
          } else {
            onTabChange?.call(2);
          }
        },
      ),
      _ActionItem(
        label: 'Practice & Quizzes',
        description: 'Interactive quizzes and student evaluation tests',
        icon: Icons.quiz_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () {
          if (onNamedNavigation != null) {
            onNamedNavigation!('Practice');
          } else {
            onTabChange?.call(3);
          }
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.map((a) {
            return SizedBox(
              width: cardWidth,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Recent Lessons List ─────────────────────────────────────────────────────

class _RecentLessonsList extends StatelessWidget {
  final String uid;
  final Function(int)? onTabChange;
  final Function(String)? onNamedNavigation;

  const _RecentLessonsList({
    required this.uid,
    this.onTabChange,
    this.onNamedNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamLessons(
        userRole: UserRole.educator,
        userId: uid,
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

        final allLessons = snapshot.data ?? [];

        // STRICT FILTER: Only show lessons created by this educator
        // When an educator account is newly made and has 0 lessons, do NOT fallback to other users' lessons.
        final myLessons = allLessons
            .where((l) => l.createdByUid == uid)
            .toList();

        myLessons.sort((a, b) {
          final tA = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tB = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return tB.compareTo(tA);
        });

        final recentLessons = myLessons.take(5).toList();

        if (recentLessons.isEmpty) {
          return _buildEmptyLessons(context, isDark);
        }

        return Column(
          children: recentLessons
              .map((l) => _LessonRow(
                    lesson: l,
                    onTap: () {
                      if (onNamedNavigation != null) {
                        onNamedNavigation!('Lessons');
                      } else {
                        onTabChange?.call(1);
                      }
                    },
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyLessons(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF81B655).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book_rounded, size: 32, color: Color(0xFF81B655)),
          ),
          const SizedBox(height: 14),
          Text(
            'No lessons published yet',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start sharing your knowledge — create your first lesson with AI Notebooks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              if (onNamedNavigation != null) {
                onNamedNavigation!('AI Notebooks');
              } else {
                onTabChange?.call(4);
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create First Lesson'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF81B655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
  final Function(String)? onNamedNavigation;

  const _MyQuizzesSection({
    required this.uid,
    this.onTabChange,
    this.onNamedNavigation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

        // STRICT FILTER: Only show quizzes created by this educator
        // When newly made, show empty state instead of other educators' quizzes.
        final myQuizzes = quizzes
            .where((q) => q.createdByUid == uid && !q.isAssessment)
            .toList();

        if (myQuizzes.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.quiz_rounded, size: 32, color: Color(0xFFF5A623)),
                ),
                const SizedBox(height: 14),
                Text(
                  'No quizzes created yet',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate interactive quizzes from your lessons and evaluate your learners.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    if (onNamedNavigation != null) {
                      onNamedNavigation!('AI Notebooks');
                    } else {
                      onTabChange?.call(4);
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create New Quiz'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: myQuizzes.take(6).map((quiz) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5A623).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.quiz_rounded, color: Color(0xFFF5A623), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                quiz.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          quiz.description.isNotEmpty ? quiz.description : 'Interactive practice quiz.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${quiz.questions.length} Questions',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF81B655),
                                ),
                              ),
                            ),
                            // VIEW QUIZ: Let educator inspect their quiz questions and answers
                            FilledButton.tonalIcon(
                              onPressed: () {
                                NavigationService.instance.goToQuiz(context, quiz, previewMode: true);
                              },
                              icon: const Icon(Icons.visibility_outlined, size: 14),
                              label: const Text('View Quiz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF81B655).withValues(alpha: 0.15),
                                foregroundColor: const Color(0xFF81B655),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
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
        return const Color(0xFF10B981);
      case 'awaiting_approval':
        return const Color(0xFFF5A623);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (lesson.validationStatus) {
      case 'approved':
        return 'Published';
      case 'awaiting_approval':
        return 'Pending Review';
      case 'rejected':
        return 'Needs Revision';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81B655).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF81B655), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(_statusIcon, color: _statusColor, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (lesson.isMembersOnly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'MEMBERS ONLY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
