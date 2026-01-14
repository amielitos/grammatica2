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
  bool _isCorrect = false;
  int _attemptsUsed = 0;
  bool _completed = false;

  String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");

  Future<void> _submit(int maxAttempts) async {
    if (_attemptsUsed >= maxAttempts && !_completed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No attempts remaining.')));
      return;
    }

    final input = _normalize(_answerCtrl.text);
    final expected = _normalize(widget.quiz.answer);
    final correct = input == expected;

    setState(() => _submitting = true);

    try {
      await DatabaseService.instance.markQuizCompleted(
        user: widget.user,
        quizId: widget.quiz.id,
        answer: _answerCtrl.text.trim(),
        isCorrect: correct,
      );

      if (mounted) {
        setState(() {
          _submitting = false;
          // Optimistic update (stream will confirm)
          if (correct) {
            _isCorrect = true;
            _completed = true;
          }
          _attemptsUsed++; // Increment local count for immediate feedback
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              correct
                  ? 'Correct!'
                  : 'Incorrect. ${maxAttempts - _attemptsUsed} attempts remaining.',
            ),
            backgroundColor: correct ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz.title)),
      body: StreamBuilder<Map<String, Map<String, dynamic>>>(
        stream: DatabaseService.instance.quizProgressStream(widget.user),
        builder: (context, snapshot) {
          final progressMap = snapshot.data ?? {};
          final myProgress = progressMap[widget.quiz.id];

          // Update state from stream
          if (myProgress != null) {
            _completed = myProgress['completed'] == true;
            final streamAttempts =
                (myProgress['attemptsUsed'] as num?)?.toInt() ?? 0;
            // Prevent stale stream data from overwriting local increment
            if (streamAttempts > _attemptsUsed) {
              _attemptsUsed = streamAttempts;
            }
            // Ensure we don't 'uncomplete' if locally valid (though unlikely)
            // But actually, for attempts, max is safe.
            _isCorrect = myProgress['isCorrect'] == true;
          } else {
            // If no progress doc, streamAttempts is 0.
            // If we have local attempts, keep them?
            // Usually implies fresh start.
            // But if we just submitted attempt 1, and stream says null (latency), we want to keep 1.
          }

          final maxAttempts = widget.quiz.maxAttempts;
          final attemptsLeft = maxAttempts - _attemptsUsed;
          final canSubmit = !_completed && attemptsLeft > 0;
          final showTryAgain =
              !_completed && _attemptsUsed > 0 && attemptsLeft > 0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_completed && _isCorrect)
                        const Chip(
                          label: Text(
                            'Completed',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        )
                      else if (_attemptsUsed >= maxAttempts && !_isCorrect)
                        const Chip(
                          label: Text(
                            'Failed',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                        )
                      else
                        Chip(
                          label: Text(
                            'Attempts used: $_attemptsUsed / $maxAttempts',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MarkdownBody(data: widget.quiz.question),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _answerCtrl,
                    enabled:
                        canSubmit ||
                        showTryAgain, // Allow editing if trying again
                    decoration: InputDecoration(
                      labelText: 'Your Answer',
                      border: const OutlineInputBorder(),
                      errorText:
                          (_attemptsUsed > 0 &&
                              !_isCorrect &&
                              !_submitting &&
                              attemptsLeft > 0)
                          ? 'Incorrect, try again.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (canSubmit || showTryAgain)
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : () => _submit(maxAttempts),
                      child: _submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(showTryAgain ? 'Try Again' : 'Submit'),
                    )
                  else if (_isCorrect)
                    Text(
                      'Great job! The answer was: ${widget.quiz.answer}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      'Out of attempts. The correct answer was: ${widget.quiz.answer}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
