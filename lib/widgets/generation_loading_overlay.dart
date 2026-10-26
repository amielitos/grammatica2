import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Full-content loading overlay presented during AI output generation.
class GenerationLoadingOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;

  const GenerationLoadingOverlay({
    super.key,
    required this.title,
    this.subtitle,
  });

  /// Returns a full-barrier overlay widget suitable for use directly in a [Stack].
  ///
  /// Blocks all pointer events and dims the screen with a smooth overlay
  /// matching the Educator's Notebook design.
  static Widget fullBarrier({
    required BuildContext context,
    required String title,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
          child: GenerationLoadingOverlay(
            title: title,
            subtitle: subtitle,
          ),
        ),
      ),
    );
  }

  /// Displays a modal non-dismissible loading dialog with the animated overlay.
  static Future<T> showAsDialog<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Future<T> Function() task,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: GenerationLoadingOverlay(
              title: title,
              subtitle: subtitle,
            ),
          ),
        ),
      ),
    );

    try {
      final result = await task();
      return result;
    } finally {
      if (dialogOpen && context.mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

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
            // Educational Progress Indicator
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ],
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
