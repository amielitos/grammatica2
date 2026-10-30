import 'package:confetti/confetti.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_widgets.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
import '../widgets/linked_companion_toolbar.dart';
import 'home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:string_similarity/string_similarity.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/navigation_service.dart';
import '../services/web_service.dart';
import '../services/badge_service.dart';

class _RenderableQuestion {
  final QuizQuestion question;

  _RenderableQuestion({
    required this.question,
  });
}

class QuizDetailPage extends StatefulWidget {
  final User user;
  final Quiz quiz;
  final bool previewMode;
  final bool autoStart;
  final String? notebookId;
  final Lesson? lesson;

  const QuizDetailPage({
    super.key,
    required this.user,
    required this.quiz,
    this.previewMode = false,
    this.autoStart = false,
    this.notebookId,
    this.lesson,
  });

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  int _currentQuestionIndex = 0;
  bool _quizStarted = false;
  List<_RenderableQuestion> _shuffledQuestions = [];
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
  bool _isEducator = false;
  bool _checkingSubscription = true;

  bool get _isEducatorOrPreview =>
      _previewMode ||
      _isEducator ||
      _isAdminOrSuperAdmin ||
      widget.quiz.createdByUid == _effectiveUser.uid ||
      widget.lesson?.createdByUid == _effectiveUser.uid;

  late Stream<Map<String, Map<String, dynamic>>> _quizProgressStream;
  late ConfettiController _confettiController;

  bool _isReviewing = false;

  String _formatTs(dynamic ts) {
    if (ts == null) return 'N/A';
    DateTime d;
    if (ts is Timestamp) {
      d = ts.toDate().toLocal();
    } else if (ts is DateTime) {
      d = ts.toLocal();
    } else {
      return 'N/A';
    }
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final amPm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $hour:$minute $amPm';
  }
  bool get _previewMode => widget.previewMode;
  Map<String, dynamic>? _userData;

  // Speech to Text for pronunciation questions
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isStartingSpeech = false;
  bool _isListening = false;
  int? _listeningQuestionIndex;
  dynamic _webRecognition;
  Timer? _watchdogTimer;
  final Map<int, String> _recognizedTranscripts = {};

  // Prerequisite check state
  bool _prerequisiteMet = true;
  Lesson? _prerequisiteLesson;

  // Controller map for multi-blank fill-in-the-blank questions
  final Map<int, List<TextEditingController>> _blankControllers = {};

  /// Live user object to preserve auth session continuity.
  User get _effectiveUser => AuthService.maybeLiveUser ?? widget.user;

