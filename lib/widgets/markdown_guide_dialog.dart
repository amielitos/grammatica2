import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class MarkdownGuideDialog extends StatelessWidget {
  const MarkdownGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Markdown Guide'),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use Markdown to format your text:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildGuideItem(
              context,
              title: 'Headers',
              syntax: '# Header 1\n## Header 2',
              description: 'Use # for headers.',
            ),
            _buildGuideItem(
              context,
              title: 'Bold',
              syntax: '**bold text**',
              description: 'Wrap text in double asterisks.',
            ),
            _buildGuideItem(
              context,
              title: 'Italic',
              syntax: '*italic text*',
              description: 'Wrap text in single asterisks.',
            ),
            _buildGuideItem(
              context,
              title: 'Lists',
              syntax: '- Item 1\n- Item 2',
              description: 'Use hyphens for bullet points.',
            ),
            _buildGuideItem(
              context,
              title: 'Numbered Lists',
              syntax: '1. Item 1\n2. Item 2',
              description: 'Use numbers followed by a period.',
            ),
            _buildGuideItem(
              context,
              title: 'Links',
              syntax: '[Link Text](url)',
              description: 'Square brackets for text, parentheses for URL.',
            ),
            _buildGuideItem(
              context,
              title: 'Code Block',
              syntax: '```\ncode here\n```',
              description: 'Use triple backticks for code blocks.',
            ),
            _buildGuideItem(
              context,
              title: 'Inline Code',
              syntax: '`code`',
              description: 'Use single backtick for inline code.',
            ),
            _buildGuideItem(
              context,
              title: 'Blockquote',
              syntax: '> Quote',
              description: 'Use > for blockquotes.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(
    BuildContext context, {
    required String title,
    required String syntax,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(syntax, style: const TextStyle(fontFamily: 'monospace')),
          Text(description),
        ],
      ),
    );
  }
}
