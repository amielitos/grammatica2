import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/database_service.dart';
import '../widgets/glass_card.dart';

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
      appBar: AppBar(
        title: const Text('Grammatica'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StreamBuilder<Map<String, Map<String, dynamic>>>(
                stream: DatabaseService.instance.quizProgressStream(
                  widget.user,
                ),
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
                    _isCorrect = myProgress['isCorrect'] == true;
                  }

                  final maxAttempts = widget.quiz.maxAttempts;
                  final attemptsLeft = maxAttempts - _attemptsUsed;
                  final canSubmit = !_completed && attemptsLeft > 0;
                  final showTryAgain =
                      !_completed && _attemptsUsed > 0 && attemptsLeft > 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_completed && _isCorrect)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (_attemptsUsed >= maxAttempts && !_isCorrect)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red),
                              ),
                              child: const Text(
                                'Failed',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: Text(
                                'Attempts used: $_attemptsUsed / $maxAttempts',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      MarkdownBody(
                        data: widget.quiz.question,
                        selectable: true,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _answerCtrl,
                        enabled: canSubmit || showTryAgain,
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
                      const SizedBox(height: 16),
                      if (canSubmit || showTryAgain)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : () => _submit(maxAttempts),
                            child: _submitting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(showTryAgain ? 'Try Again' : 'Submit'),
                          ),
                        )
                      else if (_isCorrect)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: Colors.green,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Great job! The answer was: ${widget.quiz.answer}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Out of attempts. The correct answer was: ${widget.quiz.answer}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