  @override
  void initState() {
    super.initState();
    _fetchUserData();

    _shuffledQuestions = widget.quiz.questions
        .where((q) => q.type != 'passage')
        .map((q) => _RenderableQuestion(question: q))
        .toList();
    _answerCtrls = List.generate(
      _shuffledQuestions.length,
      (_) => TextEditingController(),
    );
    _secondsRemaining = widget.quiz.duration * 60;
    _quizProgressStream = DatabaseService.instance.quizProgressStream(_effectiveUser);
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 2500));
    
    // Load existing attempt progress immediately
    DatabaseService.instance.getQuizProgress(_effectiveUser.uid, widget.quiz.id).then((pData) {
      if (pData != null && mounted) {
        setState(() {
          _attemptsUsed = (pData['attemptsUsed'] as num?)?.toInt() ?? _attemptsUsed;
          _lastScore = (pData['score'] as num?)?.toInt() ?? _lastScore;
          _timeTaken = (pData['timeTaken'] as num?)?.toInt() ?? _timeTaken;
          _isCorrect = pData['isCorrect'] == true;
          if (_attemptsUsed > 0 && !_isReviewing) {
            _quizStarted = false; // Always preserve and display previous attempts
          }
        });
      }
    });

    if (!widget.quiz.isMembersOnly ||
        widget.quiz.createdByUid == _effectiveUser.uid ||
        widget.quiz.isAssessment) {
      _checkingSubscription = false;
    }
    _checkSubscription();

    if (widget.quiz.requiresLessonCompleted && widget.quiz.requiredLessonId != null) {
      _prerequisiteMet = false;
      _checkPrerequisiteLesson();
    }

    final bool shouldBlockForPrereq = widget.quiz.requiresLessonCompleted && !_prerequisiteMet && !_isAdminOrSuperAdmin;
    final bool isCreator = widget.quiz.createdByUid == _effectiveUser.uid || widget.lesson?.createdByUid == _effectiveUser.uid;
    if (!shouldBlockForPrereq && !widget.previewMode && !isCreator && _attemptsUsed == 0 && (widget.autoStart || widget.quiz.isAssessment)) {
      _quizStarted = true;
      _startTime = DateTime.now();
      _completedLocal = false;
      _isReviewing = false;
      if (widget.quiz.duration > 0) {
        _startTimer();
      }
    }
  }

  Future<void> _checkPrerequisiteLesson() async {
    final reqId = widget.quiz.requiredLessonId;
    if (reqId == null) {
      if (mounted) setState(() { _prerequisiteMet = true; });
      return;
    }
    try {
      final role = await RoleService.instance.getRole(_effectiveUser.uid);
      if (role == UserRole.admin || role == UserRole.superadmin || widget.quiz.createdByUid == _effectiveUser.uid) {
        if (mounted) {
          setState(() {
            _prerequisiteMet = true;
          });
        }
        return;
      }
      final progress = await DatabaseService.instance.getLessonProgress(_effectiveUser.uid, reqId);
      final isCompleted = progress != null && (progress['completed'] == true || (progress['progress'] as num? ?? 0) >= 1.0);
      final lesson = await DatabaseService.instance.getLesson(reqId);
      final canViewLesson = lesson != null &&
          !lesson.isArchived &&
          (lesson.validationStatus == 'approved' ||
              lesson.createdByUid == _effectiveUser.uid ||
              role == UserRole.validator);
      if (mounted) {
        setState(() {
          _prerequisiteMet = isCompleted;
          _prerequisiteLesson = canViewLesson ? lesson : null;
        });
      }
    } catch (e) {
      debugPrint('Error checking prerequisite lesson: $e');
    }
  }


  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isListening) {
        debugPrint('[Speech] Watchdog timeout - stopping listening');
        _stopListening();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No speech detected. Tap the mic to try again.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _stopListening() {
    _isStartingSpeech = false;
    _watchdogTimer?.cancel();
    if (kIsWeb && _webRecognition != null) {
      try {
        WebService.instance.stopSpeechRecognition(_webRecognition);
      } catch (_) {}
      _webRecognition = null;
    }
    if (!kIsWeb) {
      try {
        _speech.stop();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isListening = false;
        _listeningQuestionIndex = null;
      });
    }
  }

  Future<void> _initSpeech() async {
    if (_isSpeechInitialized) return;
    try {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) return;
      }
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech Status: $status');
          if (_isStartingSpeech) return;
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              _stopListening();
            }
          }
        },
        onError: (err) {
          debugPrint('Speech Error: ${err.errorMsg}');
          if (_isStartingSpeech) return;
          if (mounted && _isListening) {
            _stopListening();
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  String _normalizePronunciation(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _processSpokenWords(String rawWords, String targetWord, int questionIndex) {
    _answerCtrls[questionIndex].text = _normalizePronunciation(rawWords);
  }

  Future<void> _toggleListening(String targetWord, int questionIndex) async {
    if (_isListening && _listeningQuestionIndex == questionIndex) {
      _stopListening();
      return;
    }

    if (kIsWeb) {
      await _startWebListening(targetWord, questionIndex);
    } else {
      await _startMobileListening(targetWord, questionIndex);
    }
  }

  Future<void> _startWebListening(String targetWord, int questionIndex) async {
    if (!WebService.instance.isSpeechRecognitionSupported()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not supported in this browser. Please use Google Chrome or Microsoft Edge.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (_webRecognition != null) {
      try {
        WebService.instance.stopSpeechRecognition(_webRecognition);
      } catch (_) {}
      _webRecognition = null;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    setState(() {
      _isListening = true;
      _listeningQuestionIndex = questionIndex;
    });

    _resetWatchdog();
    _startWebListeningSession(targetWord, questionIndex);
  }

  void _startWebListeningSession(String targetWord, int questionIndex) {
    if (!mounted || !_isListening || _listeningQuestionIndex != questionIndex) return;

    try {
      final recognition = WebService.instance.createSpeechRecognition();
      if (recognition == null) return;

      _webRecognition = recognition;

      WebService.instance.configureSpeechRecognition(
        recognition: recognition,
        onResult: (transcript, isFinal) {
          debugPrint('[WebSpeech] Recognized: "$transcript", isFinal: $isFinal');
          if (mounted) {
            final cleanText = transcript.trim();
            if (cleanText.isNotEmpty) {
              setState(() {
                _recognizedTranscripts[questionIndex] = cleanText;
                _processSpokenWords(cleanText, targetWord, questionIndex);
              });
            }
            if (isFinal && cleanText.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 1200), () {
                if (mounted && _isListening && _listeningQuestionIndex == questionIndex) {
                  _stopListening();
                }
              });
            }
          }
        },
        onError: (e) {
          debugPrint('[WebSpeech] Error: $e');
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('not-allowed') || errStr.contains('denied') || errStr.contains('permission')) {
            _stopListening();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Microphone access blocked. Please allow microphone in browser address bar permissions.'),
                  duration: Duration(seconds: 4),
                ),
              );
            }
          } else if (errStr.contains('no-speech')) {
            debugPrint('[WebSpeech] no-speech: waiting for user speech...');
          } else if (errStr.contains('audio-capture')) {
            debugPrint('[WebSpeech] audio-capture busy or unavailable');
            _stopListening();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Microphone was busy. Tap the mic to try again.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else if (errStr.contains('network')) {
            debugPrint('[WebSpeech] network note: browser speech service temporarily unavailable');
          } else if (errStr.contains('aborted')) {
            debugPrint('[WebSpeech] aborted');
          } else {
            debugPrint('[WebSpeech] unhandled error: $errStr');
          }
        },
        onEnd: () {
          debugPrint('[WebSpeech] onEnd event');
          if (mounted && _isListening && _listeningQuestionIndex == questionIndex) {
            final heard = _recognizedTranscripts[questionIndex];
            if (heard != null && heard.isNotEmpty) {
              _stopListening();
            } else {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted && _isListening && _listeningQuestionIndex == questionIndex) {
                  _startWebListeningSession(targetWord, questionIndex);
                }
              });
            }
          }
        },
      );

      WebService.instance.startSpeechRecognition(recognition);
    } catch (e) {
      debugPrint('[WebSpeech] Start session error: $e');
    }
  }

  Future<void> _startMobileListening(String targetWord, int questionIndex) async {
    _isStartingSpeech = true;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _isStartingSpeech = false;
      _stopListening();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for pronunciation practice.'),
          ),
        );
      }
      return;
    }

    if (!_isSpeechInitialized) {
      await _initSpeech();
    }

    if (!_isSpeechInitialized && mounted) {
      _isStartingSpeech = false;
      _stopListening();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device.')),
      );
      return;
    }

    try {
      if (_speech.isListening) {
        await _speech.cancel();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      _resetWatchdog();

      bool started = await _speech.listen(
        onResult: (result) {
          debugPrint('[MobileSpeech] Result: "${result.recognizedWords}", isFinal: ${result.finalResult}');
          if (mounted) {
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              setState(() {
                _recognizedTranscripts[questionIndex] = words;
                _processSpokenWords(words, targetWord, questionIndex);
              });
            }
            if (result.finalResult && words.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted && _isListening && _listeningQuestionIndex == questionIndex) {
                  _stopListening();
                }
              });
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 8),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );

      _isStartingSpeech = false;

      if (started) {
        if (mounted) {
          setState(() {
            _isListening = true;
            _listeningQuestionIndex = questionIndex;
          });
        }
      } else {
        debugPrint('[MobileSpeech] First listen call returned false. Retrying once...');
        await _speech.cancel();
        await Future.delayed(const Duration(milliseconds: 250));

        started = await _speech.listen(
          onResult: (result) {
            debugPrint('[MobileSpeech-Retry] Result: "${result.recognizedWords}", isFinal: ${result.finalResult}');
            if (mounted) {
              final words = result.recognizedWords.trim();
              if (words.isNotEmpty) {
                setState(() {
                  _recognizedTranscripts[questionIndex] = words;
                  _processSpokenWords(words, targetWord, questionIndex);
                });
              }
              if (result.finalResult && words.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 700), () {
                  if (mounted && _isListening && _listeningQuestionIndex == questionIndex) {
                    _stopListening();
                  }
                });
              }
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 8),
            partialResults: true,
            cancelOnError: false,
            listenMode: stt.ListenMode.dictation,
          ),
        );

        if (started && mounted) {
          setState(() {
            _isListening = true;
            _listeningQuestionIndex = questionIndex;
          });
        } else {
          debugPrint('[MobileSpeech] Speech recognizer failed to start after retry.');
          _stopListening();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone was busy. Please tap the mic again to speak.')),
            );
          }
        }
      }
    } catch (e) {
      _isStartingSpeech = false;
      debugPrint('[MobileSpeech] Listen error: $e');
      _stopListening();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start speech recognition: $e')),
        );
      }
    }
  }

  void _skipCurrentQuestion(int index) {
    _stopListening();
    final q = _shuffledQuestions[index].question;
    if (q.type == 'fill_in_the_blank') {
      final ctrls = _blankControllers[index];
      if (ctrls != null) {
        for (var c in ctrls) {
          if (c.text.trim().isEmpty) {
            c.text = '[Skipped]';
          }
        }
      }
    }
    _answerCtrls[index].text = '[Skipped]';
    setState(() {
      if (_currentQuestionIndex < _shuffledQuestions.length - 1) {
        _currentQuestionIndex++;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question skipped.'),
        duration: Duration(seconds: 1),
      ),
    );
  }



  Future<void> _fetchUserData() async {
    final data = await DatabaseService.instance.getUserData(_effectiveUser.uid);
    if (!mounted) return;
    setState(() {
      _userData = data;
    });
  }

  Future<void> _checkSubscription() async {
    final role = await RoleService.instance.getRole(_effectiveUser.uid);
    if (!mounted) return;
    final isEducatorRole = role == UserRole.educator ||
        role == UserRole.admin ||
        role == UserRole.superadmin ||
        widget.quiz.createdByUid == _effectiveUser.uid ||
        widget.lesson?.createdByUid == _effectiveUser.uid;

    if (isEducatorRole) {
      setState(() {
        _isEducator = true;
        _isSubscribed = true;
        if (role == UserRole.admin || role == UserRole.superadmin) {
          _isAdminOrSuperAdmin = true;
        }
        _checkingSubscription = false;
      });
      return;
    }

    if (!widget.quiz.isMembersOnly || widget.quiz.createdByUid == _effectiveUser.uid) {
      setState(() => _checkingSubscription = false);
      return;
    }
    final isSub = await DatabaseService.instance.isSubscribed(
      widget.quiz.createdByUid!,
      _effectiveUser.uid,
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
    _watchdogTimer?.cancel();
    _stopListening();
    for (var ctrl in _answerCtrls) {
      ctrl.dispose();
    }
    for (var ctrls in _blankControllers.values) {
      for (var ctrl in ctrls) {
        ctrl.dispose();
      }
    }
    _confettiController.dispose();
    super.dispose();
  }

  bool get _allAnswered => _answerCtrls.every(
        (ctrl) => ctrl.text.trim().isNotEmpty,
      );

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
      scorableCount++;
      final input = _normalize(_answerCtrls[i].text);
      final expected = _normalize(q.answer);

      bool isPass = false;
      if (q.type == 'pronunciation') {
        final reg = RegExp(r'\[([^\]]+)\]');
        final match = reg.firstMatch(q.question);
        final rawTarget = match != null
            ? match.group(1)!.trim()
            : (q.targetWord ?? q.answer);
        final target = _normalizePronunciation(rawTarget);
        final rawHeard = _recognizedTranscripts[i] ?? '';
        final spokenClean = _normalizePronunciation(
          rawHeard.isNotEmpty ? rawHeard : _answerCtrls[i].text,
        );

        isPass = spokenClean.isNotEmpty && spokenClean == target;
      } else if (q.type == 'fill_in_the_blank') {
        final reg = RegExp(r'\[([^\]]+)\]');
        final matches = reg.allMatches(q.question).toList();
        final expectedBlanks = matches.isNotEmpty
            ? matches.map((m) => _normalize(m.group(1)!)).toList()
            : (q.blankAnswers != null && q.blankAnswers!.isNotEmpty
                ? q.blankAnswers!.map((b) => _normalize(b)).toList()
                : q.answer.split(',').map((s) => _normalize(s)).where((s) => s.isNotEmpty).toList());
        final userParts = _answerCtrls[i].text.split(',').map((s) => _normalize(s)).toList();

        if (expectedBlanks.isNotEmpty && userParts.length >= expectedBlanks.length) {
          bool allMatch = true;
          for (int b = 0; b < expectedBlanks.length; b++) {
            if (b >= userParts.length || userParts[b] != expectedBlanks[b]) {
              allMatch = false;
              break;
            }
          }
          isPass = allMatch;
        } else {
          isPass = input == expected;
        }
      } else {
        isPass = input == expected;
      }

      if (isPass) score++;
      userAnswers.add(_answerCtrls[i].text.trim());
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
        user: _effectiveUser,
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

      if (percentage >= 100.0 || (scorableCount > 0 && score == scorableCount)) {
        BadgeService.instance.recordPerfectQuiz(_effectiveUser.uid, context: context);
      }

      DatabaseService.instance.checkAndAwardAchievement(_effectiveUser.uid, 'first_quiz').then((awarded) {
        if (awarded) {
          NotificationService.instance.sendAchievementNotification(
            uid: _effectiveUser.uid,
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
        user: _effectiveUser,
        userData: _userData,
        showBackButton: _previewMode || Navigator.canPop(context),
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: _effectiveUser.uid),
          );
        },
        onLogoTap: () async {
          if (_quizStarted && !_completedLocal && !_previewMode) {
            final shouldPop = await _showExitConfirmation();
            return shouldPop == true;
          }
          return true;
        },
        onProfileTap: () async {
          if (_quizStarted && !_completedLocal && !_previewMode) {
            final shouldPop = await _showExitConfirmation();
            return shouldPop == true;
          }
          return true;
        },
      ),
      drawer: UniversalDrawer(
        user: _effectiveUser,
        userData: _userData ?? {},
        onTap: (i) async {
          if (_quizStarted && !_completedLocal && !_previewMode) {
            final shouldPop = await _showExitConfirmation();
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop(); // Close drawer
              HomePage.navigateToTab(context, i);
            }
          } else {
            Navigator.of(context).pop(); // Close drawer
            HomePage.navigateToTab(context, i);
          }
        },
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : AppColors.backgroundBase,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 900;
            final bool isDark = Theme.of(context).brightness == Brightness.dark;

            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                  Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Back to Lessons',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7)),
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
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(constraints.maxWidth < 600 ? 16 : 24),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
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
                                            return _buildResultsArea(maxAttempts, progress: myProgress);
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
                                if (isWide && !_quizStarted)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 48),
                                    child: SizedBox(
                                      width: 320,
                                      child: LinkedCompanionSidebar(
                                        user: _effectiveUser,
                                        notebookId: widget.notebookId ?? widget.quiz.notebookId,
                                        currentQuiz: widget.quiz,
                                        currentLesson: widget.lesson,
                                        activeType: CompanionMediaType.quiz,
                                      ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final horizontalPad = isNarrow ? 20.0 : 48.0;
        final verticalPad = isNarrow ? 24.0 : 48.0;

        return Column(
          children: [
            if (_previewMode || widget.quiz.validationStatus == 'awaiting_approval')
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8A838).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8A838).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Color(0xFFE8A838)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pending Approval • Submitted: ${_formatTs(widget.quiz.createdAt)}',
                        style: GoogleFonts.inter(color: const Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 13),
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
                    padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
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
                            fontSize: isNarrow ? 28 : 42,
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
                            fontSize: isNarrow ? 15 : 18,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
                    child: Column(
                      children: [
                        if (isNarrow) ...[
                          _statBox(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            iconColor: AppColors.primary,
                            icon: Icons.timer_outlined,
                            label: 'Duration',
                            value: '${widget.quiz.duration.toString().padLeft(2, '0')}:00',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _statBox(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            iconColor: AppColors.primary,
                            icon: Icons.help_outline_rounded,
                            label: 'Questions',
                            value: '${widget.quiz.questions.length}',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _statBox(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            iconColor: AppColors.primary,
                            icon: Icons.refresh_rounded,
                            label: 'Attempts',
                            value: '$_attemptsUsed/$maxAttempts',
                            isDark: isDark,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _statBox(
                                  color: AppColors.primary.withValues(alpha: 0.08),
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
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  iconColor: AppColors.primary,
                                  icon: Icons.help_outline_rounded,
                                  label: 'Questions',
                                  value: '${widget.quiz.questions.length}',
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _statBox(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  iconColor: AppColors.primary,
                                  icon: Icons.refresh_rounded,
                                  label: 'Attempts',
                                  value: '$_attemptsUsed/$maxAttempts',
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 48),
                        if (!_isEducatorOrPreview)
                          (maxAttempts - _attemptsUsed > 0)
                              ? (widget.quiz.requiresLessonCompleted && !_prerequisiteMet && !_isAdminOrSuperAdmin && widget.quiz.createdByUid != _effectiveUser.uid
                                  ? _buildPrerequisiteRequiredMessage(isDark)
                                  : (_isSubscribed || _isAdminOrSuperAdmin || !widget.quiz.isMembersOnly || widget.quiz.createdByUid == _effectiveUser.uid
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
                                      : _buildLockMessage(isDark)))
                              : _buildNoAttemptsMessage(isDark),
                        if (_isEducatorOrPreview)
                          OutlinedButton.icon(
                            onPressed: _startReview,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 64),
                              side: const BorderSide(color: AppColors.primary, width: 2),
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.visibility_rounded),
                            label: Text('View Quiz Questions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
          Text('Enrollment Required', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(height: 8),
          Text('You need an active enrollment to take this quiz.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary)),
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

  Widget _buildPrerequisiteRequiredMessage(bool isDark) {
    final lessonTitle = widget.quiz.requiredLessonTitle ?? _prerequisiteLesson?.title ?? 'the required lesson';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2416) : const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, size: 36, color: Color(0xFFFFB800)),
          ),
          const SizedBox(height: 16),
          Text(
            'Prerequisite Lesson Required',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2A2A2A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You must complete "$lessonTitle" first before taking this quiz.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 20),
          if (_prerequisiteLesson != null)
            ElevatedButton.icon(
              onPressed: () {
                NavigationService.instance.goToLesson(context, _prerequisiteLesson!);
              },
              icon: const Icon(Icons.school_rounded),
              label: const Text('Go to Lesson'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFillInTheBlankBody({
    required QuizQuestion question,
    required int index,
    required bool isDark,
    required Color textColor,
  }) {
    final reg = RegExp(r'\[([^\]]+)\]');
    final matches = reg.allMatches(question.question).toList();
    final List<String> expectedBlanks = matches.isNotEmpty
        ? matches.map((m) => m.group(1)!.trim()).toList()
        : (question.blankAnswers != null && question.blankAnswers!.isNotEmpty
            ? question.blankAnswers!
            : question.answer.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList());

    if (!_blankControllers.containsKey(index)) {
      final existingAnswers = _answerCtrls[index].text.split(',').map((s) => s.trim()).toList();
      _blankControllers[index] = List.generate(
        expectedBlanks.isNotEmpty ? expectedBlanks.length : 1,
        (bIdx) => TextEditingController(
          text: bIdx < existingAnswers.length ? existingAnswers[bIdx] : '',
        ),
      );
    }

    final blankCtrls = _blankControllers[index]!;

    void syncAnswers() {
      _answerCtrls[index].text = blankCtrls.map((c) => c.text.trim()).join(', ');
      setState(() {});
    }

    String displayText = question.question;
    for (int b = 0; b < matches.length; b++) {
      displayText = displayText.replaceFirst(matches[b].group(0)!, '___(${b + 1})___');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Fill in the Blanks (${expectedBlanks.length} blank${expectedBlanks.length > 1 ? 's' : ''})',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                displayText,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  height: 1.8,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your Answers:',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(blankCtrls.length, (bIdx) {
          final expected = bIdx < expectedBlanks.length ? expectedBlanks[bIdx] : '';
          final userText = blankCtrls[bIdx].text.trim();
          final isMatch = userText.toLowerCase() == expected.toLowerCase();

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${bIdx + 1}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: blankCtrls[bIdx],
                    enabled: !_isReviewing,
                    style: GoogleFonts.inter(fontSize: 16, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Enter word for blank #${bIdx + 1}',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF333333) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isReviewing
                              ? (isMatch ? AppColors.primary : AppColors.error)
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _isReviewing
                              ? (isMatch ? AppColors.primary : AppColors.error)
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    onChanged: (_) => syncAnswers(),
                  ),
                ),
                if (_isReviewing) ...[
                  const SizedBox(width: 12),
                  if (isMatch)
                    const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28)
                  else ...[
                    const Icon(Icons.cancel_rounded, color: AppColors.error, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '($expected)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        }),
        if (!_isReviewing) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _skipCurrentQuestion(index),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: Text(
                _answerCtrls[index].text == '[Skipped]' ? 'Question Skipped ✓' : 'Skip this question',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPronunciationBody({
    required QuizQuestion question,
    required int index,
    required bool isDark,
    required Color textColor,
  }) {
    final reg = RegExp(r'\[([^\]]+)\]');
    final match = reg.firstMatch(question.question);
    final String targetWord = match != null
        ? match.group(1)!.trim()
        : (question.targetWord ?? question.answer.trim());

    final String sentenceWithoutWord = match != null
        ? question.question.replaceFirst(match.group(0)!, '____[Say this word]____')
        : question.question;

    final String spoken = _answerCtrls[index].text.trim();
    final String heard = _recognizedTranscripts[index] ?? '';
    final bool isListeningThis = _isListening && _listeningQuestionIndex == index;

    final String targetClean = _normalizePronunciation(targetWord);
    final String spokenClean = _normalizePronunciation(heard.isNotEmpty ? heard : spoken);
    final bool isPassed = spokenClean.isNotEmpty && spokenClean == targetClean;
    final double bestSim = spokenClean.isNotEmpty
        ? (isPassed ? 1.0 : StringSimilarity.compareTwoStrings(spokenClean, targetClean).clamp(0.0, 0.99))
        : 0.0;
    final String targetMatchedWord = spokenClean;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.record_voice_over_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Pronunciation Quiz',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                sentenceWithoutWord,
                style: GoogleFonts.inter(fontSize: 18, height: 1.8, fontWeight: FontWeight.w500, color: textColor),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Word to pronounce: ',
                      style: GoogleFonts.inter(fontSize: 14, color: textColor),
                    ),
                    Text(
                      targetWord,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              if (!_isReviewing) ...[
                GestureDetector(
                  onTap: () => _toggleListening(targetWord, index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isListeningThis ? Colors.red : AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: (isListeningThis ? Colors.red : AppColors.primary).withValues(alpha: 0.35),
                          blurRadius: isListeningThis ? 25 : 12,
                          spreadRadius: isListeningThis ? 6 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isListeningThis ? Icons.stop_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isListeningThis
                      ? 'Listening... Speak the word now (Tap to stop)'
                      : ((heard.isNotEmpty || spoken.isNotEmpty)
                          ? 'Tap the microphone to re-record'
                          : 'Tap the microphone and say the word'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isListeningThis ? Colors.red : Colors.grey.shade600,
                  ),
                ),
                if (isListeningThis && heard.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Hearing: "$heard"',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              if (heard.isNotEmpty || spoken.isNotEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 540),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? Colors.green.withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF1E293B) : Colors.orange.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isPassed ? Colors.green.shade400 : Colors.orange.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPassed ? Icons.check_circle_rounded : Icons.hearing_rounded,
                            color: isPassed ? Colors.green : Colors.orange.shade800,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'What the system heard:',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isPassed ? Colors.green.shade800 : Colors.orange.shade900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPassed
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(bestSim * 100).toInt()}% Match',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.green.shade800 : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          '"${heard.isNotEmpty ? heard : spoken}"',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (targetMatchedWord.isNotEmpty &&
                          targetMatchedWord.toLowerCase() != (heard.isNotEmpty ? heard : spoken).toLowerCase()) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Matched word: ',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              '"$targetMatchedWord"',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.green.shade700 : textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPassed
                                ? 'Excellent! Pronunciation accepted.'
                                : 'Needs practice. Say the exact target word.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPassed ? Colors.green.shade700 : Colors.orange.shade800,
                            ),
                          ),
                          if (!_isReviewing)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _answerCtrls[index].clear();
                                  _recognizedTranscripts.remove(index);
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text('Clear', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade600,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (!_isReviewing) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _skipCurrentQuestion(index),
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(
                    spoken == '[Skipped]' ? 'Question Skipped ✓' : 'Skip this question',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;
        final paddingAmount = constraints.maxWidth < 600 ? 20.0 : 40.0;

        Widget buildQuestionBody() {
          List<String> effectiveOptions = [];
          if (question.options != null && question.options!.isNotEmpty) {
            effectiveOptions = question.options!;
          } else if (question.type != 'fill_in_the_blank' && question.type != 'pronunciation') {
            final ans = question.answer.trim();
            if (ans.toLowerCase() == 'true' || ans.toLowerCase() == 'false') {
              effectiveOptions = const ['True', 'False'];
            } else if (ans.isNotEmpty) {
              effectiveOptions = [
                ans,
                'Option B',
                'Option C',
                'Option D',
              ];
            } else {
              effectiveOptions = const ['Option A', 'Option B', 'Option C', 'Option D'];
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.type != 'fill_in_the_blank' && question.type != 'pronunciation')
                Text(
                  question.question,
                  style: GoogleFonts.outfit(
                    fontSize: isWide ? 26 : 22,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: Image.network(
                        question.imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(color: AppColors.primary),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Image failed to load', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              if (question.type == 'fill_in_the_blank')
                _buildFillInTheBlankBody(
                  question: question,
                  index: _currentQuestionIndex,
                  isDark: isDark,
                  textColor: textColor,
                )
              else if (question.type == 'pronunciation')
                _buildPronunciationBody(
                  question: question,
                  index: _currentQuestionIndex,
                  isDark: isDark,
                  textColor: textColor,
                )
              else
                ...effectiveOptions.map((opt) {
                  final normalizedOpt = opt.trim();
                  final currentVal = _answerCtrls[_currentQuestionIndex].text.trim();
                  final isSelected = currentVal == normalizedOpt;
                  final isCorrectAnswer = normalizedOpt.toLowerCase() == question.answer.trim().toLowerCase();

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
                          : () => setState(() => _answerCtrls[_currentQuestionIndex].text = normalizedOpt),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(20),
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(normalizedOpt, style: GoogleFonts.inter(fontSize: 15, color: textColor, fontWeight: FontWeight.w500)),
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
                }),
                
              if (_isReviewing && (question.hint != null || question.explanation != null))
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
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
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(paddingAmount),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.quiz.duration > 0 && !_isReviewing) _buildTimerBadge(),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  buildQuestionBody(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isReviewing && (question.type == 'pronunciation' || question.type == 'fill_in_the_blank')) ...[
                  OutlinedButton.icon(
                    onPressed: () => _skipCurrentQuestion(_currentQuestionIndex),
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: Text(
                      _answerCtrls[_currentQuestionIndex].text == '[Skipped]'
                          ? 'Question Skipped'
                          : 'Skip Question',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Spacer(),
                ],
                if (_currentQuestionIndex > 0)
                  SizedBox(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _stopListening();
                        setState(() => _currentQuestionIndex--);
                      },
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
                          onPressed: () {
                            _stopListening();
                            setState(() => _currentQuestionIndex++);
                          },
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
                          : ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _quizStarted = false;
                                  _isReviewing = false;
                                  _completedLocal = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                              label: Text('Back to Results', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
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
      },
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
              final isAnswered = _answerCtrls[index].text.trim().isNotEmpty;
              
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
                  onTap: () {
                    _stopListening();
                    setState(() => _currentQuestionIndex = index);
                  },
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
                      'Q ${index + 1}',
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

  Widget _buildResultsArea(int maxAttempts, {Map<String, dynamic>? progress}) {
    final minutes = _timeTaken ~/ 60;
    final seconds = _timeTaken % 60;
    final timeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    final scorableCount = _shuffledQuestions.length;
    final double percentage = scorableCount > 0 ? (_lastScore ?? 0) / scorableCount : 1.0;
    final int percentInt = (percentage * 100).round();
    
    String feedbackMessage = 'Keep practicing to achieve complete mastery.';
    String performanceBadge = 'Completed 📚';
    Color badgeColor = const Color(0xFF3B82F6);
    if (percentage >= 1.0) {
      feedbackMessage = 'Outstanding! Perfect score — you have mastered this material!';
      performanceBadge = 'Perfect Score! 🏆';
      badgeColor = const Color(0xFF10B981);
    } else if (percentage >= 0.8) {
      feedbackMessage = 'Stellar performance! You have a solid grasp of this topic.';
      performanceBadge = 'Great Job! ⭐';
      badgeColor = const Color(0xFF10B981);
    } else if (percentage >= 0.6 || _isCorrect) {
      feedbackMessage = "Good effort! You're making steady progress toward mastery.";
      performanceBadge = 'Passed 👍';
      badgeColor = const Color(0xFFF59E0B);
    } else {
      feedbackMessage = "Review the lesson materials and try again to sharpen your skills.";
      performanceBadge = 'Needs Review 💡';
      badgeColor = const Color(0xFFEF4444);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    // Allow retake whenever more than one attempt is configured or attempts remain
    final canRetake = (maxAttempts <= 0) || (maxAttempts > 1 && _attemptsUsed < maxAttempts) || ((maxAttempts - _attemptsUsed) > 0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                'Quiz Complete!',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Performance Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  performanceBadge,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stat Cards Row
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildModernStatCard(
                    context,
                    isDark: isDark,
                    label: 'SCORE',
                    value: '${_lastScore ?? 0}/$scorableCount',
                    subtext: '$percentInt% Accuracy',
                    icon: Icons.military_tech_rounded,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                  _buildModernStatCard(
                    context,
                    isDark: isDark,
                    label: 'DURATION',
                    value: timeStr,
                    subtext: 'Time elapsed',
                    icon: Icons.timer_outlined,
                    accentColor: const Color(0xFF10B981),
                  ),
                  _buildModernStatCard(
                    context,
                    isDark: isDark,
                    label: 'ATTEMPTS',
                    value: '$_attemptsUsed / $maxAttempts',
                    subtext: (maxAttempts - _attemptsUsed) > 0
                        ? '${maxAttempts - _attemptsUsed} remaining'
                        : 'Final attempt',
                    icon: Icons.replay_rounded,
                    accentColor: const Color(0xFF6366F1),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Feedback Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        feedbackMessage,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(
                        'Back to Lessons',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                  // View Last Attempt / Review button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        List<dynamic>? savedAnswers;
                        if (progress != null && progress['lastAnswers'] is List) {
                          savedAnswers = (progress['lastAnswers'] as List).cast<dynamic>();
                        } else {
                          final pData = await DatabaseService.instance.getQuizProgress(_effectiveUser.uid, widget.quiz.id);
                          if (pData != null && pData['lastAnswers'] is List) {
                            savedAnswers = (pData['lastAnswers'] as List).cast<dynamic>();
                          }
                        }
                        if (savedAnswers != null) {
                          for (int i = 0; i < _answerCtrls.length; i++) {
                            if (i < savedAnswers.length) {
                              _answerCtrls[i].text = savedAnswers[i]?.toString() ?? '';
                            }
                          }
                        }
                        _blankControllers.clear();
                        if (mounted) {
                          setState(() {
                            _quizStarted = true;
                            _isReviewing = true;
                            _completedLocal = false;
                            _currentQuestionIndex = 0;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: Text(
                        'View Last Attempt',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  if (canRetake)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _quizStarted = true;
                            _completedLocal = false;
                            _isReviewing = false;
                            _currentQuestionIndex = 0;
                            for (var ctrl in _answerCtrls) {
                              ctrl.clear();
                            }
                            _blankControllers.clear();
                            _recognizedTranscripts.clear();
                            _secondsRemaining = widget.quiz.duration * 60;
                            _startTime = DateTime.now();
                          });
                          if (widget.quiz.duration > 0) _startTimer();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Retake Quiz',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: Text(
                          'Continue Learning',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
    BuildContext context, {
    required bool isDark,
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.3 : 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
