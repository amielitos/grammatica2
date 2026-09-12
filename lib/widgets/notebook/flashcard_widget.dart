import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/flashcard_models.dart';
import '../../theme/app_colors.dart';

/// 3D flip flashcard widget that reveals answer on tap or swipe.
class FlashcardWidget extends StatefulWidget {
  final Flashcard card;
  final bool showHint;
  final VoidCallback? onFlipped;

  const FlashcardWidget({
    super.key,
    required this.card,
    this.showHint = true,
    this.onFlipped,
  });

  @override
  State<FlashcardWidget> createState() => FlashcardWidgetState();
}

class FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  bool get isFront => _isFront;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(FlashcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      // Reset flip when card changes
      _isFront = true;
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void flip() {
    if (_controller.isAnimating) return;

    if (_isFront) {
      _controller.forward();
      setState(() => _isFront = false);
    } else {
      _controller.reverse();
      setState(() => _isFront = true);
    }
    widget.onFlipped?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isUnder = (angle > (pi / 2));

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildBack(isDark),
                  )
                : _buildFront(isDark),
          );
        },
      ),
    );
  }

  Widget _buildFront(bool isDark) {
    return _buildCardShell(
      isDark: isDark,
      isFront: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top tag row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'QUESTION / TERM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.card.tags.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.card.tags.first,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),

          // Main Question text
          Center(
            child: Text(
              widget.card.front,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const Spacer(),

          // Bottom prompt
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap to reveal answer',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(bool isDark) {
    return _buildCardShell(
      isDark: isDark,
      isFront: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top tag row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ANSWER / DEFINITION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Main Answer text
          Center(
            child: Text(
              widget.card.back,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),

          if (widget.showHint && widget.card.hint != null && widget.card.hint!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFF5A623)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.card.hint!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF5A623),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),

          // Bottom prompt
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flip_to_front_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap to flip back',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardShell({
    required bool isDark,
    required bool isFront,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280, maxHeight: 380),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F291E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFront
              ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08))
              : const Color(0xFF3B82F6).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
