import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/study_guide_models.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';

/// Clean, responsive slideshow presentation viewer for generated presentations.
/// Allows users to navigate through slides with Previous / Next buttons,
/// dot indicators, or arrow keys.
class PresentationView extends StatefulWidget {
  final Presentation presentation;
  final String notebookId;
  final String outputId;
  final bool isLearnerView;

  const PresentationView({
    super.key,
    required this.presentation,
    required this.notebookId,
    required this.outputId,
    this.isLearnerView = false,
  });

  @override
  State<PresentationView> createState() => _PresentationViewState();
}

class _PresentationViewState extends State<PresentationView> {
  int _currentSlideIndex = 0;
  bool _showNotes = false;
  final FocusNode _focusNode = FocusNode();

  List<PresentationSlide> get _slides => widget.presentation.slides;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _previousSlide() {
    if (_currentSlideIndex > 0) {
      setState(() => _currentSlideIndex--);
    }
  }

  void _nextSlide() {
    if (_currentSlideIndex < _slides.length - 1) {
      setState(() => _currentSlideIndex++);
    }
  }

  Future<void> _completePresentation() async {
    final user = AuthService.liveUser;
    if (widget.outputId.isNotEmpty) {
      await DatabaseService.instance.markContentCompleted(
        user: user,
        contentId: widget.outputId,
        completed: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presentation completed! Great job! 🎉'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previousSlide();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _nextSlide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_slides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.slideshow_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(
                'No slides available',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentSlide = _slides[_currentSlideIndex];
    final totalSlides = _slides.length;
    final isFirst = _currentSlideIndex == 0;
    final isLast = _currentSlideIndex == totalSlides - 1;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Deck Info & Publish
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.slideshow_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.presentation.title,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (widget.presentation.subtitle != null &&
                          widget.presentation.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.presentation.subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.slideshow_rounded, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        'Slide ${_currentSlideIndex + 1} of $totalSlides',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Slide Frame
            Container(
              constraints: const BoxConstraints(minHeight: 420),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Slide Top Banner with Category & Counter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282F3B) : const Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.view_carousel_rounded, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 6),
                                Text(
                                  'Slide ${_currentSlideIndex + 1} of $totalSlides',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (currentSlide.speakerNotes != null &&
                              currentSlide.speakerNotes!.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => setState(() => _showNotes = !_showNotes),
                              icon: Icon(
                                _showNotes ? Icons.notes_rounded : Icons.speaker_notes_outlined,
                                size: 16,
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                              label: Text(
                                _showNotes ? 'Hide Notes' : 'Speaker Notes',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Slide Body
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentSlide.subtitle != null && currentSlide.subtitle!.isNotEmpty) ...[
                            Text(
                              currentSlide.subtitle!.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            currentSlide.title,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Bullet points
                          ...currentSlide.bulletPoints.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final point = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${idx + 1}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        point,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Expandable Speaker Notes
                          if (_showNotes &&
                              currentSlide.speakerNotes != null &&
                              currentSlide.speakerNotes!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: isDark ? 0.1 : 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.record_voice_over_rounded, size: 16, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Speaker Notes',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentSlide.speakerNotes!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Controls Ribbon: [Previous Button] --- [Slide Dots] --- [Next Button]
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous Slide Button
                ElevatedButton.icon(
                  onPressed: isFirst ? null : _previousSlide,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text('Previous', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF282F3B) : Colors.white,
                    foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                    disabledForegroundColor: isDark ? Colors.white24 : Colors.grey.shade400,
                    disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    elevation: 0,
                  ),
                ),

                // Slide Dots indicator
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalSlides, (index) {
                        final isActive = index == _currentSlideIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _currentSlideIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 10,
                            width: isActive ? 28 : 10,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? Colors.white24 : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // Next Slide / Completed Button
                ElevatedButton.icon(
                  onPressed: isLast ? _completePresentation : _nextSlide,
                  icon: Text(
                    isLast ? 'Completed' : 'Next',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  label: Icon(
                    isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: isDark ? Colors.white24 : Colors.grey.shade400,
                    disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
