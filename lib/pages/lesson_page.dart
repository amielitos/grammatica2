import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/notification_widgets.dart';
import '../pages/quiz_detail_page.dart';
import '../main.dart';
import '../services/database_service.dart';

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
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final username = (data?['username'] as String?)?.trim();
        final display = (username != null && username.isNotEmpty) ? username : (fallbackEmail ?? 'Unknown');
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

    if (!widget.previewMode) {
      DatabaseService.instance.checkAndAwardAchievement(widget.user.uid, 'first_lesson').then((awarded) {
        if (awarded) {
          // Achievement awarded
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lesson Material', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          NotificationIconButton(
            userId: widget.user.uid,
            onTap: () {
              notificationVisibleNotifier.value = !notificationVisibleNotifier.value;
            },
          ),
        ],
      ),
      body: BackgroundWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_previewMode)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'PREVIEW MODE',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      Text(
                        'Admin View',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              // Metadata
              Row(
                children: [
                  _authorName(
                    uid: _lesson.createdByUid,
                    fallbackEmail: _lesson.createdByEmail,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  const Text('•', style: TextStyle(color: AppColors.divider)),
                  const SizedBox(width: 12),
                  Text(
                    _lesson.createdAt != null ? _fmt(_lesson.createdAt!) : 'N/A',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Content
              ...[_lesson.prompt].map((part) {
                final trimmed = part.trim();
                if (trimmed.isEmpty) return const SizedBox.shrink();
                return InteractiveMarkdown(data: trimmed);
              }),

              if (!_previewMode && _lesson.quizId != null) ...[
                const SizedBox(height: 48),
                const Divider(color: AppColors.divider),
                const SizedBox(height: 32),
                StreamBuilder<Map<String, Map<String, dynamic>>>(
                  stream: DatabaseService.instance.quizProgressStream(widget.user),
                  builder: (context, snapshot) {
                    final progressMap = snapshot.data ?? {};
                    final myProgress = progressMap[_lesson.quizId];
                    final attempts = (myProgress?['attemptsUsed'] as num?)?.toInt() ?? 0;

                    if (attempts > 0) {
                      return _buildQuizResults(myProgress!);
                    }

                    return Center(
                      child: Column(
                        children: [
                          const Icon(Icons.assignment_turned_in_rounded, size: 64, color: AppColors.primary),
                          const SizedBox(height: 24),
                          const Text(
                            'Knowledge Check',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Complete the quiz to finalize this lesson.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 64),
                            ),
                            onPressed: () async {
                              try {
                                await DatabaseService.instance.markLessonCompleted(
                                  user: widget.user,
                                  lessonId: _lesson.id,
                                );

                                final doc = await FirebaseFirestore.instance.collection('quizzes').doc(_lesson.quizId).get();

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
                            icon: const Icon(Icons.play_lesson_rounded),
                            label: const Text('TAKE LESSON QUIZ', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text(
              'Lesson Quiz Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (passed ? AppColors.primary : AppColors.error).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                passed ? Icons.verified_rounded : Icons.cancel_rounded,
                size: 64,
                color: passed ? AppColors.primary : AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              passed ? 'LESSON COMPLETED' : 'QUIZ FAILED',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: passed ? AppColors.primary : AppColors.error,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statColumn('Score', '$score / $total'),
                _statColumn('Time Taken', timeStr),
              ],
            ),
            if (lastAttemptAt != null) ...[
              const SizedBox(height: 24),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),
              Text(
                'Completed on: ${_fmt(lastAttemptAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
