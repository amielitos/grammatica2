import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/notification_widgets.dart';
import '../pages/quiz_detail_page.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
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
  bool _isLoadingQuiz = false;

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
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final data = await DatabaseService.instance.getUserData(widget.user.uid);
    if (mounted) {
      setState(() {
        _userData = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCEDA72), // Lime green background from image
      appBar: CustomAppBar(
        user: widget.user,
        userData: _userData,
        showBackButton: widget.previewMode,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
      ),
      drawer: UniversalDrawer(
        user: widget.user,
        userData: _userData ?? {},
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildMainCard()),
                      const SizedBox(width: 24),
                      SizedBox(width: 320, child: _buildQuizSidebar()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMainCard(),
                      const SizedBox(height: 24),
                      _buildQuizSidebar(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      constraints: const BoxConstraints(minHeight: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _lesson.title,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _authorName(
                    uid: _lesson.createdByUid,
                    fallbackEmail: _lesson.createdByEmail,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lesson.createdAt != null
                        ? _fmt(_lesson.createdAt!)
                        : 'N/A',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          InteractiveMarkdown(data: _lesson.prompt.trim()),
        ],
      ),
    );
  }

  Widget _buildQuizSidebar() {
    final isValidator = _userData?['role'] == 'VALIDATOR';
    if (_previewMode || _lesson.quizId == null || isValidator) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: DatabaseService.instance.quizProgressStream(widget.user),
      builder: (context, snapshot) {
        final progressMap = snapshot.data ?? {};
        final myProgress = progressMap[_lesson.quizId];
        final attempts = (myProgress?['attemptsUsed'] as num?)?.toInt() ?? 0;

        if (attempts > 0) {
          return _buildQuizResultsCard(myProgress!);
        }

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCEDA72), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 48,
                  color: Color(0xFF88B342),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Knowledge Check',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete the quiz and finalize this lesson.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF88B342),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoadingQuiz ? null : _takeQuizAction,
                  child: _isLoadingQuiz
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Take Quiz',
                          style: TextStyle(fontWeight: FontWeight.normal),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takeQuizAction() async {
    setState(() => _isLoadingQuiz = true);
    try {
      await DatabaseService.instance.markLessonCompleted(
        user: widget.user,
        lessonId: _lesson.id,
      );

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
      if (mounted) {
        setState(() => _isLoadingQuiz = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz: $e')),
        );
      }
    }
  }

  Widget _buildQuizResultsCard(Map<String, dynamic> progress) {
    final score = progress['score'] ?? 0;
    final total = progress['totalQuestions'] ?? 0;
    final passed = progress['passed'] == true;
    final timeTaken = progress['timeTaken'] as int? ?? 0;

    final minutes = timeTaken ~/ 60;
    final seconds = timeTaken % 60;
    final timeStr = minutes > 0 ? '$minutes m $seconds s' : '$seconds s';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (passed ? const Color(0xFF88B342) : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              passed ? Icons.verified_rounded : Icons.cancel_rounded,
              size: 48,
              color: passed ? const Color(0xFF88B342) : Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            passed ? 'Knowledge Check Passed' : 'Knowledge Check Failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: passed ? const Color(0xFF88B342) : Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('Score', '$score/$total'),
              _statItem('Time', timeStr),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: passed ? const Color(0xFF88B342) : Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isLoadingQuiz ? null : _takeQuizAction,
              child: _isLoadingQuiz
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: passed ? const Color(0xFF88B342) : Colors.red,
                      ),
                    )
                  : Text(
                      passed ? 'Retake Quiz' : 'Try Again',
                      style: TextStyle(color: passed ? const Color(0xFF88B342) : Colors.red),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }
}
