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
}
