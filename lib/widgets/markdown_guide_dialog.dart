import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownGuideDialog extends StatelessWidget {
  const MarkdownGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF81B655);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Markdown Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, primaryColor),
                const SizedBox(height: 40),
                _buildSectionTitle(context, 'Basic Formatting'),
                _buildGuideCard(
                  context,
                  title: 'Headers',
                  syntax: '# Heading 1\n## Heading 2\n### Heading 3',
                  result: '# Heading 1\n## Heading 2\n### Heading 3',
                ),
                _buildGuideCard(
                  context,
                  title: 'Emphasis',
                  syntax: '**Bold text**\n*Italic text*\n~~Strikethrough~~',
                  result: '**Bold text**\n*Italic text*\n~~Strikethrough~~',
                ),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Structure'),
                _buildGuideCard(
                  context,
                  title: 'Lists',
                  syntax: '- Unordered item 1\n- Unordered item 2\n\n1. Ordered item 1\n2. Ordered item 2',
                  result: '- Unordered item 1\n- Unordered item 2\n\n1. Ordered item 1\n2. Ordered item 2',
                ),
                _buildGuideCard(
                  context,
                  title: 'Blockquotes',
                  syntax: '> This is a blockquote\n> spanning multiple lines.',
                  result: '> This is a blockquote\n> spanning multiple lines.',
                ),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Code & Media'),
                _buildGuideCard(
                  context,
                  title: 'Code',
                  syntax: 'Inline `code`.\n\n```dart\n// Code block\nvoid main() {\n  print("Hello");\n}\n```',
                  result: 'Inline `code`.\n\n```dart\n// Code block\nvoid main() {\n  print("Hello");\n}\n```',
                ),
                _buildGuideCard(
                  context,
                  title: 'Links & Images',
                  syntax: '[Grammatica Website](https://grammatica.app)\n\n![Alt Text](url_to_image)',
                  result: '[Grammatica Website](https://grammatica.app)\n\n*(Images will display if URL is valid)*',
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.doc_text_fill, color: primaryColor, size: 32),
              const SizedBox(width: 16),
              const Text(
                'Markdown Syntax',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Enhance your lessons and quizzes with rich text formatting. Use the guide below to learn the essentials.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF81B655),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context, {
    required String title,
    required String syntax,
    required String result,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    color: isDark ? Colors.black.withOpacity(0.15) : Colors.grey[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('SYNTAX', isDark),
                        const SizedBox(height: 16),
                        SelectableText(
                          syntax,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.6,
                            color: isDark ? Colors.green[300] : const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08)),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('RESULT', isDark),
                        const SizedBox(height: 16),
                        MarkdownBody(
                          data: result,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                            h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            listBullet: TextStyle(color: const Color(0xFF81B655)),
                            code: TextStyle(
                              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                            ),
                            blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            blockquoteDecoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(left: BorderSide(color: Color(0xFF81B655), width: 4)),
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
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
    );
  }
}

