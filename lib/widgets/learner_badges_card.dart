import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';
import '../theme/app_colors.dart';

class LearnerBadgesCard extends StatelessWidget {
  final String uid;

  const LearnerBadgesCard({
    super.key,
    required this.uid,
  });


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<BadgeModel>>(
      stream: BadgeService.instance.streamBadges(),
      builder: (context, badgesSnap) {
        final badges = badgesSnap.data ?? [];
        if (badgesSnap.connectionState == ConnectionState.waiting && badges.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ));
        }

        return StreamBuilder<Map<String, EarnedBadge>>(
          stream: BadgeService.instance.streamEarnedBadges(uid),
          builder: (context, earnedSnap) {
            final earnedMap = earnedSnap.data ?? {};

            return StreamBuilder<UserBadgeStats>(
              stream: BadgeService.instance.streamUserStats(uid),
              builder: (context, statsSnap) {
                final stats = statsSnap.data ?? const UserBadgeStats();

                final earnedCount = badges.where((b) => earnedMap.containsKey(b.id)).length;

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.military_tech_rounded,
                                    color: Color(0xFFF59E0B), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Badges & Achievements',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$earnedCount of ${badges.length} Unlocked',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      if (badges.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No badges available yet.',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth < 450
                                ? 2
                                : (constraints.maxWidth < 750 ? 3 : 5);

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.76,
                              ),
                              itemCount: badges.length,
                              itemBuilder: (context, index) {
                                final badge = badges[index];
                                final isEarned = earnedMap.containsKey(badge.id);
                                final currentProgress = stats.getStat(badge.criteriaType);

                                return _buildBadgeTile(
                                  context: context,
                                  badge: badge,
                                  isEarned: isEarned,
                                  currentProgress: currentProgress,
                                  isDark: isDark,
                                  earnedBadge: earnedMap[badge.id],
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBadgeTile({
    required BuildContext context,
    required BadgeModel badge,
    required bool isEarned,
    required int currentProgress,
    required bool isDark,
    EarnedBadge? earnedBadge,
  }) {
    final progressRatio = (currentProgress / badge.threshold).clamp(0.0, 1.0);

    return InkWell(
      onTap: () => _showBadgeDetail(context, badge, isEarned, currentProgress, earnedBadge, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEarned
                ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isEarned ? 1.5 : 1.0,
          ),
          boxShadow: isEarned
              ? [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon: Colorful SVG if earned, black or grey circle if locked
            Expanded(
              flex: 4,
              child: Center(
                child: isEarned
                    ? SvgPicture.asset(
                        badge.iconAsset,
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                      )
                    : Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFF64748B),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_rounded,
                            size: 22,
                            color: Colors.white54,
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 6),

            // Badge Name
            Text(
              badge.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isEarned
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white54 : const Color(0xFF64748B)),
              ),
            ),

            const SizedBox(height: 4),

            // Status / Progress
            if (isEarned) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF10B981)),
                    const SizedBox(width: 3),
                    Text(
                      'Earned',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Locked progress: e.g. 3/10
              Text(
                '$currentProgress/${badge.threshold}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressRatio > 0 ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(
    BuildContext context,
    BadgeModel badge,
    bool isEarned,
    int currentProgress,
    EarnedBadge? earnedBadge,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isEarned
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: isEarned
                  ? SvgPicture.asset(badge.iconAsset)
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFF64748B),
                          width: 2.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          size: 36,
                          color: Colors.white54,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Text(
                    isEarned
                        ? 'Completed (${badge.threshold}/${badge.threshold}) ✓'
                        : '$currentProgress of ${badge.threshold}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isEarned ? const Color(0xFF10B981) : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
