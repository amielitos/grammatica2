import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'markdown_guide_dialog.dart';

class MarkdownGuideButton extends StatelessWidget {
  const MarkdownGuideButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const MarkdownGuideDialog(),
          ),
        );
      },
      icon: const Icon(CupertinoIcons.question_circle, size: 18),
      label: const Text('Markdown Guide'),
    );
  }
}
