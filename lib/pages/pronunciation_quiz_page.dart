import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../services/web_service.dart';
import 'package:string_similarity/string_similarity.dart';
import '../services/vosk_service.dart';
import '../models/spelling_word.dart'; // Reusing SpellingWord model
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/role_service.dart';
import '../widgets/glass_card.dart';
import 'admin/admin_spelling_words_tab.dart';

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

  // Audio removed for Pronunciation Quiz

  // Web Speech Specifics
  dynamic _webSpeech;

  // List to track user answers for the preview pane
  List<String?> _userAnswers = [];
  bool _showPreview = false;

  // Timer fields
  Timer? _timer;
  int _timeLeft = 0;

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

    // await _speakWord(); // Removed
    _startTimer();
  }

  Future<void> _startRecording() async {
    if (mounted) {
      setState(() {
        _isRecording = true;
        _recognizedText = "Listening...";
      });
    }

    if (kIsWeb) {
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
    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }
    if (kIsWeb) {
      WebService.instance.stopSpeechRecognition(_webSpeech);
    } else {
      // Native Vosk Stop logic
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

      // Trigger Achievement Notification for first pronunciation
      DatabaseService.instance
          .checkAndAwardAchievement(widget.user.uid, 'first_pronunciation')
          .then((awarded) {
            if (awarded) {
              NotificationService.instance.sendAchievementNotification(
                uid: widget.user.uid,
                title: 'Pronunciation Pro!',
                message:
                    'Congratulations on completing your first Pronunciation Quiz session!',
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Pronunciation Quiz'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<UserRole>(
            stream: RoleService.instance.roleStream(widget.user.uid),
            builder: (context, snapshot) {
              if (snapshot.data == UserRole.admin ||
                  snapshot.data == UserRole.superadmin) {
                return IconButton(
                  icon: const Icon(Icons.settings, size: 32),
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
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width * 0.6
              : MediaQuery.of(context).size.width * 0.9,
          child: _buildBody(),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.record_voice_over, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'Select Difficulty',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            _DifficultyCard(
              title: 'Novice',
              color: Colors.green,
              onTap: () => _startSession(SpellingDifficulty.novice),
            ),
            const SizedBox(height: 16),
            _DifficultyCard(
              title: 'Amateur',
              color: Colors.orange,
              onTap: () => _startSession(SpellingDifficulty.amateur),
            ),
            const SizedBox(height: 16),
            _DifficultyCard(
              title: 'Professional',
              color: Colors.red,
              onTap: () => _startSession(SpellingDifficulty.professional),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameSession() {
    final minutes = (_timeLeft / 60).floor();
    final seconds = (_timeLeft % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              Text(
                'Word ${_currentIndex + 1} / ${_sessionWords.length}',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _timeLeft < 10
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _timeLeft < 10 ? Colors.red : Colors.blue,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer,
                      size: 18,
                      color: _timeLeft < 10 ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$minutes:$seconds',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _timeLeft < 10 ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          GlassCard(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.1),
                    Colors.purple.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _sessionWords[_currentIndex].word,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Text(
              _recognizedText.isEmpty
                  ? "Press the mic and say the word"
                  : _recognizedText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isRecording ? Colors.red : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _resetRecording,
                    icon: const Icon(Icons.refresh),
                    color: Colors.grey,
                    iconSize: 32,
                    tooltip: "Reset Text",
                  ),
                  const Text(
                    "Reset",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _isRecording ? Colors.red : Colors.blue,
                    child: IconButton(
                      onPressed: _toggleRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording ? "Listening..." : "Tap to Speak",
                    style: TextStyle(
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _recognizedText.isNotEmpty
                        ? _submitAnswer
                        : null,
                    icon: const Icon(Icons.check_circle),
                    color: _recognizedText.isNotEmpty
                        ? Colors.green
                        : Colors.grey,
                    iconSize: 40,
                    tooltip: "Submit Answer",
                  ),
                  const Text(
                    "Submit",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _skipWord,
            child: const Text(
              'Skip this word',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              setState(() => _selectedDifficulty = null);
            },
            child: const Text(
              'Cancel Quiz',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Session Complete!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Score: $_score / ${_sessionWords.length}',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showPreview = !_showPreview),
              icon: Icon(_showPreview ? Icons.expand_less : Icons.expand_more),
              label: Text(_showPreview ? 'Hide Preview' : 'Show Preview'),
            ),
            if (_showPreview) ...[
              const SizedBox(height: 24),
              ...List.generate(_sessionWords.length, (index) {
                final wordObj = _sessionWords[index];
                final userAnswer = _userAnswers[index];
                double? similarity;
                if (userAnswer != null) {
                  similarity = StringSimilarity.compareTwoStrings(
                    userAnswer.trim().toLowerCase(),
                    wordObj.word.toLowerCase(),
                  );
                }
                final isCorrect = similarity != null && similarity >= 0.8;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correct: ${wordObj.word}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Your Pronunciation: ${userAnswer ?? "(No audio)"}',
                              style: TextStyle(
                                color: isCorrect ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isCorrect ? Icons.check : Icons.close,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => setState(() => _selectedDifficulty = null),
              child: const Text('Back to Menu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(15),
          color: color.withValues(alpha: 0.1),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
