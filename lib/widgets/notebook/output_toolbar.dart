import 'package:flutter/material.dart';
import '../../models/notebook_models.dart';
import '../../theme/app_colors.dart';

/// Bottom generation toolbar enabling educators to generate diverse AI outputs
/// (Flashcards, Quiz, Study Guide, Timeline, Briefing, FAQ, Mind Map) from ingested sources.
class OutputToolbar extends StatelessWidget {
  final bool hasSources;
  final bool isGenerating;
  final NotebookOutputType? selectedType;
  final Map<NotebookOutputType, int> outputCounts;
  final Function(NotebookOutputType) onSelectOutput;
  final Function(NotebookOutputType) onGenerateRequested;

  const OutputToolbar({
    super.key,
    required this.hasSources,
    required this.isGenerating,
    this.selectedType,
    this.outputCounts = const {},
    required this.onSelectOutput,
    required this.onGenerateRequested,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B231A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.lesson,
                icon: Icons.school_rounded,
                label: 'Lesson',
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.flashcards,
                icon: Icons.style_rounded,
                label: 'Flashcards',
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.quiz,
                icon: Icons.quiz_rounded,
                label: 'Quiz',
                color: const Color(0xFFEF4444),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.studyGuide,
                icon: Icons.menu_book_rounded,
                label: 'Study Guide',
                color: AppColors.primary,
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.timeline,
                icon: Icons.timeline_rounded,
                label: 'Timeline',
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.briefing,
                icon: Icons.assignment_rounded,
                label: 'Briefing Doc',
                color: const Color(0xFF14B8A6),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.faq,
                icon: Icons.help_outline_rounded,
                label: 'FAQ',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              _buildTypeButton(
                context: context,
                type: NotebookOutputType.mindMap,
                icon: Icons.hub_rounded,
                label: 'Mind Map',
                color: const Color(0xFFEC4899),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required BuildContext context,
    required NotebookOutputType type,
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = selectedType == type;
    final count = outputCounts[type] ?? 0;
    final enabled = hasSources && !isGenerating;

    return Tooltip(
      message: !hasSources
          ? 'Add at least one source to generate $label'
          : (count > 0 ? '$count generated' : 'Generate $label'),
      child: InkWell(
        onTap: enabled
            ? () {
                onSelectOutput(type);
                if (count == 0) {
                  onGenerateRequested(type);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? const Color(0xFF232C22) : const Color(0xFFF1F5F0)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? (isSelected ? color : color.withValues(alpha: 0.8)) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: enabled
                      ? (isDark ? Colors.white : AppColors.textPrimary)
                      : Colors.grey,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
