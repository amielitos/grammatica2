import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_rate_limit_service.dart';
import '../pages/manage_subscriptions_page.dart';
import 'ai_quota_exceeded_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Interactive popup message / toast that visually informs the user of their remaining
/// AI generations for the day whenever an AI action completes.
class AIQuotaNotification {
  static void show(
    BuildContext context, {
    required AIRateLimitStatus status,
    String? title,
    String? subtitle,
  }) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnlimited = status.isUnlimited;
    final remaining = status.remaining;
    final limit = status.limit;
    final isLow = !isUnlimited && remaining <= 2;
    final isOut = !isUnlimited && remaining == 0;

    Color accentColor;
    Color iconBg;
    if (isOut) {
      accentColor = Colors.redAccent;
      iconBg = Colors.red.withValues(alpha: 0.2);
    } else if (isLow) {
      accentColor = const Color(0xFFF59E0B);
      iconBg = Colors.amber.withValues(alpha: 0.2);
    } else {
      accentColor = const Color(0xFF6366F1);
      iconBg = const Color(0xFF6366F1).withValues(alpha: 0.2);
    }

    final headline = title ?? 'AI Generation Ready';
    final quotaText = isUnlimited
        ? 'Unlimited AI generations left today'
        : remaining == 1
            ? '1 generation left today'
            : status.used == 0
                ? '$remaining generations left today'
                : '$remaining of $limit generations left today';

    final resetText = 'Resets in ${status.formattedTimeUntilReset}';

    // Remove existing snackbars to avoid stacking delays
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          headline,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isUnlimited ? 'UNLIMITED' : '$remaining LEFT',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$quotaText • $resetText',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!isUnlimited && !status.isSubscribed && remaining <= 3)
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManageSubscriptionsPage(user: user),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Upgrade',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white70),
                  tooltip: 'Quota Info',
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    AIQuotaExceededDialog.showDetails(context, status);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
