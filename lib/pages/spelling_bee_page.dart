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
import '../models/spelling_word.dart';
import '../pages/admin/admin_spelling_words_tab.dart';
import '../theme/app_colors.dart';
import '../services/ai_logic_service.dart';
import '../services/ai_rate_limit_service.dart';
import '../widgets/ai_quota_badge.dart';
import '../widgets/ai_quota_exceeded_dialog.dart';
import '../widgets/generation_loading_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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
  bool _isLoading = false;


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
    if (_isLoading) return;
    setState(() => _isLoading = true);

    List<SpellingWord> allWords;

    try {
      final diffStr = difficulty.toString().split('.').last;
      final aiWords = await AILogicService.instance.generatePracticeWords(diffStr, 10);
      
      allWords = aiWords.map((wordData) {
        return SpellingWord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          word: wordData['word']!,
          description: wordData['description'],
          difficulty: difficulty,
          createdAt: Timestamp.now(),
          createdByUid: 'ai_generated',
          audioUrl: null,
        );
      }).toList();

      if (mounted) {
        AIRateLimitService.instance.showQuotaNotification(
          context,
          uid: widget.user.uid,
          title: 'Spelling Words Generated',
        );
      }
    } catch (e) {
      if (mounted) {
        if (e is AIRateLimitException) {
          if (e.isBurst) {
            AIQuotaExceededDialog.showBurst(
              context,
              e.cooldownRemaining ?? const Duration(seconds: 15),
            );
          } else {
            AIRateLimitService.instance.getStatus(widget.user.uid).then((stat) {
              if (mounted) {
                AIQuotaExceededDialog.showExceeded(context, stat);
              }
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI generation failed: $e')),
          );
        }
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_isLoading,
      child: Stack(
        children: [
          Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leadingWidth: 240,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  label: Text(
                    _selectedDifficulty == null ? 'Back to Practice Tools' : 'Back to Spelling Bee',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _isLoading ? null : () {
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
                        onPressed: _isLoading ? null : () => Navigator.of(context).push(
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
            body: Container(
              color: isDark
                  ? const Color(0xFF1E1E1E)
                  : AppColors.backgroundBase,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: _buildBody(),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
                  child: const GenerationLoadingOverlay(
                    title: 'Generating Spelling Words...',
                    subtitle: 'Curating vocabulary with custom definitions and hints...',
                  ),
                ),
              ),
            ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
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


                const AIQuotaBadge(),
                const SizedBox(height: 16),

                // Main Centered Header
                Text(
                  'Choose your Difficulty',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 44 : 32,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      height: 1.55,
                      fontWeight: FontWeight.w400,
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

  Widget _buildStatBox(String title, String value, IconData icon, Color color, {bool isMobile = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSession() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minutes = (_timeLeft / 60).floor().toString().padLeft(2, '0');
    final seconds = (_timeLeft % 60).toString().padLeft(2, '0');

    String difficultyText = "";
    Color difficultyColor = AppColors.primary;
    switch (_selectedDifficulty) {
      case SpellingDifficulty.novice:
        difficultyText = "Novice";
        difficultyColor = const Color(0xFFF59E0B);
        break;
      case SpellingDifficulty.amateur:
        difficultyText = "Amateur";
        difficultyColor = AppColors.primary;
        break;
      case SpellingDifficulty.professional:
        difficultyText = "Professional";
        difficultyColor = const Color(0xFFEF4444);
        break;
      default:
        break;
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 32, isMobile ? 16 : 24, 40),
      child: Column(
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: difficultyColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: difficultyColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.spellcheck_rounded, size: 16, color: difficultyColor),
                const SizedBox(width: 6),
                Text(
                  'SPELLING BEE • $difficultyText',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: difficultyColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 20),

          // KPI Stats Cards
          if (isMobile)
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Progress',
                    '${_currentIndex + 1} / 10',
                    Icons.subtitles_rounded,
                    AppColors.primary,
                    isMobile: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatBox(
                    'Score',
                    '$_score / 10',
                    Icons.stars_rounded,
                    const Color(0xFFF59E0B),
                    isMobile: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatBox(
                    'Time Left',
                    '$minutes:$seconds',
                    Icons.timer_rounded,
                    const Color(0xFFEF4444),
                    isMobile: true,
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildStatBox('Progress', '${_currentIndex + 1} / 10', Icons.subtitles_rounded, AppColors.primary),
                _buildStatBox('Current Score', '$_score / 10', Icons.stars_rounded, const Color(0xFFF59E0B)),
                _buildStatBox('Time Left', '$minutes:$seconds', Icons.timer_rounded, const Color(0xFFEF4444)),
              ],
            ),
          SizedBox(height: isMobile ? 16 : 36),

          // Main Card
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18 : 36,
                vertical: isMobile ? 24 : 40,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Speaker Audio Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _speakWord,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: _isPlaying ? 0.5 : 0.25),
                              blurRadius: _isPlaying ? 28 : 16,
                              spreadRadius: _isPlaying ? 6 : 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isPlaying ? "Listening to word..." : "Tap to replay audio prompt",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isPlaying ? AppColors.primary : (isDark ? Colors.white60 : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Listen carefully and spell the word",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (_sessionWords.isNotEmpty &&
                      _currentIndex < _sessionWords.length &&
                      _sessionWords[_currentIndex].description != null &&
                      _sessionWords[_currentIndex].description!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: isDark ? Colors.amber[300] : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _sessionWords[_currentIndex].description!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: _answerController,
                    focusNode: _focusNode,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your answer here...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submitAnswer(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitAnswer,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        'Submit Answer',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _skipWord,
                        icon: const Icon(Icons.skip_next_rounded, size: 16),
                        label: Text('Skip Word', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () {
                          _timer?.cancel();
                          setState(() => _selectedDifficulty = null);
                        },
                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                        label: Text(
                          'Quit Session',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _sessionWords.length;
    final pct = total > 0 ? ((_score / total) * 100).round() : 0;

    String tierTitle;
    String tierSubtitle;
    IconData tierIcon;
    Color tierColor;
    String tierBadge;

    if (pct == 100) {
      tierTitle = 'Flawless Victory!';
      tierSubtitle = 'You spelled every single word perfectly without a hitch!';
      tierIcon = Icons.emoji_events_rounded;
      tierColor = const Color(0xFFF59E0B);
      tierBadge = '🏆 PERFECT SPELLCASTER';
    } else if (pct >= 80) {
      tierTitle = 'Spectacular Spelling!';
      tierSubtitle = 'Outstanding performance! You are mastering this vocabulary level!';
      tierIcon = Icons.stars_rounded;
      tierColor = const Color(0xFF10B981);
      tierBadge = '🌟 SPELLING MASTER';
    } else if (pct >= 50) {
      tierTitle = 'Great Effort!';
      tierSubtitle = 'Solid work! Keep practicing to get even closer to perfection!';
      tierIcon = Icons.thumb_up_rounded;
      tierColor = const Color(0xFF3B82F6);
      tierBadge = '🎯 ON TARGET';
    } else {
      tierTitle = 'Keep Practicing!';
      tierSubtitle = 'Every attempt builds stronger language memory. You got this!';
      tierIcon = Icons.fitness_center_rounded;
      tierColor = const Color(0xFF8B5CF6);
      tierBadge = '💪 PRACTICE MAKES PERFECT';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // 1. Fun Celebration Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: tierColor.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Tier Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        tierBadge,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tierColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Glowing Icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [tierColor, tierColor.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tierColor.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(tierIcon, size: 48, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      tierTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      tierSubtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 2. Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$_score / $total',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: tierColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'CORRECT',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$pct%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF81B655),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ACCURACY',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _selectedDifficulty == SpellingDifficulty.professional
                                      ? 'Pro'
                                      : (_selectedDifficulty == SpellingDifficulty.amateur
                                          ? 'Amateur'
                                          : (_selectedDifficulty == SpellingDifficulty.novice
                                              ? 'Novice'
                                              : 'Normal')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'DIFFICULTY',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // 3. Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              if (_selectedDifficulty != null) {
                                _startSession(_selectedDifficulty!);
                              } else {
                                setState(() => _selectedDifficulty = null);
                              }
                            },
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: Text(
                              'Play Again',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF81B655),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _selectedDifficulty = null),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: Text(
                              'All Levels',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => setState(() => _showPreview = !_showPreview),
                      icon: Icon(
                        _showPreview ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 20,
                        color: const Color(0xFF81B655),
                      ),
                      label: Text(
                        _showPreview ? 'Hide Words Review' : 'Review Your Words (${_sessionWords.length})',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF81B655),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Word Review Section
              if (_showPreview) ...[
                const SizedBox(height: 20),
                ...List.generate(_sessionWords.length, (index) {
                  final wordObj = _sessionWords[index];
                  final userAnswer = _userAnswers[index];
                  final isCorrect = userAnswer?.trim().toLowerCase() == wordObj.word.toLowerCase();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCorrect
                            ? const Color(0xFF10B981).withValues(alpha: 0.35)
                            : const Color(0xFFEF4444).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCorrect ? Icons.check_rounded : Icons.close_rounded,
                            color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wordObj.word,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (wordObj.description != null && wordObj.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  wordObj.description!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                userAnswer?.isEmpty ?? true ? 'No answer given' : 'Your input: "$userAnswer"',
                                style: TextStyle(
                                  color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovered
                    ? widget.themeColor.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
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
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: filled ? Colors.white : (isDark ? Colors.grey[600] : const Color(0xFF94A3B8)),
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
