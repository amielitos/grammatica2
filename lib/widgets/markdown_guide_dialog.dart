import 'package:flutter/material.dart';

class MarkdownGuideDialog extends StatelessWidget {
  const MarkdownGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Markdown Guide'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use Markdown to format your text:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildGuideItem(
              title: 'Headers',
              syntax: '# Header 1\n## Header 2',
              description: 'Use # for headers.',
            ),
            _buildGuideItem(
              title: 'Bold',
              syntax: '**bold text**',
              description: 'Wrap text in double asterisks.',
            ),
            _buildGuideItem(
              title: 'Italic',
              syntax: '*italic text*',
              description: 'Wrap text in single asterisks.',
            ),
            _buildGuideItem(
              title: 'Lists',
              syntax: '- Item 1\n- Item 2',
              description: 'Use hyphens for bullet points.',
            ),
            _buildGuideItem(
              title: 'Numbered Lists',
              syntax: '1. Item 1\n2. Item 2',
              description: 'Use numbers followed by a period.',
            ),
            _buildGuideItem(
              title: 'Links',
              syntax: '[Link Text](url)',
              description: 'Square brackets for text, parentheses for URL.',
            ),
            _buildGuideItem(
              title: 'Code Block',
              syntax: '```\ncode here\n```',
              description: 'Use triple backticks for code blocks.',
            ),
            _buildGuideItem(
              title: 'Inline Code',
              syntax: '`code`',
              description: 'Use single backtick for inline code.',
            ),
            _buildGuideItem(
              title: 'Blockquote',
              syntax: '> Quote',
              description: 'Use > for blockquotes.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildGuideItem({
    required String title,
    required String syntax,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              syntax,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
