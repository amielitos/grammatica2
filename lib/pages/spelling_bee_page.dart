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
        leadingWidth: 240,
        leading: Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: TextButton.icon(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            label: Text(
              _selectedDifficulty == null ? 'Back to Practice Tools' : 'Back to Spelling Bee',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              alignment: Alignment.centerLeft,
            ),
            onPressed: () {
              if (_selectedDifficulty == null) {
                widget.onBack();
              } else {
                _timer?.cancel();
                setState(() => _selectedDifficulty = null);
              }
            },
          ),
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
        imageAssetPath: _selectedDifficulty == null 
            ? 'assets/practicebg.png' 
            : 'assets/spellingbeebg.png',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
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
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'Choose your Difficulty',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Select a level for Spelling Bee',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Row(
              children: [
                Expanded(
                  child: _DifficultyCard(
                    title: 'Novice',
                    color: const Color(0xFFFCE267),
                    icon: Icons.star_rounded,
                    rating: 2,
                    onTap: () => _startSession(SpellingDifficulty.novice),
                  ),
                ),
                SizedBox(width: 32),
                Expanded(
                  child: _DifficultyCard(
                    title: 'Amateur',
                    color: const Color(0xFFA1CC73),
                    icon: Icons.show_chart_rounded,
                    rating: 3,
                    onTap: () => _startSession(SpellingDifficulty.amateur),
                  ),
                ),
                SizedBox(width: 32),
                Expanded(
                  child: _DifficultyCard(
                    title: 'Professional',
                    color: const Color(0xFFE6625B),
                    icon: Icons.local_fire_department_rounded,
                    rating: 4,
                    onTap: () => _startSession(SpellingDifficulty.professional),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String value) {
    return Container(
      width: 220,
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildGameSession() {
    final minutes = (_timeLeft / 60).floor().toString().padLeft(2, '0');
    final seconds = (_timeLeft % 60).toString().padLeft(2, '0');
    
    String difficultyText = "";
    Color difficultyColor = Colors.black;
    switch (_selectedDifficulty) {
      case SpellingDifficulty.novice:
        difficultyText = "Novice";
        difficultyColor = const Color(0xFFFCE267);
        break;
      case SpellingDifficulty.amateur:
        difficultyText = "Amateur";
        difficultyColor = const Color(0xFFA1CC73);
        break;
      case SpellingDifficulty.professional:
        difficultyText = "Professional";
        difficultyColor = const Color(0xFFE6625B);
        break;
      default:
        break;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 60, 24, 40),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
              children: [
                TextSpan(text: 'Spelling Bee - '),
                TextSpan(text: difficultyText, style: TextStyle(color: difficultyColor)),
              ],
            ),
          ),
          SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildStatBox('Progress:', 'Word ${_currentIndex + 1} of 10'),
              _buildStatBox('Current Score:', '$_score/10'),
              _buildStatBox('Time:', '$minutes:$seconds'),
            ],
          ),
          SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _speakWord,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: difficultyColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_isPlaying)
                            BoxShadow(
                              color: difficultyColor.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 48),
                  Text(
                    "Listen carefully and spell the word",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: _answerController,
                    focusNode: _focusNode,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Type your answer here...',
                      hintStyle: TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic),
                      contentPadding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.8)),
                      ),
                    ),
                    onSubmitted: (_) => _submitAnswer(),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submitAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655), // Match the solid green mockup button
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Submit Answer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  TextButton(
                    onPressed: _skipWord,
                    child: Text('Skip this word', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      setState(() => _selectedDifficulty = null);
                    },
                    child: Text(
                      'Cancel Spelling Bee',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFE56B6B),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFE56B6B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
  final Color color;
  final IconData icon;
  final int rating;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 480, // Taller card to match vertical orientation
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(height: 12),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: Colors.white, size: 40),
                ),
                SizedBox(height: 32),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Difficulty:',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: index < rating ? const Color(0xFFF6A119) : (isDark ? Colors.grey[600] : Colors.grey[400]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
