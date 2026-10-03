import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TopNavBar extends StatelessWidget {
  const TopNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800; // Consistent breakpoint

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
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
                  height: 36,
                  errorBuilder: (ctx, err, st) => Row(
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        color: Color(0xFF81B655),
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Grammatica',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
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
          if (isDesktop) ...[
            _buildNavButton('All About Grammatica'),
            const SizedBox(width: 28),
            _buildNavButton("FAQ's"),
          ],
        ],
      ),
    );
  }

  Widget _buildNavButton(String text) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1D1B20),
          fontWeight: FontWeight.w500,
          fontSize: 15,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
