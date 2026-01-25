import 'dart:math';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // For kIsWeb
import 'dart:js_interop'; // For JS interop
import 'package:web/web.dart' as web; // For native web APIs
import 'package:audioplayers/audioplayers.dart';
import '../models/spelling_word.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../widgets/glass_card.dart';
import 'admin/admin_spelling_words_tab.dart';

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

  // List to track user answers for the preview pane
  List<String?> _userAnswers = [];
  bool _showPreview = false;

  // Timer fields
  Timer? _timer;
  int _timeLeft = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      _flutterTts.setStartHandler(() => setState(() => _isPlaying = true));
      _flutterTts.setCompletionHandler(
        () => setState(() => _isPlaying = false),
      );
      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        setState(() => _isPlaying = false);
      });

      // Avoid plugin initialization crash on Web if implementation is missing
      if (kIsWeb) {
        debugPrint("Initializing TTS on Web - check for plugin availability");
      }

      // Small delay to ensure voices are available on some browsers
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        await _flutterTts.setLanguage("en-US");
        await _flutterTts.setSpeechRate(0.4);
        await _flutterTts.setVolume(1.0);
      } catch (e) {
        debugPrint("TTS Configuration Error (likely MissingPlugin on Web): $e");
      }
    } catch (e) {
      debugPrint("Robust TTS Init Catch: $e");
      // On Web, MissingPluginException is common if registration fails.
      // We don't rethrow here so the app remains functional with manual fallback.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _flutterTts.stop();
    } catch (e) {
      debugPrint("Error stopping TTS in dispose: $e");
    }
    try {
      _audioPlayer.dispose();
    } catch (e) {
      debugPrint("Error disposing audio player: $e");
    }
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_selectedDifficulty == null) return;

    switch (_selectedDifficulty!) {
      case SpellingDifficulty.novice:
        _timeLeft = 120; // 2 minutes
        break;
      case SpellingDifficulty.amateur:
        _timeLeft = 60; // 1 minute
        break;
      case SpellingDifficulty.professional:
        _timeLeft = 30; // 30 seconds
        break;
    }

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
    _userAnswers.add(null); // Record null for timeout
    _nextWord();
  }

  Future<void> _startSession(SpellingDifficulty difficulty) async {
    final allWords = await DatabaseService.instance.fetchSpellingWords(
      difficulty: difficulty,
    );
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words found. Admin must add some!')),
      );
      return;
    }

    final random = Random();
    final List<SpellingWord> shuffled = List.from(allWords)..shuffle(random);

    try {
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
    } catch (e) {
      debugPrint("Error starting session: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start session: $e')));
      }
    }
  }

  Future<void> _speakWord() async {
    if (_sessionWords.isEmpty) return;
    final currentWordObj = _sessionWords[_currentIndex];
    final word = currentWordObj.word;

    // Stop ongoing audio/TTS
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("Error stopping audio player: $e");
    }
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error stopping TTS: $e");
    }

    // Prioritize recorded audio
    if (currentWordObj.audioUrl != null &&
        currentWordObj.audioUrl!.isNotEmpty) {
      try {
        setState(() => _isPlaying = true);
        await _audioPlayer.play(UrlSource(currentWordObj.audioUrl!));
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
        return;
      } catch (e) {
        debugPrint("Error playing recorded audio: $e");
        // Fallback to TTS if audio play fails
        if (mounted) setState(() => _isPlaying = false);
      }
    }

    bool pluginSuccess = false;
    try {
      await _flutterTts.speak(word);
      pluginSuccess = true;
    } catch (e) {
      debugPrint("TTS Plugin Error (Speak): $e");
    }

    // Fallback to native Web Speech API if plugin fails on Web
    if (!pluginSuccess && kIsWeb) {
      try {
        final utterance = web.SpeechSynthesisUtterance(word);
        utterance.lang = 'en-US';
        utterance.rate = 0.8;
        web.window.speechSynthesis.speak(utterance);

        // Manual state update since we bypass plugin handlers
        setState(() => _isPlaying = true);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isPlaying = false);
        });
      } catch (e) {
        debugPrint("Native Web Speech Fallback Error: $e");
      }
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
    }
  }

  void _skipWord() {
    _userAnswers.add(""); // Record empty string for skipped word
    _nextWord();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Material fallback
          onPressed: widget.onBack,
        ),
        title: const Text('Spelling Bee'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<UserRole>(
            stream: RoleService.instance.roleStream(widget.user.uid),
            builder: (context, snapshot) {
              if (snapshot.data == UserRole.admin ||
                  snapshot.data == UserRole.superadmin) {
                return IconButton(
                  icon: const Icon(
                    Icons.settings,
                    size: 32,
                  ), // Material fallback
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
          width: MediaQuery.of(context).size.width * 0.6,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedDifficulty == null) {
      return _buildDifficultySelection();
    }
    if (_isGameOver) {
      return _buildGameOver();
    }
    return _buildGameSession();
  }

  Widget _buildDifficultySelection() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.bug_report,
              size: 80,
              color: Colors.amber,
            ), // Material fallback for ant
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _timeLeft < 10 ? Colors.red : Colors.blue,
                  ),
                ),
                child: Row(
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
          IconButton(
            iconSize: 80,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.amber,
            ),
            onPressed: _speakWord,
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _answerController,
            focusNode: _focusNode,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Type the word here',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onSubmitted: (_) => _submitAnswer(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: Colors.amber.shade700,
            ),
            onPressed: _submitAnswer,
            child: const Text(
              'SUBMIT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            if (_showPreview) ...[
              const SizedBox(height: 24),
              ...List.generate(_sessionWords.length, (index) {
                final wordObj = _sessionWords[index];
                final userAnswer = _userAnswers[index];
                final isCorrect =
                    userAnswer != null &&
                    userAnswer.trim().toLowerCase() ==
                        wordObj.word.toLowerCase();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
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
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Answer: ${userAnswer == null
                                  ? "(Timeout)"
                                  : userAnswer.isEmpty
                                  ? "(Skipped)"
                                  : userAnswer}',
                              style: TextStyle(
                                color: isCorrect ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
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
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _selectedDifficulty = null),
              child: const Text(
                'Back to Menu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(15),
          color: color.withOpacity(0.1),
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
