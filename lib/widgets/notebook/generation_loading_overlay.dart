import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';

/// Full-content loading overlay presented during AI output generation.
class GenerationLoadingOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;

  const GenerationLoadingOverlay({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  State<GenerationLoadingOverlay> createState() => _GenerationLoadingOverlayState();
}

class _GenerationLoadingOverlayState extends State<GenerationLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing AI Icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      const Color(0xFF5B8A38),
                      const Color(0xFF3B82F6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Shimmering Title Text
            Shimmer.fromColors(
              baseColor: isDark ? Colors.white : AppColors.textPrimary,
              highlightColor: AppColors.primary,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              widget.subtitle ?? 'Analyzing sources and grounding response...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Progress Bar Indicator
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  color: AppColors.primary,
                  minHeight: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
