import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class LessonPage extends StatefulWidget {
  final User user;
  final Lesson lesson;
  const LessonPage({super.key, required this.user, required this.lesson});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
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
      });
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
            MarkdownBody(
              data: _lesson.prompt.isEmpty ? '_No content_' : _lesson.prompt,
            ),
          ],
        ),
      ),
    );
  }
}
