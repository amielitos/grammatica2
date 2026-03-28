import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/design_ornaments.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class QuizDetailPage extends StatefulWidget {
  final User user;
  final Quiz quiz;
  final bool previewMode;

  const QuizDetailPage({
    super.key,
    required this.user,
    required this.quiz,
    this.previewMode = false,
  });

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  int _currentQuestionIndex = 0;
  bool _quizStarted = false;
  List<QuizQuestion> _shuffledQuestions = [];
  List<TextEditingController> _answerCtrls = [];
  Timer? _timer;
  int _secondsRemaining = 0;
  int _totalSeconds = 0;
  DateTime? _startTime;
  int _timeTaken = 0;

  bool _submitting = false;
  bool _isCorrect = false;
  bool _completedLocal = false;
  int _attemptsUsed = 0;
  int? _lastScore;
  bool _isSubscribed = false;
  bool _isAdminOrSuperAdmin = false;
  bool _checkingSubscription = true;

  late Stream<Map<String, Map<String, dynamic>>> _quizProgressStream;

  bool _isReviewing = false;
  bool get _previewMode => widget.previewMode || widget.quiz.validationStatus == 'awaiting_approval';

  @override
  void initState() {
    super.initState();
    _shuffledQuestions = List.from(widget.quiz.questions)..shuffle();
    _answerCtrls = List.generate(
      _shuffledQuestions.length,
      (_) => TextEditingController(),
    );
    _secondsRemaining = widget.quiz.duration * 60;
    _totalSeconds = _secondsRemaining;
    _quizProgressStream = DatabaseService.instance.quizProgressStream(widget.user);
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    final role = await RoleService.instance.getRole(widget.user.uid);
    if (role == UserRole.admin || role == UserRole.superadmin) {
      if (mounted) {
        setState(() {
          _isSubscribed = true;
          _isAdminOrSuperAdmin = true;
          _checkingSubscription = false;
        });
      }
      return;
    }

    if (!widget.quiz.isMembersOnly || widget.quiz.createdByUid == widget.user.uid) {
      if (mounted) setState(() => _checkingSubscription = false);
      return;
    }
    final isSub = await DatabaseService.instance.isSubscribed(
      widget.quiz.createdByUid!,
      widget.user.uid,
    );
    if (mounted) {
      setState(() {
        _isSubscribed = isSub;
        _checkingSubscription = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var ctrl in _answerCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  bool get _allAnswered => _answerCtrls.every((ctrl) => ctrl.text.trim().isNotEmpty);

  void _startQuiz() {
    setState(() {
      _quizStarted = true;
      _startTime = DateTime.now();
      _completedLocal = false;
      _isReviewing = false;
    });
    if (widget.quiz.duration > 0) {
      _startTimer();
    }
  }

  void _startReview() {
    setState(() {
      _quizStarted = true;
      _isReviewing = true;
      _completedLocal = false;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      } else {
        _timer?.cancel();
        _submit(widget.quiz.maxAttempts, autoSubmit: true);
      }
    });
  }

  String _normalize(String s) => s.trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");

  Future<void> _submit(int maxAttempts, {bool autoSubmit = false}) async {
    if (_attemptsUsed >= maxAttempts && !_completedLocal && !autoSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No attempts remaining.')));
      return;
    }

    int score = 0;
    List<String> userAnswers = [];
    for (int i = 0; i < _shuffledQuestions.length; i++) {
      final input = _normalize(_answerCtrls[i].text);
      final expected = _normalize(_shuffledQuestions[i].answer);
      if (input == expected) score++;
      userAnswers.add(_answerCtrls[i].text.trim());
    }

    final bool isCorrect = score == _shuffledQuestions.length;

    setState(() => _submitting = true);
    _timer?.cancel();

    if (_startTime != null) {
      _timeTaken = DateTime.now().difference(_startTime!).inSeconds;
    }

    try {
      final double percentage = (score / _shuffledQuestions.length) * 100;
      final bool isPassed = percentage >= 90;

      final lesson = await DatabaseService.instance.getLessonByQuizId(widget.quiz.id);

      await DatabaseService.instance.completeQuizAndLesson(
        user: widget.user,
        quizId: widget.quiz.id,
        passed: isPassed,
        isCorrect: isCorrect,
        score: score,
        totalQuestions: _shuffledQuestions.length,
        answers: userAnswers,
        timeTaken: _timeTaken,
        lessonId: lesson?.id,
      );

      if (mounted) {
        setState(() {
          _submitting = false;
          _isCorrect = isCorrect;
          _lastScore = score;
          _completedLocal = true;
        });

        DatabaseService.instance.checkAndAwardAchievement(widget.user.uid, 'first_quiz').then((awarded) {
          if (awarded) {
            NotificationService.instance.sendAchievementNotification(
              uid: widget.user.uid,
              title: 'Quiz Mastery!',
              message: 'Congratulations on completing your first quiz on Grammatica!',
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPassed ? 'Quiz Mastery Achieved!' : 'Quiz submitted. Needs 90% to pass.',
            ),
            backgroundColor: isPassed ? AppColors.primary : AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
        title: const Text('Knowledge Quiz', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 900;

            return Center(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: StreamBuilder<Map<String, Map<String, dynamic>>>(
                            stream: _quizProgressStream,
                            builder: (context, snapshot) {
                              final progressMap = snapshot.data ?? {};
                              final myProgress = progressMap[widget.quiz.id];

                              if (myProgress != null) {
                                _attemptsUsed = (myProgress['attemptsUsed'] as num?)?.toInt() ?? 0;
                                _isCorrect = myProgress['isCorrect'] == true;

                                if (!_submitting) {
                                  _lastScore = (myProgress['score'] as num?)?.toInt();
                                  final serverTime = (myProgress['timeTaken'] as num?)?.toInt() ?? 0;
                                  if (!_quizStarted) {
                                    _timeTaken = serverTime;
                                  }
                                }
                              }

                              final maxAttempts = widget.quiz.maxAttempts;

                              if (_completedLocal || (_attemptsUsed > 0 && !_quizStarted)) {
                                return _buildResultsArea(maxAttempts);
                              }

                              if (_checkingSubscription) {
                                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                              }

                              if (!_quizStarted) {
                                return _buildStartArea(maxAttempts);
                              }

                              return _buildQuestionArea(maxAttempts);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isWide && _quizStarted && !_completedLocal)
                    SizedBox(
                      width: 320,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 100, 24, 40),
                        child: _buildQuestionSidePanel(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStartArea(int maxAttempts) {
    return Column(
      children: [
        if (_previewMode)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 32),
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
                    'PREVIEW MODE - Contents only view active.',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.quiz.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.quiz.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickInfo(Icons.timer_outlined, '${widget.quiz.duration} min'),
                    _buildQuickInfo(Icons.help_outline_rounded, '${widget.quiz.questions.length} questions'),
                    _buildQuickInfo(Icons.refresh_rounded, '$_attemptsUsed/$maxAttempts used'),
                  ],
                ),
                const SizedBox(height: 48),
                if (!_previewMode)
                  (maxAttempts - _attemptsUsed > 0)
                      ? (_isSubscribed || _isAdminOrSuperAdmin || !widget.quiz.isMembersOnly || widget.quiz.createdByUid == widget.user.uid
                          ? ElevatedButton(
                              onPressed: _startQuiz,
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 64)),
                              child: const Text('START CHALLENGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            )
                          : _buildLockMessage())
                      : _buildNoAttemptsMessage(),
                if (_previewMode)
                  OutlinedButton.icon(
                    onPressed: _startReview,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 64)),
                    icon: const Icon(Icons.rate_review_rounded),
                    label: const Text('REVIEW QUESTIONS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildLockMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.lock_rounded, color: AppColors.secondary, size: 32),
          SizedBox(height: 12),
          Text('Subscription Required', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
          SizedBox(height: 4),
          Text('You need an active subscription to take this quiz.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNoAttemptsMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.block_rounded, color: AppColors.error, size: 32),
          SizedBox(height: 12),
          Text('Maximum Attempts Reached', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
          SizedBox(height: 4),
          Text('You have already used all permitted attempts for this quiz.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildQuestionArea(int maxAttempts) {
    final question = _shuffledQuestions[_currentQuestionIndex];
    final isMultipleChoice = question.type == 'multiple_choice';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_shuffledQuestions.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13),
                    ),
                    if (widget.quiz.duration > 0 && !_isReviewing) _buildTimerBadge(),
                  ],
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / _shuffledQuestions.length,
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  question.question,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.4),
                ),
                const SizedBox(height: 40),
                if (isMultipleChoice)
                  ...question.options!.map((opt) {
                    final normalizedOpt = opt.trim();
                    final currentVal = _answerCtrls[_currentQuestionIndex].text.trim();
                    final isSelected = currentVal == normalizedOpt;
                    final isCorrectAnswer = normalizedOpt == question.answer.trim();

                    Color borderColor = AppColors.divider;
                    Color bgColor = AppColors.surface;
                    if (isSelected) borderColor = AppColors.primary;
                    if (_isReviewing) {
                      if (isCorrectAnswer) {
                        borderColor = AppColors.primary;
                        bgColor = AppColors.primary.withOpacity(0.1);
                      } else if (isSelected) {
                        borderColor = AppColors.error;
                        bgColor = AppColors.error.withOpacity(0.1);
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: _isReviewing
                            ? null
                            : () => setState(() => _answerCtrls[_currentQuestionIndex].text = normalizedOpt),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: isSelected || (_isReviewing && isCorrectAnswer) ? 2 : 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider, width: isSelected ? 8 : 2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(normalizedOpt, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                              ),
                              if (_isReviewing && isCorrectAnswer)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                              if (_isReviewing && isSelected && !isCorrectAnswer)
                                const Icon(Icons.cancel_rounded, color: AppColors.error),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _answerCtrls[_currentQuestionIndex],
                        enabled: !_isReviewing,
                        autofocus: true,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: 'Type your answer here',
                          fillColor: AppColors.surface,
                          filled: true,
                          contentPadding: EdgeInsets.all(24),
                        ),
                        onChanged: (v) => setState(() {}),
                      ),
                      if (_isReviewing)
                        Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CORRECT ANSWER:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text(question.answer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentQuestionIndex > 0)
              TextButton.icon(
                onPressed: () => setState(() => _currentQuestionIndex--),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('PREVIOUS'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), foregroundColor: AppColors.textSecondary),
              )
            else
              const SizedBox(),
            if (_currentQuestionIndex < _shuffledQuestions.length - 1)
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentQuestionIndex++),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('NEXT'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              )
            else if (!_isReviewing)
              ElevatedButton(
                onPressed: (_submitting || !_allAnswered) ? null : () => _confirmSubmission(maxAttempts),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
                child: _submitting
                    ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    : const Text('FINISH QUIZ'),
              ),
          ],
        ),
        if (!_isReviewing && !_allAnswered && _currentQuestionIndex == _shuffledQuestions.length - 1)
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Text(
              'Please provide all answers to finalize your submission.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildTimerBadge() {
    final bool isLow = _secondsRemaining < 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isLow ? AppColors.error : AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isLow ? AppColors.error : AppColors.primary).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 18, color: isLow ? AppColors.error : AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
            style: TextStyle(fontWeight: FontWeight.bold, color: isLow ? AppColors.error : AppColors.primary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSidePanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Navigator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _shuffledQuestions.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == _currentQuestionIndex;
                  final isAnswered = _answerCtrls[index].text.trim().isNotEmpty;

                  return InkWell(
                    onTap: () => setState(() => _currentQuestionIndex = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.primary : (isAnswered ? AppColors.primary.withOpacity(0.1) : AppColors.divider.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrent ? null : Border.all(color: isAnswered ? AppColors.primary.withOpacity(0.5) : AppColors.divider),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : (isAnswered ? AppColors.primary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSubmission(int maxAttempts) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Quiz'),
        content: const Text('Are you sure you want to submit your answers now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not Yet')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Submit')),
        ],
      ),
    );

    if (confirm == true) {
      _submit(maxAttempts);
    }
  }

  Widget _buildResultsArea(int maxAttempts) {
    final minutes = _timeTaken ~/ 60;
    final seconds = _timeTaken % 60;
    final timeStr = minutes > 0 ? '$minutes m $seconds s' : '$seconds s';

    final remainingAttempts = (maxAttempts - _attemptsUsed).clamp(0, maxAttempts);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: (_isCorrect ? AppColors.primary : AppColors.secondary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_isCorrect ? Icons.stars_rounded : Icons.emoji_events_rounded, size: 80, color: _isCorrect ? AppColors.primary : AppColors.secondary),
        ),
        const SizedBox(height: 32),
        Text(
          _isCorrect ? 'Stellar Performance!' : 'Challenge Complete!',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Score', '${_lastScore ?? 0}/${_shuffledQuestions.length}', AppColors.primary),
            _buildStatItem('Duration', timeStr, AppColors.secondary),
          ],
        ),
        const SizedBox(height: 48),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  _isCorrect ? 'You have mastered this content!' : 'Excellent effort! Continue practicing to reach mastery.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                if (!_isCorrect && remainingAttempts > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Precision attempts remaining: $remainingAttempts',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        if (!_isCorrect && remainingAttempts > 0)
          ElevatedButton(
            onPressed: () {
              setState(() {
                _quizStarted = true;
                _completedLocal = false;
                _currentQuestionIndex = 0;
                for (var ctrl in _answerCtrls) {
                  ctrl.clear();
                }
                _secondsRemaining = widget.quiz.duration * 60;
                _startTime = DateTime.now();
              });
              if (widget.quiz.duration > 0) {
                _startTimer();
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(240, 64)),
            child: const Text('RETRY CHALLENGE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Return to Lesson'),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
