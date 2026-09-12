import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notebook_models.dart';
import '../../theme/app_colors.dart';

/// Confirmation dialog presented before generating an AI notebook output.
/// Provides a concise description of the output, an assessment-style selector
/// if generating a quiz, a list of active sources, and an explicit confirmation button.
class GenerationConfirmDialog extends StatefulWidget {
  final NotebookOutputType type;
  final List<NotebookSource> sources;
  final bool hasExistingOutput;

  const GenerationConfirmDialog({
    super.key,
    required this.type,
    required this.sources,
    this.hasExistingOutput = false,
  });

  @override
  State<GenerationConfirmDialog> createState() => _GenerationConfirmDialogState();
}

class _GenerationConfirmDialogState extends State<GenerationConfirmDialog> {
  bool _isAssessment = false;

  String _getTypeDescription(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.lesson:
        return 'Generates an interactive, structured lesson with key concepts, rich markdown formatting, and clear pedagogical explanations based on your sources.';
      case NotebookOutputType.flashcards:
        return 'Creates high-yield study flashcards with key terms, definitions, and front/back pairs optimized for active recall.';
      case NotebookOutputType.quiz:
        return 'Generates comprehensive assessment questions with answer keys and explanations based on your ingested source materials.';
      case NotebookOutputType.studyGuide:
        return 'Compiles an in-depth study guide featuring key takeaways, essential vocabulary terms, and chapter-by-chapter summaries.';
      case NotebookOutputType.timeline:
        return 'Constructs a chronological milestone sequence tracking key historical events, steps, or developments.';
      case NotebookOutputType.briefing:
        return 'Synthesizes an executive overview summarizing primary arguments, important takeaways, and critical insights.';
      case NotebookOutputType.faq:
        return 'Answers the most frequently asked questions and foundational concepts extracted from your sources.';
      case NotebookOutputType.mindMap:
        return 'Constructs a visual hierarchical mind map connecting central topics to sub-concepts and branches.';
    }
  }

  IconData _getTypeIcon(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.lesson:
        return Icons.school_rounded;
      case NotebookOutputType.flashcards:
        return Icons.style_rounded;
      case NotebookOutputType.quiz:
        return Icons.quiz_rounded;
      case NotebookOutputType.studyGuide:
        return Icons.menu_book_rounded;
      case NotebookOutputType.timeline:
        return Icons.timeline_rounded;
      case NotebookOutputType.briefing:
        return Icons.assignment_rounded;
      case NotebookOutputType.faq:
        return Icons.help_outline_rounded;
      case NotebookOutputType.mindMap:
        return Icons.hub_rounded;
    }
  }

  Color _getTypeColor(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.lesson:
        return const Color(0xFF10B981);
      case NotebookOutputType.flashcards:
        return const Color(0xFF3B82F6);
      case NotebookOutputType.quiz:
        return const Color(0xFFEF4444);
      case NotebookOutputType.studyGuide:
        return AppColors.primary;
      case NotebookOutputType.timeline:
        return const Color(0xFF8B5CF6);
      case NotebookOutputType.briefing:
        return const Color(0xFF14B8A6);
      case NotebookOutputType.faq:
        return const Color(0xFFF59E0B);
      case NotebookOutputType.mindMap:
        return const Color(0xFFEC4899);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getTypeColor(widget.type);
    final icon = _getTypeIcon(widget.type);
    final readySources = widget.sources
        .where((s) => s.processingStatus == SourceProcessingStatus.ready && s.rawContent.isNotEmpty)
        .toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E261D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon & Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate ${widget.type.displayName}',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Grammatica AI Notebook Assistant',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  _getTypeDescription(widget.type),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
              ),

              // Quiz Type Selector (Only if Quiz)
              if (widget.type == NotebookOutputType.quiz) ...[
                const SizedBox(height: 20),
                Text(
                  'Select Quiz Format',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isAssessment = false),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: !_isAssessment
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: !_isAssessment ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey.shade200),
                              width: !_isAssessment ? 1.8 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.quiz_rounded,
                                    size: 18,
                                    color: !_isAssessment ? AppColors.primary : (isDark ? Colors.white60 : Colors.grey),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Practice Quiz',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: !_isAssessment ? AppColors.primary : (isDark ? Colors.white : AppColors.textPrimary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Interactive multi-choice & short answer practice.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isAssessment = true),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isAssessment
                                ? Colors.deepPurple.withValues(alpha: 0.12)
                                : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isAssessment ? Colors.deepPurple : (isDark ? Colors.white10 : Colors.grey.shade200),
                              width: _isAssessment ? 1.8 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: _isAssessment ? Colors.deepPurple : (isDark ? Colors.white60 : Colors.grey),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Assessment',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _isAssessment ? Colors.deepPurple : (isDark ? Colors.white : AppColors.textPrimary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Passage-based reading exam with timed evaluation.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Ready Sources Summary
              Text(
                'Sources to Synthesize (${readySources.length})',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (readySources.isEmpty)
                Text(
                  'No ready sources found. Add a document, note, or web link on the left panel first.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.orange),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: readySources.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              // Existing Draft Notice
              if (widget.hasExistingOutput) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A ${widget.type.displayName} draft already exists. Confirming will regenerate and replace it.',
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: readySources.isEmpty
                        ? null
                        : () => Navigator.pop(context, {
                              'confirmed': true,
                              'isAssessment': _isAssessment,
                            }),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      'Confirm & Generate',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
