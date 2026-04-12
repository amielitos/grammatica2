import 'package:confetti/confetti.dart';
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
import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
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
  late ConfettiController _confettiController;

  bool _isReviewing = false;
  bool get _previewMode => widget.previewMode || widget.quiz.validationStatus == 'awaiting_approval';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _shuffledQuestions = List.from(widget.quiz.questions)..shuffle();
    _answerCtrls = List.generate(
      _shuffledQuestions.length,
      (_) => TextEditingController(),
    );
    _secondsRemaining = widget.quiz.duration * 60;
    _totalSeconds = _secondsRemaining;
    _quizProgressStream = DatabaseService.instance.quizProgressStream(widget.user);
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _checkSubscription();
  }

  Future<void> _fetchUserData() async {
    final data = await DatabaseService.instance.getUserData(widget.user.uid);
    if (mounted) {
      setState(() {
        _userData = data;
      });
    }
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
    _confettiController.dispose();
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
          _confettiController.play();
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
      appBar: CustomAppBar(
        user: widget.user,
        userData: _userData,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
        onLogoTap: () => Navigator.pop(context),
        onProfileTap: () => Navigator.pop(context),
      ),
      drawer: UniversalDrawer(
        user: widget.user,
        userData: _userData ?? {},
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFCEDA72),
              Color(0xFFE4EB6F),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 900;

            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    physics: _completedLocal ? const NeverScrollableScrollPhysics() : null,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_completedLocal)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24, left: 12),
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.black.withOpacity(0.6)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Back to Lessons',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black.withOpacity(0.7)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1300),
                          child: Container(
                            padding: const EdgeInsets.all(64),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 850),
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
                                            return const Center(child: CircularProgressIndicator(color: Colors.white));
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
                                if (isWide && _quizStarted && !_completedLocal)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 48),
                                    child: SizedBox(
                                      width: 300,
                                      child: _buildQuestionSidePanel(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                    numberOfParticles: 50,
                    gravity: 0.1,
                  ),
                ),
              ],
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PREVIEW MODE - Contents only view active.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF88B342), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.quiz.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.quiz.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _metaText('creator'),
                    const SizedBox(width: 24),
                    _metaText('date created'),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.black26),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _statBox(
                        color: const Color(0xFFFBE681),
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '${widget.quiz.duration.toString().padLeft(2, '0')}:00',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statBox(
                        color: const Color(0xFFF7837F),
                        icon: Icons.help_outline_rounded,
                        label: 'Questions',
                        value: '${widget.quiz.questions.length}',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _statBox(
                        color: const Color(0xFF8FF683),
                        icon: Icons.refresh_rounded,
                        label: 'Attempts',
                        value: '$_attemptsUsed/$maxAttempts',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.black26),
                const SizedBox(height: 48),
                if (!_previewMode)
                  (maxAttempts - _attemptsUsed > 0)
                      ? (_isSubscribed || _isAdminOrSuperAdmin || !widget.quiz.isMembersOnly || widget.quiz.createdByUid == widget.user.uid
                          ? Center(
                              child: SizedBox(
                                width: 340,
                                child: ElevatedButton(
                                  onPressed: _startQuiz,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF88B342),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 64),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Start Quiz',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : _buildLockMessage())
                      : _buildNoAttemptsMessage(),
                if (_previewMode)
                  OutlinedButton.icon(
                    onPressed: _startReview,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 64),
                      side: const BorderSide(color: Color(0xFF88B342)),
                      foregroundColor: const Color(0xFF88B342),
                    ),
                    icon: const Icon(Icons.rate_review_rounded),
                    label: const Text('Review Questions', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaText(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.black45, fontSize: 14),
    );
  }

  Widget _statBox({
    required Color color,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.black87),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
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
    if (_shuffledQuestions.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('This quiz has no questions yet.', style: TextStyle(fontSize: 18, color: Colors.grey))));
    }
    final question = _shuffledQuestions[_currentQuestionIndex];
    final isMultipleChoice = question.type == 'multiple_choice';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _shuffledQuestions.length,
                  minHeight: 12,
                  backgroundColor: AppColors.divider.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  if (widget.quiz.duration > 0 && !_isReviewing) _buildTimerBadge(),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                question.question,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Colors.black87, height: 1.4),
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
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: _isReviewing
                            ? null
                            : () => setState(() => _answerCtrls[_currentQuestionIndex].text = normalizedOpt),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.black12, width: isSelected ? 2 : 1),
                            boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSelected ? AppColors.primary : Colors.black26, width: 2),
                                ),
                                child: isSelected
                                    ? Center(child: Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)))
                                    : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(normalizedOpt, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w400)),
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
                        maxLines: 10,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Type your answer here...',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 18),
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          contentPadding: const EdgeInsets.all(32),
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
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_currentQuestionIndex > 0)
              SizedBox(
                width: 160,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentQuestionIndex--),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Previous', style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
              ),
            if (_currentQuestionIndex > 0) const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: (_currentQuestionIndex < _shuffledQuestions.length - 1)
                  ? ElevatedButton(
                      onPressed: () => setState(() => _currentQuestionIndex++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_forward_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Next', style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal)),
                        ],
                      ),
                    )
                  : (!_isReviewing)
                      ? ElevatedButton(
                          onPressed: (_submitting || !_allAnswered) ? null : () => _confirmSubmission(maxAttempts),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: _submitting
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Finish', style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal)),
                        )
                      : const SizedBox(),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.12), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const Text(
            'Questions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shuffledQuestions.length,
            itemBuilder: (context, index) {
              final isSelected = index == _currentQuestionIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _currentQuestionIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.black26),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Question ${index + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
    final timeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    final double percentage = (_lastScore ?? 0) / _shuffledQuestions.length;
    String feedbackMessage = 'Keep practicing to achieve mastery! ✨';
    if (percentage >= 1.0) {
      feedbackMessage = 'Perfect Score! You are a true Grammatica expert! 🏆';
    } else if (percentage >= 0.9) {
      feedbackMessage = 'Stellar performance! You have mastered this content. 🌟';
    } else if (percentage >= 0.7) {
      feedbackMessage = 'Great job! You\'re very close to mastery. 💪';
    } else if (percentage >= 0.5) {
      feedbackMessage = 'Good effort! A bit more review and you\'ll get there. 📚';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE69F),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
          ),
          child: const Center(
            child: Icon(
              Icons.emoji_events_rounded,
              size: 60,
              color: Color(0xFFF9A825),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Quiz Complete!',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildResultPill(
              label: 'Score',
              value: '${_lastScore ?? 0}/${_shuffledQuestions.length}',
              color: const Color(0xFFFEE69F),
              textColor: const Color(0xFFF9A825),
            ),
            const SizedBox(width: 24),
            _buildResultPill(
              label: 'Duration',
              value: timeStr,
              color: const Color(0xFFCEDA72).withOpacity(0.5),
              textColor: const Color(0xFF88B342),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: 500,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          alignment: Alignment.center,
          child: Text(
            feedbackMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.normal),
          ),
        ),
        if (!_isCorrect && (maxAttempts - _attemptsUsed) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _quizStarted = true;
                  _completedLocal = false;
                  _currentQuestionIndex = 0;
                  for (var ctrl in _answerCtrls) ctrl.clear();
                  _secondsRemaining = widget.quiz.duration * 60;
                  _startTime = DateTime.now();
                });
                if (widget.quiz.duration > 0) _startTimer();
              },
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
      ],
    );
  }

  Widget _buildResultPill({
    required String label,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textColor.withOpacity(0.8)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
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
