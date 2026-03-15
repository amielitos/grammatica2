import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/notification_widgets.dart';
import '../main.dart';
import 'quiz_detail_page.dart';

class LessonPage extends StatefulWidget {
  final User user;
  final Lesson lesson;
  final bool previewMode;

  const LessonPage({
    super.key,
    required this.user,
    required this.lesson,
    this.previewMode = false,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da $hh:$mm';
  }

  Widget _authorName({
    required String? uid,
    required String? fallbackEmail,
    TextStyle? style,
  }) {
    if (uid == null || uid.isEmpty) {
      return Text('By: ${fallbackEmail ?? 'Unknown'}', style: style);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final username = (data?['username'] as String?)?.trim();
        final display = (username != null && username.isNotEmpty)
            ? username
            : (fallbackEmail ?? 'Unknown');
        return Text('By: $display', style: style);
      },
    );
  }

  late Lesson _lesson;
  bool get _previewMode => widget.previewMode;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;

    // Trigger Achievement Notification for first lesson
    if (!widget.previewMode) {
      DatabaseService.instance
          .checkAndAwardAchievement(widget.user.uid, 'first_lesson')
          .then((awarded) {
            if (awarded) {
              // Note: Achievement notification logic can be kept as functionality
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson'),
        actions: [
          NotificationIconButton(
            userId: widget.user.uid,
            onTap: () {
              notificationVisibleNotifier.value =
                  !notificationVisibleNotifier.value;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_previewMode)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Preview Mode',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Viewing as Admin',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                _authorName(
                  uid: _lesson.createdByUid,
                  fallbackEmail: _lesson.createdByEmail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Text(
                  '• Created: ${_lesson.createdAt != null ? _fmt(_lesson.createdAt!) : 'N/A'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...[_lesson.prompt].map((part) {
              final trimmed = part.trim();
              if (trimmed.isEmpty) return const SizedBox.shrink();
              return InteractiveMarkdown(data: trimmed);
            }),
            if (!_previewMode && _lesson.quizId != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              StreamBuilder<Map<String, Map<String, dynamic>>>(
                stream: DatabaseService.instance.quizProgressStream(
                  widget.user,
                ),
                builder: (context, snapshot) {
                  final progressMap = snapshot.data ?? {};
                  final myProgress = progressMap[_lesson.quizId];
                  final attempts =
                      (myProgress?['attemptsUsed'] as num?)?.toInt() ?? 0;

                  if (attempts > 0) {
                    return _buildQuizResults(myProgress!);
                  }

                  return Center(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () async {
                        try {
                          // Mark lesson completed
                          await DatabaseService.instance.markLessonCompleted(
                            user: widget.user,
                            lessonId: _lesson.id,
                          );

                          // Fetch quiz and navigate
                          final doc = await FirebaseFirestore.instance
                              .collection('quizzes')
                              .doc(_lesson.quizId)
                              .get();

                          if (doc.exists && context.mounted) {
                            final quiz = Quiz.fromDoc(doc);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizDetailPage(
                                  user: widget.user,
                                  quiz: quiz,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error loading quiz: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.quiz),
                      label: const Text(
                        'Take Required Quiz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuizResults(Map<String, dynamic> progress) {
    final score = progress['score'] ?? 0;
    final total = progress['totalQuestions'] ?? 0;
    final passed = progress['passed'] == true;
    final lastAttemptAt = progress['lastAttemptAt'] as Timestamp?;
    final timeTaken = progress['timeTaken'] as int? ?? 0;

    final minutes = timeTaken ~/ 60;
    final seconds = timeTaken % 60;
    final timeStr = minutes > 0 ? '$minutes m $seconds s' : '$seconds seconds';

    return Center(
      child: Column(
        children: [
          Text(
            'Quiz Results',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: passed
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  size: 48,
                  color: passed
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  passed ? 'PASSED' : 'FAILED',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: passed
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn('Score', '$score / $total'),
                    _statColumn('Time', timeStr),
                  ],
                ),
                if (lastAttemptAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Taken on: ${_fmt(lastAttemptAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: passed
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
