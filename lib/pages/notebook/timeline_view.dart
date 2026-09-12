import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/study_guide_models.dart';
import '../../theme/app_colors.dart';
import 'publish_content_dialogs.dart';

/// Renders chronological timelines generated from notebook sources.
class TimelineView extends StatelessWidget {
  final Timeline timeline;
  final String notebookId;
  final String outputId;
  final bool isLearnerView;
  final bool isShared;

  const TimelineView({
    super.key,
    required this.timeline,
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
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  timeline.title,
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
                tooltip: 'Copy timeline',
                onPressed: () => _copyTimeline(context),
              ),
              if (!isLearnerView)
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  tooltip: 'Publish to Curriculum',
                  onPressed: () => _publishTimeline(context),
                ),
            ],
          ),
          if (timeline.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              timeline.description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Vertical Timeline Spine
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: timeline.events.length,
            itemBuilder: (context, index) {
              final event = timeline.events[index];
              final isLast = index == timeline.events.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date & spine
                    SizedBox(
                      width: 40,
                      child: Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF8B5CF6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF131812) : AppColors.backgroundBase,
                                width: 3,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Event Card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E261D) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      event.dateOrPeriod,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                                  if (event.category != null && event.category!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        event.category!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                event.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _copyTimeline(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('# ${timeline.title}\n');
    for (final e in timeline.events) {
      buffer.writeln('### ${e.dateOrPeriod}: ${e.title}');
      buffer.writeln('${e.description}\n');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timeline copied to clipboard')),
    );
  }

  void _publishTimeline(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PublishContentDialog(
        notebookId: notebookId,
        output: timeline.toNotebookOutput(
          id: outputId,
          notebookId: notebookId,
        ),
      ),
    );
  }
}
