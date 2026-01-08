import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/database_service.dart';

class QuizDetailPage extends StatefulWidget {
  final User user;
  final Quiz quiz;
  const QuizDetailPage({super.key, required this.user, required this.quiz});

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  final _answerCtrl = TextEditingController();
  bool _submitting = false;

  String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");

  Future<void> _submit() async {
    final input = _normalize(_answerCtrl.text);
    final expected = _normalize(widget.quiz.answer);
    final correct = input == expected;
    setState(() => _submitting = true);
    await DatabaseService.instance.markQuizCompleted(
      user: widget.user,
      quizId: widget.quiz.id,
      answer: _answerCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            correct
                ? 'Correct!'
                : 'Incorrect. The correct answer is: ${widget.quiz.answer}',
          ),
          backgroundColor: correct ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(data: widget.quiz.question),
            const SizedBox(height: 16),
            TextField(
              controller: _answerCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Answer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
