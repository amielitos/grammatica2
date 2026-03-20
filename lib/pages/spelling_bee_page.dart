import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../services/web_service.dart';
import '../models/spelling_word.dart';
import '../pages/admin/admin_spelling_words_tab.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../main.dart';

class SpellingBeePage extends StatefulWidget {
  final User user;
  final VoidCallback onBack;
  const SpellingBeePage({super.key, required this.user, required this.onBack});

  @override
  State<SpellingBeePage> createState() => _SpellingBeePageState();
}

class _SpellingBeePageState extends State<SpellingBeePage> {
  SpellingDifficulty? _selectedDifficulty;
  List<SpellingWord> _sessionWords = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isPlaying = false;
  bool _isGameOver = false;

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String?> _userAnswers = [];
  bool _showPreview = false;

  Timer? _timer;
  int _timeLeft = 0;
  int _totalTime = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      _flutterTts.setStartHandler(() => setState(() => _isPlaying = true));
      _flutterTts.setCompletionHandler(() => setState(() => _isPlaying = false));
      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        setState(() => _isPlaying = false);
      });

      if (kIsWeb) {
        debugPrint("Initializing TTS on Web");
      }

      await Future.delayed(const Duration(milliseconds: 500));

      try {
        await _flutterTts.setLanguage("en-US");
        await _flutterTts.setSpeechRate(0.4);
        await _flutterTts.setVolume(1.0);
      } catch (e) {
        debugPrint("TTS Configuration Error: $e");
      }
    } catch (e) {
      debugPrint("Robust TTS Init Catch: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _answerController.dispose();
    _focusNode.dispose();
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
        setState(() {
          _timeLeft--;
        });
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
    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No words found. Admin must add some!')),
        );
      }
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
      _answerController.clear();
      _userAnswers = [];
      _showPreview = false;
    });

    await _speakWord();
    _startTimer();
  }

  Future<void> _speakWord() async {
    if (_sessionWords.isEmpty) return;
    final currentWordObj = _sessionWords[_currentIndex];
    final word = currentWordObj.word;

    await _audioPlayer.stop();
    await _flutterTts.stop();

    if (currentWordObj.audioUrl != null && currentWordObj.audioUrl!.isNotEmpty) {
      try {
        setState(() => _isPlaying = true);
        await _audioPlayer.play(UrlSource(currentWordObj.audioUrl!));
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
        return;
      } catch (e) {
        debugPrint("Error playing recorded audio: $e");
        if (mounted) setState(() => _isPlaying = false);
      }
    }

    bool pluginSuccess = false;
    try {
      await _flutterTts.speak(word);
      pluginSuccess = true;
    } catch (e) {
      debugPrint("TTS Plugin Error: $e");
    }

    if (!pluginSuccess && kIsWeb) {
      WebService.instance.speak(word);
      setState(() => _isPlaying = true);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  void _submitAnswer() {
    final rawAnswer = _answerController.text.trim();
    final answer = rawAnswer.toLowerCase();
    final correctWord = _sessionWords[_currentIndex].word.toLowerCase();

    _userAnswers.add(rawAnswer);

    if (answer == correctWord) {
      _score++;
    }
    _nextWord();
  }

  void _nextWord() {
    if (_currentIndex < _sessionWords.length - 1) {
      setState(() {
        _currentIndex++;
        _answerController.clear();
      });
      _speakWord();
      _startTimer();
      _focusNode.requestFocus();
    } else {
      _timer?.cancel();
      setState(() {
        _isGameOver = true;
      });

      DatabaseService.instance
          .checkAndAwardAchievement(widget.user.uid, 'first_spelling_bee')
          .then((awarded) {
        if (awarded) {
          NotificationService.instance.sendAchievementNotification(
            uid: widget.user.uid,
            title: 'Spelling Bee Master!',
            message: 'Congratulations on completing your first Spelling Bee session!',
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
          'Spelling Bee',
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
              Icons.spellcheck_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "The Great Spelling Bee",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Test your spelling skills and vocabulary\nwith our word-to-audio challenge.",
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
            subtitle: '120 seconds • Simple words',
            color: AppColors.primary,
            icon: Icons.school_rounded,
            onTap: () => _startSession(SpellingDifficulty.novice),
          ),
          const SizedBox(height: 20),
          _DifficultyCard(
            title: 'Amateur',
            subtitle: '60 seconds • Intermediate vocabulary',
            color: AppColors.secondary,
            icon: Icons.auto_graph_rounded,
            onTap: () => _startSession(SpellingDifficulty.amateur),
          ),
          const SizedBox(height: 20),
          _DifficultyCard(
            title: 'Professional',
            subtitle: '30 seconds • Challenging words',
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
          // Audio Hub
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _speakWord,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _isPlaying ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 4),
                        boxShadow: [
                          if (_isPlaying)
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                        size: 64,
                        color: _isPlaying ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Listen Carefully",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Input
          TextField(
            controller: _answerController,
            focusNode: _focusNode,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: 'Spell the word',
              hintStyle: TextStyle(fontSize: 24, color: AppColors.textSecondary.withOpacity(0.5)),
            ),
            onSubmitted: (_) => _submitAnswer(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _submitAnswer,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 64),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded),
                const SizedBox(width: 12),
                Text('SUBMIT ANSWER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
            child: const Icon(Icons.stars_rounded, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          const Text(
            'Amazing Achievement!',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'You completed the Spelling Bee!',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Text(
                    'Precision Score',
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
            child: Text(_showPreview ? 'Hide Details' : 'Review Your Answers'),
          ),
          if (_showPreview) ...[
            const SizedBox(height: 32),
            ...List.generate(_sessionWords.length, (index) {
              final wordObj = _sessionWords[index];
              final userAnswer = _userAnswers[index];
              final isCorrect = userAnswer?.trim().toLowerCase() == wordObj.word.toLowerCase();

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
                              style: TextStyle(color: isCorrect ? AppColors.primary : AppColors.error, fontSize: 13),
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
