import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/study_guide_models.dart';
import '../../theme/app_colors.dart';
import 'publish_content_dialogs.dart';

/// Renders an executive briefing document with summaries, key points, and action items.
class BriefingView extends StatefulWidget {
  final Briefing briefing;
  final String notebookId;
  final String outputId;
  final bool isLearnerView;
  final bool isShared;

  const BriefingView({
    super.key,
    required this.briefing,
    required this.notebookId,
    required this.outputId,
    bool? isLearnerView,
    this.isShared = false,
  }) : isLearnerView = isLearnerView ?? isShared;

  @override
  State<BriefingView> createState() => _BriefingViewState();
}

class _BriefingViewState extends State<BriefingView> {
  late List<BriefingActionItem> _actionItems;

  @override
  void initState() {
    super.initState();
    _actionItems = List.from(widget.briefing.actionItems);
  }

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
                  widget.briefing.title,
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
                tooltip: 'Copy briefing',
                onPressed: () => _copyBriefing(context),
              ),
              if (!widget.isLearnerView)
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  tooltip: 'Publish to Curriculum',
                  onPressed: () => _publishBriefing(context),
                ),
            ],
          ),

          // Executive Summary Card
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_rounded, color: Color(0xFF14B8A6), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'EXECUTIVE SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.briefing.executiveSummary,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Key Points
          const SizedBox(height: 28),
          Text(
            'Strategic Points',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...widget.briefing.keyPoints.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E261D) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF14B8A6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark ? Colors.white70 : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          // Action Items
          if (_actionItems.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Action Checklist',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E261D) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: _actionItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;

                  Color priorityColor;
                  switch (item.priority.toLowerCase()) {
                    case 'high':
                      priorityColor = Colors.red;
                      break;
                    case 'medium':
                      priorityColor = Colors.orange;
                      break;
                    default:
                      priorityColor = Colors.blue;
                  }

                  return CheckboxListTile(
                    value: item.isDone,
                    onChanged: (val) {
                      setState(() {
                        _actionItems[idx] = item.copyWith(isDone: val ?? false);
                      });
                    },
                    activeColor: const Color(0xFF14B8A6),
                    title: Text(
                      item.text,
                      style: TextStyle(
                        fontSize: 14,
                        decoration: item.isDone ? TextDecoration.lineThrough : null,
                        color: item.isDone
                            ? (isDark ? Colors.white38 : Colors.black38)
                            : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Conclusion
          if (widget.briefing.conclusion != null &&
              widget.briefing.conclusion!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Looking Ahead',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.briefing.conclusion!,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _copyBriefing(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('# ${widget.briefing.title}\n');
    buffer.writeln('## Executive Summary\n${widget.briefing.executiveSummary}\n');
    buffer.writeln('## Strategic Points');
    for (final p in widget.briefing.keyPoints) {
      buffer.writeln('- $p');
    }
    buffer.writeln('\n## Action Items');
    for (final a in _actionItems) {
      buffer.writeln('- [${a.isDone ? 'x' : ' '}] ${a.text} (${a.priority})');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Briefing copied to clipboard')),
    );
  }

  void _publishBriefing(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PublishContentDialog(
        notebookId: widget.notebookId,
        output: widget.briefing.toNotebookOutput(
          id: widget.outputId,
          notebookId: widget.notebookId,
        ),
      ),
    );
  }
}
