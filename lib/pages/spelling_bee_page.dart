import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../services/web_service.dart';
import '../services/ai_service.dart';
import '../models/spelling_word.dart';
import '../pages/admin/admin_spelling_words_tab.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';


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
  bool _useAiWords = false;

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String?> _userAnswers = [];
  bool _showPreview = false;

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
    List<SpellingWord> allWords;

    if (_useAiWords) {
      try {
        allWords = await AIService.instance.generateWords(
          count: 10,
          difficulty: difficulty,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI generation failed: $e')),
          );
        }
        return;
      }
    } else {
      allWords = await DatabaseService.instance.fetchSpellingWords(
        difficulty: difficulty,
      );
    }

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
      body: _selectedDifficulty == null
          ? Container(
              color: const Color(0xFFFAFAFA),
              child: _buildBody(),
            )
          : BackgroundWrapper(
              imageAssetPath: 'assets/spellingbeebg.png',
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
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFAFA),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : 20,
            vertical: 48,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [


                // Main Centered Header
                Text(
                  'Choose your Difficulty',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 44 : 32,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    height: 1.15,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Select a challenge level below for Spelling Bee. Master spelling audio prompts across various difficulty tiers.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFF64748B),
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // AI Word Source Toggle Container
                Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _useAiWords
                              ? Icons.psychology_rounded
                              : Icons.storage_rounded,
                          color: const Color(0xFF2E5090),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Word Source:',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Database'),
                              icon: Icon(Icons.storage_rounded, size: 15),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('AI Generated'),
                              icon: Icon(Icons.auto_awesome_rounded, size: 15),
                            ),
                          ],
                          selected: {_useAiWords},
                          onSelectionChanged: (val) {
                            setState(() => _useAiWords = val.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 44),

                // Cards Row / Column
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _DifficultyCard(
                                title: 'Novice',
                                subtitle:
                                    '120s timer per word. Ideal for beginners building core spelling vocabulary.',
                                tag: 'BEGINNER',
                                icon: Icons.star_rounded,
                                themeColor: const Color(0xFFF59E0B),
                                rating: 2,
                                onTap: () =>
                                    _startSession(SpellingDifficulty.novice),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _DifficultyCard(
                                title: 'Amateur',
                                subtitle:
                                    '60s timer per word. Balanced challenge for developing spellers.',
                                tag: 'INTERMEDIATE',
                                icon: Icons.show_chart_rounded,
                                themeColor: const Color(0xFF81B655),
                                rating: 3,
                                onTap: () =>
                                    _startSession(SpellingDifficulty.amateur),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _DifficultyCard(
                                title: 'Professional',
                                subtitle:
                                    '30s timer per word. Fast-paced challenge with advanced vocabulary.',
                                tag: 'ADVANCED',
                                icon: Icons.local_fire_department_rounded,
                                themeColor: const Color(0xFFEF4444),
                                rating: 5,
                                onTap: () => _startSession(
                                    SpellingDifficulty.professional),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _DifficultyCard(
                              title: 'Novice',
                              subtitle:
                                  '120s timer per word. Ideal for beginners building core spelling vocabulary.',
                              tag: 'BEGINNER',
                              icon: Icons.star_rounded,
                              themeColor: const Color(0xFFF59E0B),
                              rating: 2,
                              onTap: () =>
                                  _startSession(SpellingDifficulty.novice),
                            ),
                            const SizedBox(height: 20),
                            _DifficultyCard(
                              title: 'Amateur',
                              subtitle:
                                  '60s timer per word. Balanced challenge for developing spellers.',
                              tag: 'INTERMEDIATE',
                              icon: Icons.show_chart_rounded,
                              themeColor: const Color(0xFF81B655),
                              rating: 3,
                              onTap: () =>
                                  _startSession(SpellingDifficulty.amateur),
                            ),
                            const SizedBox(height: 20),
                            _DifficultyCard(
                              title: 'Professional',
                              subtitle:
                                  '30s timer per word. Fast-paced challenge with advanced vocabulary.',
                              tag: 'ADVANCED',
                              icon: Icons.local_fire_department_rounded,
                              themeColor: const Color(0xFFEF4444),
                              rating: 5,
                              onTap: () => _startSession(
                                  SpellingDifficulty.professional),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                    color: Colors.black.withValues(alpha: 0.04),
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
                              color: difficultyColor.withValues(alpha: 0.4),
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
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.8)),
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
              color: AppColors.primary.withValues(alpha: 0.1),
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
                          color: (isCorrect ? AppColors.primary : AppColors.error).withValues(alpha: 0.1),
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
                              userAnswer?.isEmpty ?? true ? "(No input)" : '"$userAnswer"',
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

class _DifficultyCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color themeColor;
  final int rating;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.themeColor,
    required this.rating,
    required this.onTap,
  });

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.025,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _ctrl.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovered
                    ? widget.themeColor.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
                width: _hovered ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? widget.themeColor.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: _hovered ? 30 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Tag Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.tag,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.themeColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Icon Box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? widget.themeColor
                        : widget.themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: _hovered ? Colors.white : widget.themeColor,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle / Description
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // Rating Stars Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final filled = index < widget.rating;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: filled
                              ? widget.themeColor
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: filled ? Colors.white : const Color(0xFF94A3B8),
                          size: 14,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _hovered
                          ? widget.themeColor
                          : widget.themeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hovered
                            ? Colors.transparent
                            : widget.themeColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Start Practice',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _hovered
                                  ? Colors.white
                                  : widget.themeColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: _hovered ? Colors.white : widget.themeColor,
                          ),
                        ],
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
