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
      // Poll volume 20Ã—/second
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
        leadingWidth: 240,
        leading: Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: TextButton.icon(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            label: Text(
              _selectedDifficulty == null ? 'Back to Practice Tools' : 'Back to Pronunciation',
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
        // Removed title to match reference image which is clean in the middle
        actions: [
          StreamBuilder<UserRole>(
            stream: RoleService.instance.roleStream(widget.user.uid),
            builder: (context, snapshot) {
              if (snapshot.data == UserRole.admin || snapshot.data == UserRole.superadmin) {
                return IconButton(
                  icon: Icon(Icons.settings_rounded, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminSpellingWordsTab(),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BackgroundWrapper(
        imageAssetPath: _selectedDifficulty == null 
            ? 'assets/practicebg.png' 
            : 'assets/pronunciationbg.png',
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
            'Select a level for Pronunciation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 48),
          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: [
              _DifficultyCard(
                title: 'Novice',
                color: const Color(0xFFFDE061),
                icon: Icons.star_rounded,
                rating: 2,
                onTap: () => _startSession(SpellingDifficulty.novice),
              ),
              _DifficultyCard(
                title: 'Amateur',
                color: const Color(0xFFA1CC73),
                icon: Icons.insights_rounded,
                rating: 3,
                onTap: () => _startSession(SpellingDifficulty.amateur),
              ),
              _DifficultyCard(
                title: 'Professional',
                color: const Color(0xFFE6625B),
                icon: Icons.local_fire_department_rounded,
                rating: 4,
                onTap: () => _startSession(SpellingDifficulty.professional),
              ),
            ],
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
        difficultyColor = const Color(0xFF8BC34A); // Match mockup color
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
                TextSpan(text: 'Pronunciation - '),
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
                  if (_currentIndex < _sessionWords.length)
                    Container(
                      width: 300,
                      padding: EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8BC34A), width: 2), // The mockup shows a green border
                      ),
                      child: Center(
                        child: Text(
                          _sessionWords[_currentIndex].word,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 24),
                  Text(
                    "Press the mic and say the word",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Waveform Mockup based on volume
                  SizedBox(
                    height: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(31, (index) {
                        double baseHeight = 10.0 + (index % 5) * 5.0; // static base height pattern
                        double dynamicHeight = _isRecording ? baseHeight + (_micVolume * 40 * (index % 3 + 1)) : baseHeight;
                        if (index == 15) dynamicHeight = _isRecording ? 50.0 + _micVolume * 30 : 25.0; // center is highest
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          width: 4,
                          height: dynamicHeight.clamp(4.0, 50.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8), // Dark color from the screenshot
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: 32),

                  // Mic Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reset Button
                      InkWell(
                        onTap: _resetRecording,
                        borderRadius: BorderRadius.circular(32),
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            children: const [
                              Icon(Icons.refresh_rounded, size: 28, color: Colors.black54),
                              SizedBox(height: 4),
                              Text("Reset", style: TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 40),
                      // Mic Button
                      GestureDetector(
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8BC34A), // Green
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (_isRecording)
                                BoxShadow(
                                  color: const Color(0xFF8BC34A).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 8,
                                ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic_off_rounded : Icons.mic_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 40),
                      // Submit Button
                      InkWell(
                        onTap: _recognizedText.isNotEmpty ? _submitAnswer : null,
                        borderRadius: BorderRadius.circular(32),
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Icon(Icons.check_rounded, size: 28, color: _recognizedText.isNotEmpty ? Colors.black54 : Colors.black26),
                              SizedBox(height: 4),
                              Text("Submit", style: TextStyle(fontSize: 12, color: _recognizedText.isNotEmpty ? Colors.black54 : Colors.black26)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
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
                      'Cancel Pronunciation',
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
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.celebration_rounded, size: 64, color: AppColors.primary),
          ),
          SizedBox(height: 32),
          Text(
            'Brilliant Work!',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(height: 12),
          Text(
            'Session completed with excellence.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          SizedBox(height: 40),
          Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Text(
                    'Final Score',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_score',
                        style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Text(
                        '/${_sessionWords.length}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => setState(() => _selectedDifficulty = null),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 56),
            ),
            child: Text('Back to Menu'),
          ),
          SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            child: Text(_showPreview ? 'Hide Details' : 'Review Progress'),
          ),
          if (_showPreview) ...[
            SizedBox(height: 32),
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
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
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
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wordObj.word,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
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
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 48),
          ),
          SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Difficulty:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  Icons.star_rounded,
                  color: index < rating ? const Color(0xFFFABF00) : Colors.grey[400],
                  size: 24,
                ),
              );
            }),
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
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


