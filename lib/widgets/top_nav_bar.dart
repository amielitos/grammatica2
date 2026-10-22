import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class TopNavBar extends StatelessWidget {
  const TopNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800; // Consistent breakpoint
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo + Text Group (Identical to Landing Page Header)
          InkWell(
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logotext.png',
                  height: isDesktop ? 36 : 28,
                  errorBuilder: (ctx, err, st) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language_rounded,
                        color: const Color(0xFF81B655),
                        size: isDesktop ? 32 : 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Grammatica',
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 22 : 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildNavButton(
            context,
            'About Us',
            isDark,
            onTap: () => _showAboutUsDialog(context),
            isDesktop: isDesktop,
          ),
          SizedBox(width: isDesktop ? 16 : 8),
          // Light/Dark mode toggle button
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              final activeDark = mode == ThemeMode.dark ||
                  (mode == ThemeMode.system &&
                      MediaQuery.of(context).platformBrightness ==
                          Brightness.dark);
              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF81B655).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: EdgeInsets.all(isDesktop ? 8 : 6),
                  constraints: const BoxConstraints(),
                  tooltip: activeDark
                      ? 'Switch to Light Mode'
                      : 'Switch to Dark Mode',
                  icon: Icon(
                    activeDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: activeDark
                        ? Colors.amberAccent
                        : const Color(0xFF81B655),
                    size: isDesktop ? 20 : 18,
                  ),
                  onPressed: () {
                    themeNotifier.value =
                        activeDark ? ThemeMode.light : ThemeMode.dark;
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    String text,
    bool isDark, {
    VoidCallback? onTap,
    bool isDesktop = true,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 6, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF1D1B20),
          fontWeight: FontWeight.w600,
          fontSize: isDesktop ? 15 : 13,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  void _showAboutUsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final developers = [
      {
        'name': 'Amiel Espeña',
        'role': 'Programmer Specialist',
        'icon': Icons.code_rounded,
        'color': const Color(0xFF81B655),
      },
      {
        'name': 'Sophia Beatrice Sadie',
        'role': 'Quality Assurance Specialist',
        'icon': Icons.verified_user_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'name': 'Nathalie Ybañez',
        'role': 'Project Manager',
        'icon': Icons.assignment_ind_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'name': 'Juan Paolo Fajardo',
        'role': 'System Analyst',
        'icon': Icons.analytics_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF81B655).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.people_alt_rounded,
                              color: Color(0xFF81B655),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About Us',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Development Team',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    height: 1,
                  ),
                  const SizedBox(height: 18),
                  ...developers.map((dev) {
                    final color = dev['color'] as Color;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(dev['icon'] as IconData, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev['name'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dev['role'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81B655),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
