import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final bool showHoverEffect;

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
    this.borderColor,
    this.hoverBorderColor,
    this.isSolid = false, // Default to glass
    this.showHoverEffect = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Determine base color
    Color baseColor =
        widget.backgroundColor ??
        (isDark ? AppColors.cardNearBlack : AppColors.cardOffWhite);

    // 2. Determine border
    Color effectiveBorderColor = _isHovered
        ? (widget.hoverBorderColor ?? AppColors.primaryGreen)
        : (widget.borderColor ?? (isDark ? Colors.white24 : Colors.white));

    BorderSide borderSide = BorderSide(
      color: effectiveBorderColor,
      width: 2.0, // Constant width to prevent size shifts
    );

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.fromBorderSide(borderSide),
        boxShadow: widget.showHoverEffect
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark
                        ? (_isHovered ? 0.4 : 0.3)
                        : (_isHovered ? 0.1 : 0.05),
                  ),
                  blurRadius: _isHovered ? 25 : 20,
                  offset: Offset(0, _isHovered ? 12 : 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color:
              Theme.of(context).textTheme.bodyLarge?.color ??
              (isDark ? Colors.white : Colors.black),
        ),
        child: widget.child,
      ),
    );

    return Padding(
      padding: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = widget.showHoverEffect),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(onTap: widget.onTap, child: content),
      ),
    );
  }
}
