import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';

import 'dart:async';
import '../widgets/glass_card.dart';
import '../theme/app_colors.dart';
import '../widgets/notification_widgets.dart';
import '../services/notification_service.dart';
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

  bool _isReviewing = false;
  bool get _previewMode =>
      widget.previewMode || widget.quiz.validationStatus == 'awaiting_approval';

  @override
  void initState() {
    super.initState();
    _shuffledQuestions = List.from(widget.quiz.questions)..shuffle();
    _answerCtrls = List.generate(
      _shuffledQuestions.length,
      (_) => TextEditingController(),
    );
    _secondsRemaining = widget.quiz.duration * 60;
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

    if (!widget.quiz.isMembersOnly ||
        widget.quiz.createdByUid == widget.user.uid) {
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

  bool get _allAnswered =>
      _answerCtrls.every((ctrl) => ctrl.text.trim().isNotEmpty);

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

  String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");

  Future<void> _submit(int maxAttempts, {bool autoSubmit = false}) async {
    // Basic check against local snapshot of attempts
    if (_attemptsUsed >= maxAttempts && !_completedLocal && !autoSubmit) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No attempts remaining.')));
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
      await DatabaseService.instance.markQuizCompleted(
        user: widget.user,
        quizId: widget.quiz.id,
        isCorrect: isCorrect,
        score: score,
        totalQuestions: _shuffledQuestions.length,
        answers: userAnswers,
        timeTaken: _timeTaken,
      );

      if (mounted) {
        setState(() {
          _submitting = false;
          _isCorrect = isCorrect;
          _lastScore = score;
          _completedLocal = true;
        });

        // Trigger Achievement Notification for first quiz
        DatabaseService.instance
            .checkAndAwardAchievement(widget.user.uid, 'first_quiz')
            .then((awarded) {
              if (awarded) {
                NotificationService.instance.sendAchievementNotification(
                  uid: widget.user.uid,
                  title: 'First Quiz Completed!',
                  message:
                      'Congratulations on completing your first quiz on Grammatica!',
                );
              }
            });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCorrect
                  ? 'Quiz Submitted! All correct!'
                  : 'Quiz Submitted! Score: $score/${_shuffledQuestions.length}.',
            ),
            backgroundColor: isCorrect ? Colors.green : Colors.orange,
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
      body: LayoutBuilder(
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
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: StreamBuilder<Map<String, Map<String, dynamic>>>(
                              stream: DatabaseService.instance
                                  .quizProgressStream(widget.user),
                              builder: (context, snapshot) {
                                final progressMap = snapshot.data ?? {};
                                final myProgress = progressMap[widget.quiz.id];

                                if (myProgress != null) {
                                  _attemptsUsed =
                                      (myProgress['attemptsUsed'] as num?)
                                          ?.toInt() ??
                                      0;
                                  _isCorrect = myProgress['isCorrect'] == true;

                                  if (!_submitting) {
                                    _lastScore = (myProgress['score'] as num?)
                                        ?.toInt();
                                    final serverTime =
                                        (myProgress['timeTaken'] as num?)
                                            ?.toInt() ??
                                        0;
                                    // Only update _timeTaken from server if we aren't currently tracking local time
                                    if (!_quizStarted) {
                                      _timeTaken = serverTime;
                                    }
                                  }
                                }

                                final maxAttempts = widget.quiz.maxAttempts;

                                // Show results if finished locally OR they have used attempts and aren't in a new one
                                if (_completedLocal ||
                                    (_attemptsUsed > 0 && !_quizStarted)) {
                                  return _buildResultsArea(maxAttempts);
                                }

                                if (_checkingSubscription) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
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
                  ),
                ),
                if (isWide && _quizStarted && !_completedLocal)
                  SizedBox(
                    width: 300,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: _buildQuestionSidePanel(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStartArea(int maxAttempts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_previewMode)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview Mode - You are viewing this quiz contents. Submission is disabled.',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          widget.quiz.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(widget.quiz.description),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 20),
            const SizedBox(width: 8),
            Text('${widget.quiz.duration} minutes'),
            const Spacer(),
            Text('Attempts Used: $_attemptsUsed / $maxAttempts'),
          ],
        ),
        const SizedBox(height: 32),
        if (!_previewMode && maxAttempts - _attemptsUsed > 0)
          SizedBox(
            width: double.infinity,
            child:
                _isSubscribed ||
                    _isAdminOrSuperAdmin ||
                    !widget.quiz.isMembersOnly ||
                    widget.quiz.createdByUid == widget.user.uid
                ? FilledButton(
                    onPressed: _startQuiz,
                    child: const Text('Start Quiz'),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock, color: Colors.orange),
                        const SizedBox(height: 8),
                        const Text(
                          'Members Only Content',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'You must be subscribed to this educator to take this quiz.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        if (_previewMode)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startReview,
              icon: const Icon(Icons.rate_review),
              label: const Text('Review Questions'),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionArea(int maxAttempts) {
    final question = _shuffledQuestions[_currentQuestionIndex];
    final isMultipleChoice = question.type == 'multiple_choice';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}/${_shuffledQuestions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.quiz.duration > 0 && !_isReviewing) _buildTimerBadge(),
          ],
        ),
        const SizedBox(height: 24),
        Text(question.question, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        if (isMultipleChoice)
          ...(question.options ?? []).map((opt) {
            final isSelected =
                _answerCtrls[_currentQuestionIndex].text.trim() == opt.trim();
            final isCorrectAnswer = opt.trim() == question.answer.trim();

            // In review mode, highlight correct answer green
            Color? cardColor;
            if (_isReviewing) {
              if (isCorrectAnswer) {
                cardColor = Colors.green.withValues(alpha: 0.2);
              }
            } else if (isSelected) {
              cardColor = AppColors.primaryGreen.withValues(alpha: 0.2);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GlassCard(
                onTap: _isReviewing
                    ? null
                    : () {
                        setState(() {
                          _answerCtrls[_currentQuestionIndex].text = opt;
                        });
                      },
                backgroundColor: cardColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: opt.trim(),
                        groupValue: _answerCtrls[_currentQuestionIndex].text
                            .trim(),
                        onChanged: _isReviewing
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _answerCtrls[_currentQuestionIndex].text =
                                        val;
                                  });
                                }
                              },
                        activeColor: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontWeight:
                                (isSelected ||
                                    (_isReviewing && isCorrectAnswer))
                                ? FontWeight.bold
                                : null,
                            color: (_isReviewing && isCorrectAnswer)
                                ? Colors.green[800]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _answerCtrls[_currentQuestionIndex],
                decoration: const InputDecoration(
                  hintText: 'Type your answer here...',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isReviewing, // Disable input in review mode
                autofocus: !_isReviewing,
                onChanged: (v) => setState(() {}),
              ),
              if (_isReviewing)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Correct Answer: ${question.answer}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentQuestionIndex > 0)
              TextButton(
                onPressed: () {
                  setState(() => _currentQuestionIndex--);
                },
                child: const Text('Previous'),
              )
            else
              const SizedBox(),
            if (_currentQuestionIndex < _shuffledQuestions.length - 1)
              FilledButton(
                onPressed: () {
                  setState(() => _currentQuestionIndex++);
                },
                child: const Text('Next'),
              )
            else if (!_isReviewing)
              SizedBox(
                width: 120,
                child: FilledButton(
                  onPressed: (_submitting || !_allAnswered)
                      ? null
                      : () => _confirmSubmission(maxAttempts),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ),
          ],
        ),
        if (!_isReviewing &&
            !_allAnswered &&
            _currentQuestionIndex == _shuffledQuestions.length - 1)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Please answer all questions before submitting.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTimerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _secondsRemaining < 60
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: _secondsRemaining < 60 ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _secondsRemaining < 60 ? Colors.red : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSidePanel() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Questions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _shuffledQuestions.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == _currentQuestionIndex;
                  final isAnswered = _answerCtrls[index].text.trim().isNotEmpty;

                  return ListTile(
                    dense: true,
                    selected: isCurrent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tileColor: isCurrent
                        ? Colors.blue.withValues(alpha: 0.1)
                        : null,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: isAnswered
                          ? Colors.green
                          : Colors.grey[300],
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      'Question ${index + 1}',
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _currentQuestionIndex = index;
                      });
                    },
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
        title: const Text('Submit Quiz?'),
        content: const Text('Do you want to submit your answers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Submit'),
          ),
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
    final timeStr = minutes > 0 ? '$minutes m $seconds s' : '$seconds seconds';

    final remainingAttempts = (maxAttempts - _attemptsUsed).clamp(
      0,
      maxAttempts,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isCorrect
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isCorrect ? Icons.check_circle : Icons.info_outline,
            size: 64,
            color: _isCorrect ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isCorrect ? 'Congratulations!' : 'Quiz Finished',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              'Score',
              '${_lastScore ?? 0} / ${_shuffledQuestions.length}',
            ),
            _buildStatItem('Time', timeStr),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          _isCorrect
              ? 'You have successfully completed this quiz.'
              : 'Keep practicing! You have $remainingAttempts attempts remaining.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (!_isCorrect && remainingAttempts > 0)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _quizStarted = true; // Directly start a new attempt
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
              child: const Text('Try Again'),
            ),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Quizzes'),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
