import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pages/manage_subscriptions_page.dart';
import '../services/ai_rate_limit_service.dart';
import '../services/role_service.dart';

/// Modal dialog displayed when an AI rate limit or quota is encountered.
class AIQuotaExceededDialog extends StatelessWidget {
  final AIRateLimitStatus? status;
  final Duration? cooldownRemaining;
  final bool isBurst;

  const AIQuotaExceededDialog({
    super.key,
    this.status,
    this.cooldownRemaining,
    this.isBurst = false,
  });

  /// Displays the dialog when the daily generation quota is completely exhausted.
  static Future<void> showExceeded(
    BuildContext context,
    AIRateLimitStatus status,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AIQuotaExceededDialog(
        status: status,
        isBurst: false,
      ),
    );
  }

  /// Displays a brief warning when the short-term burst cooldown is active.
  static Future<void> showBurst(
    BuildContext context,
    Duration cooldown,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AIQuotaExceededDialog(
        cooldownRemaining: cooldown,
        isBurst: true,
      ),
    );
  }

  /// Displays information about current AI quota status when user taps the badge.
  static Future<void> showDetails(
    BuildContext context,
    AIRateLimitStatus status,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AIQuotaExceededDialog(
        status: status,
        isBurst: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (isBurst) {
      final seconds = cooldownRemaining?.inSeconds ?? 10;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please Slow Down',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI requests are limited to prevent server overload. Please wait $seconds seconds before requesting another generation.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Understood'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stat = status ??
        const AIRateLimitStatus(
          used: 10,
          limit: 10,
          date: '',
          role: UserRole.learner,
          isSubscribed: false,
        );

    final isExceeded = stat.isExceeded;
    final isFreeLearner = stat.role == UserRole.learner && !stat.isSubscribed;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isExceeded ? Colors.redAccent : const Color(0xFF6366F1))
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExceeded
                    ? Icons.block_rounded
                    : Icons.auto_awesome_rounded,
                color: isExceeded ? Colors.redAccent : const Color(0xFF6366F1),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isExceeded ? 'Daily AI Limit Reached' : 'AI Generations Quota',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isExceeded
                  ? 'You have used all ${stat.limit} of your daily AI generations. Your quota will automatically reset at midnight.'
                  : stat.isUnlimited
                      ? 'You have unlimited AI generations with your current role.'
                      : 'You have used ${stat.used} out of ${stat.limit} AI generations today.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Progress bar if not unlimited
            if (!stat.isUnlimited) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: stat.percentUsed,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isExceeded
                        ? Colors.redAccent
                        : stat.remaining <= 2
                            ? Colors.amber
                            : const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining: ${stat.remaining}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  Text(
                    'Resets in ${stat.formattedTimeUntilReset}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Upgrade banner if free learner
            if (isFreeLearner) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need more AI power?',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Enrolled learners get 100 AI generations every day.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('Upgrade Enrollment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ManageSubscriptionsPage(user: user),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
