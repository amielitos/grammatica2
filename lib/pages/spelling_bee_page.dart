import 'dart:math';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Timer fields
  Timer? _timer;
  int _timeLeft = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() => setState(() => _isPlaying = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isPlaying = false));
    _flutterTts.setErrorHandler((msg) => setState(() => _isPlaying = false));
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
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

    setState(() {
      _selectedDifficulty = difficulty;
      _sessionWords = shuffled.take(10).toList();
      _currentIndex = 0;
      _score = 0;
      _isGameOver = false;
      _answerController.clear();
    });

    _speakWord();
    _startTimer();
  }

  Future<void> _speakWord() async {
    if (_sessionWords.isEmpty) return;
    await _flutterTts.speak(_sessionWords[_currentIndex].word);
  }

  void _submitAnswer() {
    final answer = _answerController.text.trim().toLowerCase();
    final correctWord = _sessionWords[_currentIndex].word.toLowerCase();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
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
                  icon: const Icon(CupertinoIcons.settings, size: 32),
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
            const Icon(CupertinoIcons.ant, size: 80, color: Colors.amber),
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
                      CupertinoIcons.timer,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 64,
                icon: Icon(
                  _isPlaying
                      ? CupertinoIcons.pause_circle_fill
                      : CupertinoIcons.play_circle_fill,
                  color: Colors.amber,
                ),
                onPressed: _speakWord,
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 48,
                icon: const Icon(
                  CupertinoIcons.arrow_2_circlepath_circle_fill,
                  color: Colors.blueGrey,
                ),
                onPressed: _speakWord,
              ),
            ],
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
            onPressed: _nextWord,
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.checkmark_seal_fill,
              size: 80,
              color: Colors.green,
            ),
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
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
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
