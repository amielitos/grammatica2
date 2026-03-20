import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:string_similarity/string_similarity.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../services/vosk_service.dart';
import '../services/web_service.dart';
import '../models/spelling_word.dart';
import '../widgets/design_ornaments.dart';
import '../pages/admin/admin_spelling_words_tab.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class PronunciationQuizPage extends StatefulWidget {
  final User user;
  final VoidCallback onBack;
  const PronunciationQuizPage({
    super.key,
    required this.user,
    required this.onBack,
  });

  @override
  State<PronunciationQuizPage> createState() => _PronunciationQuizPageState();
}

class _PronunciationQuizPageState extends State<PronunciationQuizPage> {
  SpellingDifficulty? _selectedDifficulty;
  List<SpellingWord> _sessionWords = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isGameOver = false;
  bool _isRecording = false;
  String _recognizedText = "";

  // Web Speech Specifics
  dynamic _webSpeech;

  // Mic volume metering
  double _micVolume = 0.0;
  Timer? _volumeTimer;

  // List to track user answers for the preview pane
  List<String?> _userAnswers = [];
  bool _showPreview = false;

  // Timer fields
  Timer? _timer;
  int _timeLeft = 0;
  int _totalTime = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initVosk();
    } else {
      _initWebSpeech();
    }
  }

  Future<void> _initVosk() async {
    try {
      await VoskService.init();
      debugPrint("Vosk initialized (via service)");
    } catch (e) {
      debugPrint("Vosk Init Error: $e");
    }
  }

  void _initWebSpeech() {
    try {
      _webSpeech = WebService.instance.createSpeechRecognition();
      if (_webSpeech != null) {
        WebService.instance.configureSpeechRecognition(
          recognition: _webSpeech,
          onResult: (transcript, isFinal) {
            if (mounted) {
              setState(() {
                _recognizedText = transcript;
              });
            }
            if (isFinal) {
              _stopRecording();
            }
          },
          onError: (error) {
            debugPrint("Web Speech Error: $error");
            _stopRecording();
          },
          onEnd: () {
            if (_isRecording) {
              _stopRecording();
            }
          },
        );
      }
    } catch (e) {
      debugPrint("Web Speech Init Error: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _volumeTimer?.cancel();
    WebService.instance.stopMicMonitor();
    VoskService.stop();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_selectedDifficulty == null) return;

    switch (_selectedDifficulty!) {
      case SpellingDifficulty.novice:
        _timeLeft = 120;
        break;
      case SpellingDifficulty.amateur:
        _timeLeft = 60;
        break;
      case SpellingDifficulty.professional:
        _timeLeft = 30;
        break;
    }
    _totalTime = _timeLeft;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) {
          setState(() {
            _timeLeft--;
          });
        }
      } else {
        _timer?.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    _userAnswers.add(null);
    _nextWord();
  }

  Future<void> _startSession(SpellingDifficulty difficulty) async {
    final allWords = await DatabaseService.instance.fetchSpellingWords(
      difficulty: difficulty,
    );
    if (!mounted) return;
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words found. Admin must add some!')),
      );
      return;
    }

    final random = Random();
    final List<SpellingWord> shuffled = List.from(allWords)..shuffle(random);

    setState(() {
      _selectedDifficulty = difficulty;
      _sessionWords = shuffled.take(10).toList();
      _currentIndex = 0;
      _score = 0;
      _isGameOver = false;
      _recognizedText = "";
      _userAnswers = [];
      _showPreview = false;
    });

    _startTimer();
  }

  Future<void> _startRecording() async {
    if (mounted) {
      setState(() {
        _isRecording = true;
        _recognizedText = "Listening...";
        _micVolume = 0.0;
      });
    }

    if (kIsWeb) {
      // Start mic monitor (enables both volume meter AND ear-monitoring)
      await WebService.instance.startMicMonitor(enableMonitoring: true);
      // Poll volume 20×/second
      _volumeTimer?.cancel();
      _volumeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        final vol = WebService.instance.getMicVolume();
        if (mounted) setState(() => _micVolume = vol);
      });
      WebService.instance.startSpeechRecognition(_webSpeech);
    } else {
      // Native Vosk Logic placeholder
      debugPrint("Native recording started (via placeholder)");
      Future.delayed(const Duration(seconds: 3), () {
        if (_isRecording && mounted) {
          setState(() {
            _recognizedText = _sessionWords[_currentIndex].word;
          });
          _stopRecording();
          _submitAnswer();
        }
      });
    }
  }

  void _stopRecording() {
    _volumeTimer?.cancel();
    _volumeTimer = null;
    if (kIsWeb) {
      WebService.instance.stopMicMonitor();
      WebService.instance.stopSpeechRecognition(_webSpeech);
    } else {
      // Native Vosk Stop logic
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _micVolume = 0.0;
      });
    }
  }

  void _resetRecording() {
    if (mounted) {
      setState(() {
        _recognizedText = "";
      });
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _submitAnswer() {
    final answer = _recognizedText.trim().toLowerCase();
    final correctWord = _sessionWords[_currentIndex].word.toLowerCase();

    _userAnswers.add(_recognizedText);

    // Fuzzy Matching
    double similarity = StringSimilarity.compareTwoStrings(answer, correctWord);

    if (similarity >= 0.8) {
      _score++;
    }

    if (mounted) _nextWord();
  }

  void _nextWord() {
    if (_currentIndex < _sessionWords.length - 1) {
      setState(() {
        _currentIndex++;
        _recognizedText = "";
      });
      _startTimer();
    } else {
      _timer?.cancel();
      setState(() {
        _isGameOver = true;
      });

      DatabaseService.instance
          .checkAndAwardAchievement(widget.user.uid, 'first_pronunciation')
          .then((awarded) {
        if (awarded) {
          NotificationService.instance.sendAchievementNotification(
            uid: widget.user.uid,
            title: 'Pronunciation Pro!',
            message: 'Congratulations on completing your first Pronunciation Quiz session!',
          );
        }
      });
    }
  }

  void _skipWord() {
    _userAnswers.add("");
    _nextWord();
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
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Pronunciation Quiz',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<UserRole>(
            stream: RoleService.instance.roleStream(widget.user.uid),
            builder: (context, snapshot) {
              if (snapshot.data == UserRole.admin || snapshot.data == UserRole.superadmin) {
                return IconButton(
                  icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminSpellingWordsTab(),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BackgroundWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedDifficulty == null) return _buildDifficultySelection();
    if (_isGameOver) return _buildGameOver();
    return _buildGameSession();
  }

  Widget _buildDifficultySelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.record_voice_over_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Master Your Pronunciation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Improve your accent and clarity\nwith AI-powered speech recognition.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          _DifficultyCard(
            title: 'Novice',
            subtitle: '120 seconds per word • Common words',
            color: AppColors.primary,
            icon: Icons.school_rounded,
            onTap: () => _startSession(SpellingDifficulty.novice),
          ),
          const SizedBox(height: 20),
          _DifficultyCard(
            title: 'Amateur',
            subtitle: '60 seconds per word • Intermediate words',
            color: AppColors.secondary,
            icon: Icons.auto_graph_rounded,
            onTap: () => _startSession(SpellingDifficulty.amateur),
          ),
          const SizedBox(height: 20),
          _DifficultyCard(
            title: 'Professional',
            subtitle: '30 seconds per word • Complex vocabulary',
            color: AppColors.premium,
            icon: Icons.workspace_premium_rounded,
            onTap: () => _startSession(SpellingDifficulty.professional),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSession() {
    final minutes = (_timeLeft / 60).floor();
    final seconds = (_timeLeft % 60).toString().padLeft(2, '0');
    final progress = _timeLeft / _totalTime;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
      child: Column(
        children: [
          // Info & Timer Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Word ${_currentIndex + 1} of ${_sessionWords.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _timeLeft < 10 ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              size: 16,
                              color: _timeLeft < 10 ? AppColors.error : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$minutes:$seconds',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _timeLeft < 10 ? AppColors.error : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeLeft < 10 ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Word Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Center(
                child: Text(
                  _sessionWords[_currentIndex].word,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Recognized Text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text(
                  _recognizedText.isEmpty ? "Ready when you are!" : _recognizedText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isRecording ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                if (_isRecording) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Listening carefully...",
                    style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Volume Meter
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      const Text(
                        'Mic Level',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '${(_micVolume * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 50),
                      height: 14,
                      child: LinearProgressIndicator(
                        value: _micVolume.clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: AppColors.error.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _micVolume > 0.7
                              ? Colors.orange
                              : _micVolume > 0.4
                                  ? AppColors.primary
                                  : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '🎧 You can hear yourself through your speakers',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.refresh_rounded,
                label: "Reset",
                onTap: _resetRecording,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 32),
              Column(
                children: [
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.error : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? AppColors.error : AppColors.primary).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording ? "Stop" : "Hold to Talk",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              _ControlButton(
                icon: Icons.check_circle_rounded,
                label: "Submit",
                onTap: _recognizedText.isNotEmpty ? _submitAnswer : null,
                color: _recognizedText.isNotEmpty ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _skipWord,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Skip Word'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
              const SizedBox(width: 24),
              TextButton.icon(
                onPressed: () {
                  _timer?.cancel();
                  setState(() => _selectedDifficulty = null);
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('End Session'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration_rounded, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          const Text(
            'Brilliant Work!',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'Session completed with excellence.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Text(
                    'Final Score',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_score',
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Text(
                        '/${_sessionWords.length}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => setState(() => _selectedDifficulty = null),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 56),
            ),
            child: const Text('Back to Menu'),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            child: Text(_showPreview ? 'Hide Details' : 'Review Progress'),
          ),
          if (_showPreview) ...[
            const SizedBox(height: 32),
            ...List.generate(_sessionWords.length, (index) {
              final wordObj = _sessionWords[index];
              final userAnswer = _userAnswers[index];
              double similarity = 0;
              if (userAnswer != null) {
                similarity = StringSimilarity.compareTwoStrings(
                  userAnswer.trim().toLowerCase(),
                  wordObj.word.toLowerCase(),
                );
              }
              final isCorrect = similarity >= 0.8;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isCorrect ? AppColors.primary : AppColors.error).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCorrect ? Icons.check_rounded : Icons.close_rounded,
                          color: isCorrect ? AppColors.primary : AppColors.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wordObj.word,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userAnswer?.isEmpty ?? true ? "(No input)" : '"${userAnswer}"',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.divider, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          color: color,
          iconSize: 32,
        ),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
