import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

class LessonPage extends StatefulWidget {
  final User user;
  final Lesson lesson;
  const LessonPage({super.key, required this.user, required this.lesson});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final _answerCtrl = TextEditingController();
  String? _feedback;
  late Lesson _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
  }

  Future<void> _refresh() async {
    final latest = await DatabaseService.instance.getLessonById(_lesson.id);
    if (latest != null && mounted) {
      setState(() {
        _lesson = latest;
        _feedback = null;
        _answerCtrl.clear();
      });
    }
  }

  void _check() async {
    final input = _answerCtrl.text.trim();
    final correct = input.toLowerCase() == _lesson.answer.trim().toLowerCase();
    setState(() {
      _feedback = correct ? 'Correct!' : 'Try again';
    });
    if (correct) {
      await DatabaseService.instance.markLessonCompleted(user: widget.user, lessonId: _lesson.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lesson.title),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_lesson.prompt, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _answerCtrl,
              decoration: const InputDecoration(labelText: 'Your Answer'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _check, child: const Text('Check')),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text(_feedback!, style: TextStyle(color: _feedback == 'Correct!' ? Colors.green : Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
