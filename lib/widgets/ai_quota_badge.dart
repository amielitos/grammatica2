import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_rate_limit_service.dart';
import 'ai_quota_exceeded_dialog.dart';

/// A reactive pill badge displaying the user's remaining AI generations for the day.
class AIQuotaBadge extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const AIQuotaBadge({
    super.key,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<AIRateLimitStatus>(
      stream: AIRateLimitService.instance.quotaStream(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data!;
        final isUnlimited = status.isUnlimited;
        final remaining = status.remaining;
        final limit = status.limit;
        final isLow = !isUnlimited && remaining <= 2;
        final isOut = !isUnlimited && remaining == 0;

        Color badgeColor;
        Color textColor;
        if (isOut) {
          badgeColor = Colors.redAccent.withValues(alpha: 0.15);
          textColor = isDark ? Colors.redAccent.shade100 : Colors.red.shade700;
        } else if (isLow) {
          badgeColor = Colors.amber.withValues(alpha: 0.18);
          textColor = isDark ? Colors.amberAccent.shade100 : Colors.amber.shade900;
        } else {
          badgeColor = const Color(0xFF6366F1).withValues(alpha: 0.12);
          textColor = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);
        }

        final label = isUnlimited
            ? 'AI: Unlimited'
            : compact
                ? 'AI: $remaining/$limit'
                : 'AI: $remaining/$limit left today';

        return InkWell(
          onTap: onTap ??
              () {
                AIQuotaExceededDialog.showDetails(context, status);
              },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: textColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: compact ? 12 : 14,
                  color: textColor,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
