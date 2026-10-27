import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  final String? imageAssetPath;

  const BackgroundWrapper({super.key, required this.child, this.imageAssetPath});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : AppColors.backgroundBase;

    return Container(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageAssetPath != null)
            Positioned.fill(
              child: Opacity(
                opacity: isDark ? 0.15 : 0.95,
                child: Image.asset(
                  imageAssetPath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          // Subtle elegant geometric background accents
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: isDark ? 0.02 : 0.035),
                  border: Border.all(
                    color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: isDark ? 0.05 : 0.07),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? Colors.white : AppColors.secondary).withValues(alpha: isDark ? 0.02 : 0.03),
                  border: Border.all(
                    color: (isDark ? Colors.white : AppColors.secondary).withValues(alpha: isDark ? 0.04 : 0.06),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

