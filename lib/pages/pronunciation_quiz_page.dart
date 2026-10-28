import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';
import '../services/web_service.dart';
import '../services/ai_logic_service.dart';
import '../models/spelling_word.dart';
import '../pages/admin/admin_spelling_words_tab.dart';
import '../theme/app_colors.dart';
import '../services/ai_rate_limit_service.dart';
import '../widgets/ai_quota_badge.dart';
import '../widgets/ai_quota_exceeded_dialog.dart';
import '../widgets/generation_loading_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';


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
  bool? _isLastCorrect;
  bool _isTransitioning = false;
  bool _isLoading = false;

  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;
  bool _isStartingRecording = false;
  dynamic _webRecognition;

  // Mic volume metering
  double _micVolume = 0.0;
  Timer? _volumeTimer;
  Timer? _watchdogTimer;
  Timer? _submissionDebounceTimer;

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
      _initSpeech();
    }
  }


  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isRecording && (_recognizedText.isEmpty || _recognizedText == "Listening...")) {
        debugPrint("[Speech] Watchdog timeout - resetting stuck listening state");
        _stopRecording();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No speech detected. Tap the mic to try again."),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _initSpeech() async {
    if (_isSpeechInitialized) return;
    try {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint("Microphone permission not granted");
          return;
        }
      }

      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Speech Status: $status");
          if (_isStartingRecording) return;
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording && !_isTransitioning) {
              if (_recognizedText.isNotEmpty && _recognizedText != "Listening...") {
                _autoSubmit();
              } else {
                _stopRecording();
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("Speech Error: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})");
          if (_isStartingRecording) return;
          if (mounted && _isRecording) {
            _stopRecording();
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Speech Init Error: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _volumeTimer?.cancel();
    _watchdogTimer?.cancel();
    _submissionDebounceTimer?.cancel();
    if (kIsWeb) {
      if (_webRecognition != null) {
        try {
          WebService.instance.stopSpeechRecognition(_webRecognition);
        } catch (_) {}
        _webRecognition = null;
      }
      try {
        WebService.instance.stopMicMonitor();
      } catch (_) {}
    }
    if (!kIsWeb) {
      try {
        _speech.cancel();
      } catch (_) {}
    }
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
    _stopRecording();
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
          title: 'Practice Words Generated',
        );
      }
    } catch (e) {
      if (!mounted) return;
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
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted) return;
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words generated. Please try again.')),
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
      _isLastCorrect = null;
      _isTransitioning = false;
    });

    _startTimer();
  }

  Future<void> _startRecording() async {
    if (_isTransitioning) return;

    if (kIsWeb) {
      await _startWebRecording();
    } else {
      await _startMobileRecording();
    }
  }

  Future<void> _startWebRecording() async {
    if (_isStartingRecording) return;
    _isStartingRecording = true;

    // 1. Verify browser support
    if (!WebService.instance.isSpeechRecognitionSupported()) {
      _isStartingRecording = false;
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

    if (!mounted || _isTransitioning) {
      _isStartingRecording = false;
      return;
    }

    // Clean up any lingering recognition
    if (_webRecognition != null) {
      try {
        WebService.instance.stopSpeechRecognition(_webRecognition);
      } catch (_) {}
      _webRecognition = null;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _submissionDebounceTimer?.cancel();
    _submissionDebounceTimer = null;

    setState(() {
      _isRecording = true;
      _recognizedText = "Listening...";
      _micVolume = 0.0;
    });

    _isStartingRecording = false;
    _resetWatchdog();

    // Smooth listening waveform animation (without locking the hardware mic)
    _volumeTimer?.cancel();
    double phase = 0.0;
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted && _isRecording) {
        phase += 0.35;
        final wave = 0.25 + 0.45 * sin(phase).abs();
        setState(() => _micVolume = wave);
      }
    });

    _startWebSpeechSession();
  }

  void _startWebSpeechSession() {
    if (!mounted || !_isRecording || _isTransitioning) return;

    try {
      final recognition = WebService.instance.createSpeechRecognition();
      if (recognition == null) {
        debugPrint('[WebSpeech] Could not create SpeechRecognition instance');
        return;
      }

      _webRecognition = recognition;

      WebService.instance.configureSpeechRecognition(
        recognition: recognition,
        onResult: (transcript, isFinal) {
          debugPrint('[WebSpeech] Recognized: "$transcript", isFinal: $isFinal');
          if (mounted && !_isTransitioning) {
            final cleanText = transcript.trim();
            if (cleanText.isNotEmpty) {
              setState(() {
                _recognizedText = cleanText;
                _micVolume = 0.9;
              });
            }
            if (isFinal && cleanText.isNotEmpty && cleanText != "Listening...") {
              // Give user 1.2 seconds to finish before auto-submitting
              _submissionDebounceTimer?.cancel();
              _submissionDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
                if (mounted && _isRecording && !_isTransitioning) {
                  _autoSubmit();
                }
              });
            }
          }
        },
        onError: (e) {
          debugPrint('[WebSpeech] Error: $e');
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('not-allowed') || errStr.contains('denied') || errStr.contains('permission')) {
            _stopRecording();
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
            _stopRecording();
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
            debugPrint('[WebSpeech] session aborted');
          } else {
            debugPrint('[WebSpeech] unhandled error: $errStr');
          }
        },
        onEnd: () {
          debugPrint('[WebSpeech] onEnd event');
          if (mounted && _isRecording && !_isTransitioning) {
            if (_recognizedText.isNotEmpty && _recognizedText != "Listening...") {
              // Word captured; submit after short delay
              _submissionDebounceTimer?.cancel();
              _submissionDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
                if (mounted && _isRecording && !_isTransitioning) {
                  _autoSubmit();
                }
              });
            } else {
              // Silence timeout: cleanly restart after 400ms so Android/Chrome audio service can cycle cleanly
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted && _isRecording && !_isTransitioning) {
                  _startWebSpeechSession();
                }
              });
            }
          }
        },
      );

      WebService.instance.startSpeechRecognition(recognition);
    } catch (e) {
      debugPrint('[WebSpeech] Session start exception: $e');
    }
  }

  Future<void> _startMobileRecording() async {
    _isStartingRecording = true;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _isStartingRecording = false;
      _stopRecording();
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
      _isStartingRecording = false;
      _stopRecording();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device.')),
      );
      return;
    }

    try {
      // Force cancel any lingering session to ensure the Android recognizer is completely free
      if (_speech.isListening) {
        await _speech.cancel();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      _resetWatchdog();

      bool started = await _speech.listen(
        onResult: (result) {
          debugPrint('[MobileSpeech] Result: "${result.recognizedWords}", isFinal: ${result.finalResult}');
          if (mounted && !_isTransitioning) {
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              setState(() {
                _recognizedText = words;
              });
            }
            if (result.finalResult && words.isNotEmpty && words != "Listening...") {
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted && _isRecording && !_isTransitioning) {
                  _autoSubmit();
                }
              });
            }
          }
        },
        onSoundLevelChange: (level) {
          if (mounted && _isRecording) {
            double normalized = level > 1.0 ? ((level + 2) / 12.0) : level;
            setState(() => _micVolume = normalized.clamp(0.1, 1.0));
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

      _isStartingRecording = false;

      if (started) {
        if (mounted) {
          setState(() {
            _isRecording = true;
            _recognizedText = "Listening...";
            _micVolume = 0.0;
          });
        }
      } else {
        debugPrint('[MobileSpeech] First listen call returned false. Cancelling and retrying once...');
        await _speech.cancel();
        await Future.delayed(const Duration(milliseconds: 250));

        started = await _speech.listen(
          onResult: (result) {
            debugPrint('[MobileSpeech-Retry] Result: "${result.recognizedWords}", isFinal: ${result.finalResult}');
            if (mounted && !_isTransitioning) {
              final words = result.recognizedWords.trim();
              if (words.isNotEmpty) {
                setState(() {
                  _recognizedText = words;
                });
              }
              if (result.finalResult && words.isNotEmpty && words != "Listening...") {
                Future.delayed(const Duration(milliseconds: 700), () {
                  if (mounted && _isRecording && !_isTransitioning) {
                    _autoSubmit();
                  }
                });
              }
            }
          },
          onSoundLevelChange: (level) {
            if (mounted && _isRecording) {
              double normalized = level > 1.0 ? ((level + 2) / 12.0) : level;
              setState(() => _micVolume = normalized.clamp(0.1, 1.0));
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
            _isRecording = true;
            _recognizedText = "Listening...";
            _micVolume = 0.0;
          });
        } else {
          debugPrint('[MobileSpeech] Speech recognizer failed to start after retry.');
          _stopRecording();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone was busy. Please tap the mic again to speak.')),
            );
          }
        }
      }
    } catch (e) {
      _isStartingRecording = false;
      debugPrint('[MobileSpeech] Listen error: $e');
      _stopRecording();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start speech recognition: $e')),
        );
      }
    }
  }

  void _stopRecording() {
    _isStartingRecording = false;
    _volumeTimer?.cancel();
    _volumeTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _submissionDebounceTimer?.cancel();
    _submissionDebounceTimer = null;

    if (kIsWeb) {
      if (_webRecognition != null) {
        try {
          WebService.instance.stopSpeechRecognition(_webRecognition);
        } catch (_) {}
        _webRecognition = null;
      }
      try {
        WebService.instance.stopMicMonitor();
      } catch (_) {}
    }

    if (!kIsWeb) {
      try {
        _speech.cancel();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _micVolume = 0.0;
        if (_recognizedText == "Listening...") {
          _recognizedText = "";
        }
      });
    }
  }

  void _autoSubmit() {
    if (_isRecording) {
      _stopRecording();
    }
    // Only submit if we have real recognized text
    if (_recognizedText.isNotEmpty && _recognizedText != "Listening...") {
      _submitAnswer();
    }
  }

  void _resetRecording() {
    _stopRecording();
    if (mounted) {
      setState(() {
        _recognizedText = "";
      });
    }
  }

  void _submitAnswer() {
    if (_isTransitioning || _currentIndex >= _sessionWords.length) return;

    // Clean up the recognized text: lowercase, trim, and remove punctuation
    String rawAnswer = _recognizedText.trim().toLowerCase();
    
    // Apply profanity filter
    String answer = _filterProfanity(rawAnswer);
    
    if (answer != rawAnswer) {
      _showProfanityWarning();
    }

    answer = answer.replaceAll(RegExp(r'[^\w\s]'), ''); // Remove punctuation
    
    final correctWord = _sessionWords[_currentIndex].word.toLowerCase().trim();

    _userAnswers.add(_recognizedText);

    // Matching logic:
    // 1. Exact match after cleaning
    // 2. Contains match (in case recognition adds extra words like "the apple")
    // 3. Fuzzy match (allow for slight misrecognitions)
    
    double similarity = StringSimilarity.compareTwoStrings(answer, correctWord);
    bool isCorrect = answer == correctWord || 
                    answer.contains(correctWord) || 
                    similarity >= 0.7; // Lowered from 0.8

    if (mounted) {
      setState(() {
        _isLastCorrect = isCorrect;
        _isTransitioning = true;
        if (isCorrect) _score++;
      });

      // Delay to show feedback before next word
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            _isLastCorrect = null;
            _isTransitioning = false;
            _recognizedText = "";
          });
          _nextWord();
        }
      });
    }
  }

  void _nextWord() {
    _stopRecording();
    if (_currentIndex < _sessionWords.length - 1) {
      setState(() {
        _currentIndex++;
        _recognizedText = "";
        _isRecording = false;
        _micVolume = 0.0;
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

  String _filterProfanity(String text) {
    const profaneWords = [
      'fuck', 'shit', 'asshole', 'bitch', 'cunt', 'dick', 'pussy', 'faggot', 'bastard', 'damn'
    ];
    String filtered = text;
    for (final word in profaneWords) {
      final regExp = RegExp(r'\b' + word + r'\b', caseSensitive: false);
      filtered = filtered.replaceAll(regExp, '*' * word.length);
    }
    return filtered;
  }

  void _showProfanityWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Language Warning'),
          ],
        ),
        content: const Text(
          'Inappropriate language detected. Please keep your speech professional and focused on the learning material.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8BC34A))),
          ),
        ],
      ),
    );
  }

  void _skipWord() {
    _stopRecording();
    _userAnswers.add("");
    _nextWord();
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
          'Are you sure you want to quit this pronunciation quiz? Your progress will not be saved.',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_isLoading && (_selectedDifficulty == null || _isGameOver),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isLoading) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop == true && mounted) {
          if (_selectedDifficulty != null && !_isGameOver) {
            _timer?.cancel();
            setState(() => _selectedDifficulty = null);
          } else {
            widget.onBack();
          }
        }
      },
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
                    _selectedDifficulty == null ? 'Back to Practice Tools' : 'Back to Pronunciation',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _isLoading ? null : () async {
                    if (_selectedDifficulty == null) {
                      widget.onBack();
                    } else if (_isGameOver) {
                      setState(() => _selectedDifficulty = null);
                    } else {
                      final shouldPop = await _showExitConfirmation();
                      if (shouldPop == true && mounted) {
                        _timer?.cancel();
                        setState(() => _selectedDifficulty = null);
                      }
                    }
                  },
                ),
              ),
              actions: [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: AIQuotaBadge(),
                  ),
                ),
                StreamBuilder<UserRole>(
                  stream: RoleService.instance.roleStream(widget.user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.data == UserRole.admin || snapshot.data == UserRole.superadmin) {
                      return IconButton(
                        icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary),
                        onPressed: _isLoading ? null : () async {
                          if (_selectedDifficulty != null && !_isGameOver) {
                            final shouldPop = await _showExitConfirmation();
                            if (shouldPop != true) return;
                          }
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminSpellingWordsTab(),
                              ),
                            );
                          }
                        },
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
                    title: 'Generating Practice Words...',
                    subtitle: 'Crafting pronunciation targets and phonetic guidelines...',
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
      color: Colors.transparent,
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
                    'Select a challenge level below to practice speaking. Test real-time speech recognition & accuracy scoring across levels.',
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
                                title: 'Beginner',
                                subtitle:
                                    '120s per word. Pronounce foundational words with extended time.',
                                tag: 'BEGINNER',
                                icon: Icons.lightbulb_outline_rounded,
                                themeColor: const Color(0xFFF59E0B),
                                onTap: () =>
                                    _startSession(SpellingDifficulty.novice),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _DifficultyCard(
                                title: 'Intermediate',
                                subtitle:
                                    '60s per word. Practice conversational and everyday pronunciation.',
                                tag: 'INTERMEDIATE',
                                icon: Icons.graphic_eq_rounded,
                                themeColor: const Color(0xFF81B655),
                                onTap: () =>
                                    _startSession(SpellingDifficulty.amateur),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _DifficultyCard(
                                title: 'Advanced',
                                subtitle:
                                    '30s per word. Master complex pronunciations under tight timers.',
                                tag: 'ADVANCED',
                                icon: Icons.psychology_rounded,
                                themeColor: const Color(0xFFEF4444),
                                onTap: () => _startSession(
                                    SpellingDifficulty.professional),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _DifficultyCard(
                              title: 'Beginner',
                              subtitle:
                                  '120s per word. Pronounce foundational words with extended time.',
                              tag: 'BEGINNER',
                              icon: Icons.lightbulb_outline_rounded,
                              themeColor: const Color(0xFFF59E0B),
                              onTap: () =>
                                  _startSession(SpellingDifficulty.novice),
                            ),
                            const SizedBox(height: 20),
                            _DifficultyCard(
                              title: 'Intermediate',
                              subtitle:
                                  '60s per word. Practice conversational and everyday pronunciation.',
                              tag: 'INTERMEDIATE',
                              icon: Icons.graphic_eq_rounded,
                              themeColor: const Color(0xFF81B655),
                              onTap: () =>
                                  _startSession(SpellingDifficulty.amateur),
                            ),
                            const SizedBox(height: 20),
                            _DifficultyCard(
                              title: 'Advanced',
                              subtitle:
                                  '30s per word. Master complex pronunciations under tight timers.',
                              tag: 'ADVANCED',
                              icon: Icons.psychology_rounded,
                              themeColor: const Color(0xFFEF4444),
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

  Widget _buildStatBox(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        difficultyText = "Beginner";
        difficultyColor = const Color(0xFFF59E0B);
        break;
      case SpellingDifficulty.amateur:
        difficultyText = "Intermediate";
        difficultyColor = AppColors.primary;
        break;
      case SpellingDifficulty.professional:
        difficultyText = "Advanced";
        difficultyColor = const Color(0xFFEF4444);
        break;
      default:
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
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
                Icon(Icons.mic_rounded, size: 16, color: difficultyColor),
                const SizedBox(width: 6),
                Text(
                  'PRONUNCIATION • $difficultyText',
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
          const SizedBox(height: 20),

          // KPI Stats Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildStatBox('Progress', '${_currentIndex + 1} / ${_sessionWords.length}', Icons.subtitles_rounded, AppColors.primary),
              _buildStatBox('Current Score', '$_score / ${_sessionWords.length}', Icons.stars_rounded, const Color(0xFFF59E0B)),
              _buildStatBox('Time Left', '$minutes:$seconds', Icons.timer_rounded, const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 36),

          // Main Interactive Card
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
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
                  if (_currentIndex < _sessionWords.length)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isTransitioning
                              ? (_isLastCorrect == true ? AppColors.primary : AppColors.error)
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                          width: _isTransitioning ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Center(
                              child: Text(
                                _sessionWords[_currentIndex].word,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: _isTransitioning
                                      ? (_isLastCorrect == true ? AppColors.primary : AppColors.error)
                                      : (isDark ? Colors.white : AppColors.textPrimary),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            if (_sessionWords[_currentIndex].description != null &&
                                _sessionWords[_currentIndex].description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _sessionWords[_currentIndex].description!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                            if (_isTransitioning) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isLastCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: _isLastCorrect == true ? AppColors.primary : AppColors.error,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isLastCorrect == true ? "Great Pronunciation!" : "Needs Practice",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _isLastCorrect == true ? AppColors.primary : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    "Press the mic and say the word clearly",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Audio Waveform Meter
                  SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(31, (index) {
                        double baseHeight = 8.0 + (index % 5) * 4.0;
                        double dynamicHeight = _isRecording ? baseHeight + (_micVolume * 36 * (index % 3 + 1)) : baseHeight;
                        if (index == 15) dynamicHeight = _isRecording ? 48.0 + _micVolume * 24 : 24.0;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 4,
                          height: dynamicHeight.clamp(4.0, 48.0),
                          decoration: BoxDecoration(
                            color: _isRecording ? AppColors.primary : (isDark ? Colors.white30 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_recognizedText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _recognizedText == "Listening..." ? "Listening..." : "I heard: \"$_recognizedText\"",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isTransitioning
                              ? (_isLastCorrect == true ? AppColors.primary : AppColors.error)
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Mic Controls Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reset Button
                      OutlinedButton.icon(
                        onPressed: _resetRecording,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text('Reset', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Mic Button
                      GestureDetector(
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _isRecording ? AppColors.error : AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? AppColors.error : AppColors.primary).withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: _isRecording ? 6 : 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Submit Button
                      ElevatedButton.icon(
                        onPressed: (_recognizedText.isNotEmpty && _recognizedText != "Listening...") ? _submitAnswer : null,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text('Submit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
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
      tierTitle = 'Pronunciation Royalty!';
      tierSubtitle = 'Flawless articulation! Your accent and clarity match native standards!';
      tierIcon = Icons.record_voice_over_rounded;
      tierColor = const Color(0xFFF59E0B);
      tierBadge = '🏆 FLAWLESS ORATOR';
    } else if (pct >= 80) {
      tierTitle = 'Outstanding Voice & Clarity!';
      tierSubtitle = 'Superb speech clarity! You sound confident, natural, and expressive!';
      tierIcon = Icons.stars_rounded;
      tierColor = const Color(0xFF10B981);
      tierBadge = '🌟 SPEECH MASTER';
    } else if (pct >= 50) {
      tierTitle = 'Great Vocal Practice!';
      tierSubtitle = 'Solid pronunciation flow! A few more rounds will get you to 100%!';
      tierIcon = Icons.graphic_eq_rounded;
      tierColor = const Color(0xFF3B82F6);
      tierBadge = '🎯 CLEAR & STEADY';
    } else {
      tierTitle = 'Vocal Journey Begins!';
      tierSubtitle = 'Speaking is a muscle that strengthens with every word. Let\'s try again!';
      tierIcon = Icons.mic_rounded;
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
                                  'PASSED',
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
                                  'VOICE MATCH',
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
                                      ? 'Advanced'
                                      : (_selectedDifficulty == SpellingDifficulty.amateur
                                          ? 'Intermediate'
                                          : (_selectedDifficulty == SpellingDifficulty.novice
                                              ? 'Beginner'
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
                        _showPreview ? 'Hide Speech Review' : 'Review Your Pronunciation (${_sessionWords.length})',
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

              // 4. Pronunciation Speech Review Section
              if (_showPreview) ...[
                const SizedBox(height: 20),
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
                              Row(
                                children: [
                                  Text(
                                    wordObj.word,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(similarity * 100).round()}% match',
                                    style: TextStyle(
                                      color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
                                userAnswer?.isEmpty ?? true ? 'No speech detected' : 'Detected speech: "$userAnswer"',
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
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.themeColor,
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
              color: isDark ? const Color(0xFF262626) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovered
                    ? widget.themeColor.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE2E8F0)),
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
                const SizedBox(height: 24),

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




