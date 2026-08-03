import 'package:confetti/confetti.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_widgets.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
import 'package:google_fonts/google_fonts.dart';

class _RenderableQuestion {
  final QuizQuestion question;
  final QuizQuestion? parentPassage;
  final int? nestedIndex; // 0-indexed index within the passage

  _RenderableQuestion({
    required this.question,
    this.parentPassage,
    this.nestedIndex,
  });
}

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
  List<_RenderableQuestion> _shuffledQuestions = [];
  final Map<String, TextEditingController> _answerCtrlsMap = {};
  final Map<int, int> _selectedNestedIndexMap = {};
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

  late Stream<Map<String, Map<String, dynamic>>> _quizProgressStream;
  late ConfettiController _confettiController;

  bool _isReviewing = false;
  bool get _previewMode => widget.previewMode || widget.quiz.validationStatus == 'awaiting_approval';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    
    // Keep top-level questions unflattened
    final originalQuestions = List<QuizQuestion>.from(widget.quiz.questions);
    originalQuestions.shuffle();
    
    _shuffledQuestions = originalQuestions.map((q) => _RenderableQuestion(question: q)).toList();
    
    for (int i = 0; i < _shuffledQuestions.length; i++) {
      final q = _shuffledQuestions[i].question;
      if (q.type == 'passage') {
        _selectedNestedIndexMap[i] = 0;
        if (q.nestedQuestions != null) {
          for (int j = 0; j < q.nestedQuestions!.length; j++) {
            _answerCtrlsMap["${i}_${j}"] = TextEditingController();
          }
        }
      } else {
        _answerCtrlsMap["$i"] = TextEditingController();
      }
    }
    
    _secondsRemaining = widget.quiz.duration * 60;
    _quizProgressStream = DatabaseService.instance.quizProgressStream(widget.user);
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _checkSubscription();
  }


  Future<void> _fetchUserData() async {
    final data = await DatabaseService.instance.getUserData(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _userData = data;
    });
  }

  Future<void> _checkSubscription() async {
    final role = await RoleService.instance.getRole(widget.user.uid);
    if (!mounted) return;
    if (role == UserRole.admin || role == UserRole.superadmin) {
      setState(() {
        _isSubscribed = true;
        _isAdminOrSuperAdmin = true;
        _checkingSubscription = false;
      });
      return;
    }

    if (!widget.quiz.isMembersOnly || widget.quiz.createdByUid == widget.user.uid) {
      setState(() => _checkingSubscription = false);
      return;
    }
    final isSub = await DatabaseService.instance.isSubscribed(
      widget.quiz.createdByUid!,
      widget.user.uid,
    );
    if (!mounted) return;
    setState(() {
      _isSubscribed = isSub;
      _checkingSubscription = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var ctrl in _answerCtrlsMap.values) {
      ctrl.dispose();
    }
    _confettiController.dispose();
    super.dispose();
  }

  bool get _allAnswered {
    for (int i = 0; i < _shuffledQuestions.length; i++) {
      final q = _shuffledQuestions[i].question;
      if (q.type == 'passage') {
        if (q.nestedQuestions != null) {
          for (int j = 0; j < q.nestedQuestions!.length; j++) {
            final ctrl = _answerCtrlsMap["${i}_${j}"];
            if (ctrl == null || ctrl.text.trim().isEmpty) return false;
          }
        }
      } else {
        final ctrl = _answerCtrlsMap["$i"];
        if (ctrl == null || ctrl.text.trim().isEmpty) return false;
      }
    }
    return true;
  }

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
    int scorableCount = 0;
    for (int i = 0; i < _shuffledQuestions.length; i++) {
      final q = _shuffledQuestions[i].question;
      if (q.type == 'passage') {
        if (q.nestedQuestions != null) {
          for (int j = 0; j < q.nestedQuestions!.length; j++) {
            final nq = q.nestedQuestions![j];
            scorableCount++;
            final ctrl = _answerCtrlsMap["${i}_${j}"];
            final input = _normalize(ctrl?.text ?? '');
            final expected = _normalize(nq.answer);
            if (input == expected) score++;
            userAnswers.add(ctrl?.text.trim() ?? '');
          }
        }
      } else {
        scorableCount++;
        final ctrl = _answerCtrlsMap["$i"];
        final input = _normalize(ctrl?.text ?? '');
        final expected = _normalize(q.answer);
        if (input == expected) score++;
        userAnswers.add(ctrl?.text.trim() ?? '');
      }
    }


    final bool isCorrect = score == scorableCount;

    setState(() => _submitting = true);
    _timer?.cancel();

    if (_startTime != null) {
      _timeTaken = DateTime.now().difference(_startTime!).inSeconds;
    }

    try {
      final double percentage = scorableCount > 0 ? (score / scorableCount) * 100 : 100.0;
      final bool isPassed = percentage >= 90;

      final lesson = await DatabaseService.instance.getLessonByQuizId(widget.quiz.id);

      await DatabaseService.instance.completeQuizAndLesson(
        user: widget.user,
        quizId: widget.quiz.id,
        passed: isPassed,
        isCorrect: isCorrect,
        score: score,
        totalQuestions: scorableCount,
        answers: userAnswers,
        timeTaken: _timeTaken,
        lessonId: lesson?.id,
      );

      if (!mounted) return;
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
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_quizStarted || _completedLocal || _previewMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: CustomAppBar(
        user: widget.user,
        userData: _userData,
        showBackButton: _previewMode,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
        onLogoTap: () async {
          if (_quizStarted && !_completedLocal && !_previewMode) {
            final shouldPop = await _showExitConfirmation();
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop();
            }
          } else {
            Navigator.of(context).pop();
          }
        },
        onProfileTap: () async {
          if (_quizStarted && !_completedLocal && !_previewMode) {
            final shouldPop = await _showExitConfirmation();
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop();
            }
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      drawer: UniversalDrawer(
        user: widget.user,
        userData: _userData ?? {},
        onTap: (i) async {
          if (_quizStarted && !_completedLocal && !_previewMode) {
            final shouldPop = await _showExitConfirmation();
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop(); // Close drawer
              Navigator.of(context).pop(); // Go back to lesson/practice
            }
          } else {
            Navigator.of(context).pop(); // Close drawer
            Navigator.of(context).pop(); // Go back
          }
        },
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
                    padding: EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 32),
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
                                  Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.black.withValues(alpha: 0.6)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Back to Lessons',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1300),
                          child: Container(
                            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : (constraints.maxWidth < 900 ? 32 : 64)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(constraints.maxWidth < 600 ? 16 : 32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
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
    ),
  );
}

  Future<bool?> _showExitConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Quit Quiz?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to quit this quiz? Your progress will not be saved.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Quit'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartArea(int maxAttempts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Column(
      children: [
        if (_previewMode)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PREVIEW MODE - Contents only view active.',
                    style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF76A34F), Color(0xFF5A8A38)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.quiz_rounded, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.quiz.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.quiz.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statBox(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            iconColor: AppColors.primary,
                            icon: Icons.timer_outlined,
                            label: 'Duration',
                            value: '${widget.quiz.duration.toString().padLeft(2, '0')}:00',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _statBox(
                            color: Colors.blue.withValues(alpha: 0.1),
                            iconColor: Colors.blue,
                            icon: Icons.help_outline_rounded,
                            label: 'Questions',
                            value: '${widget.quiz.questions.length}',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _statBox(
                            color: Colors.orange.withValues(alpha: 0.1),
                            iconColor: Colors.orange,
                            icon: Icons.refresh_rounded,
                            label: 'Attempts',
                            value: '$_attemptsUsed/$maxAttempts',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
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
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 64),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'Start Quiz',
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : _buildLockMessage(isDark))
                          : _buildNoAttemptsMessage(isDark),
                    if (_previewMode)
                      OutlinedButton.icon(
                        onPressed: _startReview,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 64),
                          side: const BorderSide(color: AppColors.primary, width: 2),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.rate_review_rounded),
                        label: Text('Review Questions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox({
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.transparent),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: iconColor),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.secondary, size: 36),
          const SizedBox(height: 16),
          Text('Subscription Required', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(height: 8),
          Text('You need an active subscription to take this quiz.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildNoAttemptsMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.error, size: 36),
          const SizedBox(height: 16),
          Text('No Attempts Left', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error)),
          const SizedBox(height: 8),
          Text('You have used all available attempts for this quiz.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildQuestionArea(int maxAttempts) {
if (_shuffledQuestions.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('This quiz has no questions yet.', style: TextStyle(fontSize: 18, color: Colors.grey))));
    }
    final renderable = _shuffledQuestions[_currentQuestionIndex];
    final question = renderable.question;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    if (question.type == 'passage') {
      final nestedQuestions = question.nestedQuestions ?? [];
      final selectedNestedIndex = _selectedNestedIndexMap[_currentQuestionIndex] ?? 0;
      final activeNestedQuestion = nestedQuestions.isNotEmpty && selectedNestedIndex < nestedQuestions.length
          ? nestedQuestions[selectedNestedIndex]
          : null;
      final isMultipleChoice = activeNestedQuestion?.type == 'multiple_choice';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Passage ${_currentQuestionIndex + 1} of ${_shuffledQuestions.length}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.0),
                    ),
                    if (widget.quiz.duration > 0 && !_isReviewing) _buildTimerBadge(),
                  ],
                ),
                const SizedBox(height: 24),
                
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              'READING PASSAGE',
                              style: GoogleFonts.inter(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold, 
                                color: AppColors.primary, 
                                letterSpacing: 1.2
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: SelectableText(
                          question.question,
                          style: GoogleFonts.inter(
                            fontSize: 16, 
                            height: 1.6, 
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                if (nestedQuestions.isNotEmpty) ...[
                  Text(
                    'Select Question:',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedNestedIndex,
                    dropdownColor: cardColor,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
                    ),
                    items: List.generate(nestedQuestions.length, (idx) {
                      return DropdownMenuItem<int>(
                        value: idx,
                        child: Text(
                          'Question ${idx + 1}',
                          style: GoogleFonts.inter(fontSize: 15, color: textColor),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedNestedIndexMap[_currentQuestionIndex] = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 32),

                  if (activeNestedQuestion != null) ...[
                    Text(
                      activeNestedQuestion.question,
                      style: GoogleFonts.outfit(
                        fontSize: 24, 
                        fontWeight: FontWeight.w600, 
                        color: textColor, 
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (isMultipleChoice)
                      ...activeNestedQuestion.options!.map((opt) {
                        final normalizedOpt = opt.trim();
                        final currentVal = (_answerCtrlsMap["${_currentQuestionIndex}_$selectedNestedIndex"]?.text ?? '').trim();
                        final isSelected = currentVal == normalizedOpt;
                        final isCorrectAnswer = normalizedOpt == activeNestedQuestion.answer.trim();

                        Color borderColor = isDark ? Colors.white12 : Colors.black12;
                        Color bgColor = isDark ? const Color(0xFF333333) : Colors.white;
                        
                        if (isSelected) {
                          borderColor = AppColors.primary;
                          bgColor = AppColors.primary.withValues(alpha: 0.05);
                        }

                        if (_isReviewing && isSelected && !isCorrectAnswer) {
                          borderColor = AppColors.error;
                          bgColor = AppColors.error.withValues(alpha: 0.05);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: _isReviewing
                                ? null
                                : () => setState(() => _answerCtrlsMap["${_currentQuestionIndex}_$selectedNestedIndex"]?.text = normalizedOpt),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isSelected ? borderColor : (isDark ? Colors.white30 : Colors.black26), width: 2),
                                    ),
                                    child: isSelected
                                        ? Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: borderColor)))
                                        : null,
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Text(normalizedOpt, style: GoogleFonts.inter(fontSize: 16, color: textColor, fontWeight: FontWeight.w500)),
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
                            controller: _answerCtrlsMap["${_currentQuestionIndex}_$selectedNestedIndex"],
                            enabled: !_isReviewing,
                            autofocus: true,
                            maxLines: 6,
                            style: GoogleFonts.inter(fontSize: 16, color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Type your answer here...',
                              hintStyle: GoogleFonts.inter(color: isDark ? Colors.white30 : Colors.black38),
                              fillColor: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(24),
                            ),
                            onChanged: (v) => setState(() {}),
                          ),
                          if (_isReviewing)
                            Container(
                              margin: const EdgeInsets.only(top: 24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1), 
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text('CORRECT ANSWER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(activeNestedQuestion.answer, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ],
              ],
            ),
          ),
        ],
      );
    }

    final isMultipleChoice = question.type == 'multiple_choice';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${_shuffledQuestions.length}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.0),
                  ),
                  if (widget.quiz.duration > 0 && !_isReviewing) _buildTimerBadge(),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                question.question,
                style: GoogleFonts.outfit(
                  fontSize: 28, 
                  fontWeight: FontWeight.w600, 
                  color: textColor, 
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),
              if (isMultipleChoice)
                ...question.options!.map((opt) {
                  final normalizedOpt = opt.trim();
                  final currentVal = (_answerCtrlsMap["$_currentQuestionIndex"]?.text ?? '').trim();
                  final isSelected = currentVal == normalizedOpt;
                  final isCorrectAnswer = normalizedOpt == question.answer.trim();

                  Color borderColor = isDark ? Colors.white12 : Colors.black12;
                  Color bgColor = isDark ? const Color(0xFF333333) : Colors.white;
                  
                  if (isSelected) {
                    borderColor = AppColors.primary;
                    bgColor = AppColors.primary.withValues(alpha: 0.05);
                  }

                  if (_isReviewing && isSelected && !isCorrectAnswer) {
                    borderColor = AppColors.error;
                    bgColor = AppColors.error.withValues(alpha: 0.05);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: _isReviewing
                          ? null
                          : () => setState(() => _answerCtrlsMap["$_currentQuestionIndex"]?.text = normalizedOpt),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: isSelected ? borderColor : (isDark ? Colors.white30 : Colors.black26), width: 2),
                              ),
                              child: isSelected
                                  ? Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: borderColor)))
                                  : null,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(normalizedOpt, style: GoogleFonts.inter(fontSize: 16, color: textColor, fontWeight: FontWeight.w500)),
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
                      controller: _answerCtrlsMap["$_currentQuestionIndex"],
                      enabled: !_isReviewing,
                      autofocus: true,
                      maxLines: 6,
                      style: GoogleFonts.inter(fontSize: 16, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Type your answer here...',
                        hintStyle: GoogleFonts.inter(color: isDark ? Colors.white30 : Colors.black38),
                        fillColor: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(24),
                      ),
                      onChanged: (v) => setState(() {}),
                    ),
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text('EXPLANATION & HINT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade700, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (question.hint != null && question.hint!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text('Hint: ${question.hint}', style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87)),
                        ),
                      if (question.explanation != null && question.explanation!.isNotEmpty)
                        Text(question.explanation!, style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87)),
                    ],
                  ),
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
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _currentQuestionIndex--),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: Text('Previous', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            if (_currentQuestionIndex > 0) const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: (_currentQuestionIndex < _shuffledQuestions.length - 1)
                  ? ElevatedButton.icon(
                      onPressed: () => setState(() => _currentQuestionIndex++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text('Next', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : (!_isReviewing)
                      ? ElevatedButton(
                          onPressed: (_submitting || !_allAnswered) ? null : () => _confirmSubmission(maxAttempts),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Finish Quiz', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        )
                      : const SizedBox(),
            ),
          ],
        ),
        if (!_isReviewing && !_allAnswered && _currentQuestionIndex == _shuffledQuestions.length - 1)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Text(
              'Please answer all questions to submit your quiz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.w600),
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
        color: (isLow ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 16, color: isLow ? AppColors.error : AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isLow ? AppColors.error : AppColors.primary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSidePanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Questions',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _shuffledQuestions.length,
            itemBuilder: (context, index) {
              final isSelected = index == _currentQuestionIndex;
              final q = _shuffledQuestions[index].question;
              
              bool isAnswered = false;
              if (q.type == 'passage') {
                isAnswered = true;
                if (q.nestedQuestions != null) {
                  for (int j = 0; j < q.nestedQuestions!.length; j++) {
                    final ctrl = _answerCtrlsMap["${index}_$j"];
                    if (ctrl == null || ctrl.text.trim().isEmpty) {
                      isAnswered = false;
                      break;
                    }
                  }
                }
              } else {
                isAnswered = _answerCtrlsMap["$index"]?.text.trim().isNotEmpty ?? false;
              }
              
              Color bgColor = Colors.transparent;
              Color textColor = isDark ? Colors.white70 : AppColors.textSecondary;
              Color borderColor = isDark ? Colors.white12 : Colors.black12;

              if (isSelected) {
                bgColor = AppColors.primary;
                textColor = Colors.white;
                borderColor = AppColors.primary;
              } else if (isAnswered) {
                bgColor = AppColors.primary.withValues(alpha: 0.1);
                textColor = AppColors.primary;
                borderColor = AppColors.primary.withValues(alpha: 0.2);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _currentQuestionIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      q.type == 'passage' ? 'Passage ${index + 1}' : 'Q ${index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isSelected || isAnswered ? FontWeight.bold : FontWeight.w500,
                        color: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Finish Quiz', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to submit your answers now?', style: GoogleFonts.inter(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text('Not Yet', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Submit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
    final timeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    int scorableCount = 0;
    for (var q in _shuffledQuestions) {
      if (q.question.type == 'passage') {
        scorableCount += q.question.nestedQuestions?.length ?? 0;
      } else {
        scorableCount++;
      }
    }
    final double percentage = scorableCount > 0 ? (_lastScore ?? 0) / scorableCount : 1.0;

    
    String feedbackMessage = 'Keep practicing to achieve mastery! ✨';
    if (percentage >= 1.0) {
      feedbackMessage = 'Perfect Score! You are a true Grammatica expert! 🏆';
    } else if (percentage >= 0.9) {
      feedbackMessage = 'Stellar performance! You have mastered this content. 🌟';
    } else if (percentage >= 0.7) {
      feedbackMessage = "Great job! You're very close to mastery. 💪";
    } else if (percentage >= 0.5) {
      feedbackMessage = "Good effort! A bit more review and you'll get there. 📚";
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFEE69F), Color(0xFFFFD54F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events_rounded,
                size: 64,
                color: Color(0xFFF57F17),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Quiz Complete!',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildResultPill(
                label: 'Score',
                value: '${_lastScore ?? 0}/$scorableCount',
                bgColor: const Color(0xFFFFF3E0),
                textColor: const Color(0xFFE65100),
              ),
              const SizedBox(width: 24),
              _buildResultPill(
                label: 'Duration',
                value: timeStr,
                bgColor: AppColors.primary.withValues(alpha: 0.1),
                textColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 48),
          Container(
            width: 500,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              feedbackMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, color: isDark ? Colors.white : Colors.black87, height: 1.5),
            ),
          ),
          if (!_isCorrect && (maxAttempts - _attemptsUsed) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: ElevatedButton.icon(
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
                  if (widget.quiz.duration > 0) _startTimer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultPill({
    required String label,
    required String value,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.8), letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: textColor),
          ),
        ],
      ),
    );
  }
}
