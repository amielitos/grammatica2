import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/study_guide_models.dart';
import '../../theme/app_colors.dart';
import 'publish_content_dialogs.dart';

/// Renders a structured Study Guide generated from notebook sources.
class StudyGuideView extends StatelessWidget {
  final StudyGuide guide;
  final String notebookId;
  final String outputId;
  final bool isLearnerView;
  final bool isShared;

  const StudyGuideView({
    super.key,
    required this.guide,
    required this.notebookId,
    required this.outputId,
    bool? isLearnerView,
    this.isShared = false,
  }) : isLearnerView = isLearnerView ?? isShared;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Bar & Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  guide.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy text',
                onPressed: () => _copyToClipboard(context),
              ),
              if (!isLearnerView)
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  tooltip: 'Publish to Curriculum',
                  onPressed: () => _publishGuide(context),
                ),
            ],
          ),

          // Executive Summary Callout Box
          if (guide.summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EXECUTIVE OVERVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          guide.summary,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Sections
          const SizedBox(height: 28),
          ...guide.sections.map((section) => _buildSection(section, isDark)),

          // Key Terms Grid
          if (guide.keyTerms.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Key Terminology',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: guide.keyTerms.map((term) => _buildTermCard(term, isDark)).toList(),
            ),
          ],

          // Key Takeaways Box
          if (guide.keyTakeaways.isNotEmpty) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: Color(0xFFF5A623), size: 22),
                      SizedBox(width: 10),
                      Text(
                        'CORE TAKEAWAYS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: Color(0xFFF5A623),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...guide.keyTakeaways.map(
                    (takeaway) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF5A623))),
                          Expanded(
                            child: Text(
                              takeaway,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(StudyGuideSection section, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D261C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            section.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          if (section.bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...section.bulletPoints.map(
              (bp) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✓ ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        bp,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white70 : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTermCard(KeyTerm term, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232D21) : const Color(0xFFF1F5F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            term.term,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            term.definition,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('# ${guide.title}\n');
    buffer.writeln('${guide.summary}\n');
    for (final s in guide.sections) {
      buffer.writeln('## ${s.heading}');
      buffer.writeln('${s.content}\n');
      for (final bp in s.bulletPoints) {
        buffer.writeln('- $bp');
      }
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Study guide copied to clipboard')),
    );
  }

  void _publishGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PublishContentDialog(
        notebookId: notebookId,
        output: guide.toNotebookOutput(
          id: outputId,
          notebookId: notebookId,
        ),
      ),
    );
  }
}
