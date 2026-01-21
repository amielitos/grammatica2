import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  /// If true, the card uses a solid background (no blur).
  /// If false, it applies a BackdropFilter (glass effect).
  final bool isSolid;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.isSolid = false, // Default to glass
  });

  @override
  Widget build(BuildContext context) {
    // 1. Determine base color (use provided or default opacity)
    Color baseColor = backgroundColor ?? AppColors.glassWhite;
    // If we want a strong glass effect, ensure opacity is < 1.0
    if (!isSolid && backgroundColor == null) {
      baseColor = AppColors.glassWhite;
    }

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    // 2. Wrap with Blur if not solid
    Widget styledBox = isSolid
        ? content
        : ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: content,
            ),
          );

    // 3. Handle Taps
    if (onTap != null) {
      return Padding(
        padding: margin,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: styledBox),
        ),
      );
    }

    return Padding(padding: margin, child: styledBox);
  }
}
