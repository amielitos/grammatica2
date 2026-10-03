import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaglineHeroText extends StatelessWidget {
  final String title;

  const TaglineHeroText({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.only(
        left: isMobile ? 20.0 : 60.0,
        right: isMobile ? 20.0 : 30.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: GoogleFonts.tiroDevanagariHindi(
              fontSize: isMobile ? 42 : 76,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2d5a27), // Deep elegant green matching design
              height: 1.1,
              shadows: const [
                Shadow(
                  offset: Offset(0, 8),
                  blurRadius: 16,
                  color: Color(0x33000000),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            "Smarter Grammar.",
            style: GoogleFonts.tiroDevanagariHindi(
              fontSize: isMobile ? 30 : 46,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.1,
              shadows: const [
                Shadow(
                  offset: Offset(0, 4),
                  blurRadius: 12,
                  color: Color(0x44000000),
                )
              ],
            ),
          ),

          Text(
            "Stronger Voice",
            style: GoogleFonts.tiroDevanagariHindi(
              fontSize: isMobile ? 30 : 46,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.1,
              shadows: const [
                Shadow(
                  offset: Offset(0, 4),
                  blurRadius: 12,
                  color: Color(0x44000000),
                )
              ],
            ),
          ),
          SizedBox(height: isMobile ? 24 : 48),

          // Feature Chips
          Wrap(
            spacing: isMobile ? 10 : 16,
            runSpacing: isMobile ? 10 : 16,
            children: [
              _buildFeatureChip(
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF4A90E2),
                label: 'Interactive Lessons',
                isMobile: isMobile,
              ),
              _buildFeatureChip(
                icon: Icons.auto_awesome,
                iconColor: const Color(0xFFFFB300),
                label: 'Grammar Mastery',
                isMobile: isMobile,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 16,
            spreadRadius: 2,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: isMobile ? 20 : 26),
          SizedBox(width: isMobile ? 8 : 12),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.tiroDevanagariHindi(
                fontSize: isMobile ? 15 : 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C3E50),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

