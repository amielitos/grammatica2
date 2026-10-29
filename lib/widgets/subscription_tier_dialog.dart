import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionTierDialog extends StatelessWidget {
  final Map<String, dynamic>? pricing;
  final String educatorName;
  final String? currentTier;

  const SubscriptionTierDialog({
    super.key,
    required this.pricing,
    required this.educatorName,
    this.currentTier,
  });

  @override
  Widget build(BuildContext context) {
    final premiumPrice = pricing?['premium'] ?? 7;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 700;

    final normalizedCurrent = currentTier?.trim().toLowerCase();
    final bool showPremium = normalizedCurrent != 'premium';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFAF9F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 40.0,
        vertical: isMobile ? 24.0 : 32.0,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: screenHeight * 0.90,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20.0 : 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Title and Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Upgrade to Premium with $educatorName',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 18 : 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable Tier Cards
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      if (showPremium) ...[
                        // Premium Tier Card
                        _buildTierCard(
                          context,
                          isDark: isDark,
                          tier: 'Premium',
                          price: '\$$premiumPrice/mo',
                          badgeText: 'Exclusive & Mentorship',
                          badgeColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          badgeTextColor: const Color(0xFF7C3AED),
                          subtitle: 'For learners who want exclusive lessons, personal guidance, and mentorship.',
                          inclusions: const [
                            'Full access to all public and exclusive lessons by this educator',
                            'Access to educator-only learning materials marked for enrolled learners',
                            'Personal 1-on-1 mentorship with the educator',
                            'Opportunity to ask questions and receive dedicated guidance',
                            'Personalized feedback on learning progress',
                            'Priority access to mentorship sessions',
                            'Enrollment applies directly to this educator',
                          ],
                          buttonColor: const Color(0xFFF67576),
                          buttonTextColor: Colors.white,
                        ),
                      ],

                      if (!showPremium)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'You are already enrolled with $educatorName (Premium).',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context, {
    required bool isDark,
    required String tier,
    required String price,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String subtitle,
    required List<String> inclusions,
    required Color buttonColor,
    required Color buttonTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tier,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, tier),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonTextColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  price,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: buttonTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Inclusions List
          ...inclusions.map((item) {
            final isNegative = item.startsWith('No ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      isNegative ? Icons.remove_circle_outline_rounded : Icons.check_circle_rounded,
                      size: 15,
                      color: isNegative
                          ? (isDark ? Colors.white30 : Colors.grey.shade400)
                          : const Color(0xFF81B655),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isNegative
                            ? (isDark ? Colors.white38 : Colors.grey.shade500)
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        height: 1.35,
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
}
