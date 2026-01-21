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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Determine base color
    Color baseColor =
        backgroundColor ??
        (isDark ? AppColors.cardNearBlack : AppColors.cardOffWhite);

    // 2. Determine border
    BorderSide borderSide = BorderSide(
      color: isDark ? AppColors.darkBorder : AppColors.softBorder,
      width: 1.0,
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.fromBorderSide(borderSide),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        child: child,
      ),
    );

    // 3. Handle Taps
    if (onTap != null) {
      return Padding(
        padding: margin,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: content),
        ),
      );
    }

    return Padding(padding: margin, child: content);
  }
}
