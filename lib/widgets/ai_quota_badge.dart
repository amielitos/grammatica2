import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_rate_limit_service.dart';
import 'ai_quota_exceeded_dialog.dart';

/// A reactive pill badge displaying the user's remaining AI generations for the day.
class AIQuotaBadge extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;
  final AIRateLimitStatus? statusOverride;

  const AIQuotaBadge({
    super.key,
    this.compact = false,
    this.onTap,
    this.statusOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (statusOverride != null) {
      return _buildBadge(context, statusOverride!);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<AIRateLimitStatus>(
      stream: AIRateLimitService.instance.quotaStream(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return _buildBadge(context, snapshot.data!);
      },
    );
  }

  Widget _buildBadge(BuildContext context, AIRateLimitStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnlimited = status.isUnlimited;
    final remaining = status.remaining;
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
            : isOut
                ? (compact ? 'AI: 0 left' : 'AI: 0 left today')
                : compact
                    ? 'AI: $remaining left'
                    : 'AI: $remaining left today';

        final tooltipMessage = isUnlimited
            ? 'Unlimited daily AI generations'
            : 'AI Quota: ${status.used} used of ${status.limit} ($remaining left today). Tap for details.';

        return Tooltip(
          message: tooltipMessage,
          child: InkWell(
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
          ),
        );
  }
}
