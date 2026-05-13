import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class InteractiveMarkdown extends StatelessWidget {
  final String data;

  const InteractiveMarkdown({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final trimmedData = data.trim();
    if (trimmedData.isEmpty) return const SizedBox.shrink();

    final RegExp headingRegExp = RegExp(r'^>\s+(.+)$', multiLine: true);
    final Iterable<RegExpMatch> matches = headingRegExp.allMatches(trimmedData);

    if (matches.isEmpty) {
      // No blockquotes, just normal markdown
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: MarkdownBody(
          data: trimmedData,
          selectable: true,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          styleSheet: MarkdownStyleSheet(
            p: Theme.of(context).textTheme.bodyLarge,
            tableBody: Theme.of(context).textTheme.bodyMedium,
            tableHead: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            tableBorder: TableBorder.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
            tableColumnWidth: const FlexColumnWidth(),
            tableCellsPadding: const EdgeInsets.all(8.0),
          ),
        ),
      );
    }

    final List<Widget> children = [];
    int lastEnd = 0;

    // Regex to find boundaries where a flashcard should stop:
    // 1. Another blockquote `^> ` (handled by matches)
    // 2. A heading `^# `
    // 3. A horizontal rule `^---` or `^***`
    final RegExp stopBoundaryRegExp = RegExp(
      r'^(?:#|---|[*]{3})',
      multiLine: true,
    );

    for (final match in matches) {
      // If there's content BEFORE the first blockquote, render it as normal markdown
      if (match.start > lastEnd) {
        final preContent = trimmedData.substring(lastEnd, match.start).trim();
        if (preContent.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: MarkdownBody(
                data: preContent,
                selectable: true,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyLarge,
                  tableBody: Theme.of(context).textTheme.bodyMedium,
                  tableHead: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  tableBorder: TableBorder.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                  tableColumnWidth: const FlexColumnWidth(),
                  tableCellsPadding: const EdgeInsets.all(8.0),
                ),
              ),
            ),
          );
        }
      }

      // Find where this flashcard's content ends (at the next blockquote, OR a heading, OR horizontal rule)
      final nextMatch = matches.firstWhere(
        (m) => m.start > match.end,
        orElse: () => match, // fallback if no more blockquotes
      );

      // Search for a stop boundary between this match and the next one (or end of string)
      final searchArea = trimmedData.substring(
        match.end,
        nextMatch == match ? trimmedData.length : nextMatch.start,
      );

      final stopMatch = stopBoundaryRegExp.firstMatch(searchArea);

      final int contentEnd = stopMatch != null
          ? match.end + stopMatch.start
          : (nextMatch == match ? trimmedData.length : nextMatch.start);

      final heading = match.group(1) ?? 'Flashcard';
      final content = trimmedData.substring(match.end, contentEnd).trim();

      children.add(FlashcardWidget(heading: heading, content: content));

      lastEnd = contentEnd;
    }

    // Add any remaining trailing content after the last flashcard finishes
    if (lastEnd < trimmedData.length) {
      final postContent = trimmedData.substring(lastEnd).trim();
      if (postContent.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: MarkdownBody(
              data: postContent,
              selectable: true,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyLarge,
                tableBody: Theme.of(context).textTheme.bodyMedium,
                tableHead: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                tableBorder: TableBorder.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                tableColumnWidth: const FlexColumnWidth(),
                tableCellsPadding: const EdgeInsets.all(8.0),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class FlashcardWidget extends StatefulWidget {
  final String heading;
  final String content;

  const FlashcardWidget({
    super.key,
    required this.heading,
    required this.content,
  });

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.quiz_outlined,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.heading,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: widget.content,
                  selectable: true,
                  extensionSet: md.ExtensionSet.gitHubFlavored,
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    tableBody: Theme.of(context).textTheme.bodyMedium,
                    tableHead: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    tableBorder: TableBorder.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                    tableColumnWidth: const FlexColumnWidth(),
                    tableCellsPadding: const EdgeInsets.all(8.0),
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
