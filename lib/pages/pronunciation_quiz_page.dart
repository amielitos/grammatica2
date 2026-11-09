import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
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
import 'practice_tab.dart';


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
  double _score = 0.0;
  bool _isGameOver = false;
  bool _isRecording = false;
  String _recognizedText = "";
  bool? _isLastCorrect;
  bool _isTransitioning = false;
  bool _isLoading = false;

  // Hint & Breakdown
  bool _isHintRevealed = false;
  final List<bool> _hintUsedPerWord = [];
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingTts = false;
  bool _isSlowSpeed = false;

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
    _initTts();
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
    try {
      _flutterTts.stop();
    } catch (_) {}
    PracticeTab.isGenerating.value = false;
    if (PracticeTab.confirmExitActiveSession == _confirmQuitSession) {
      PracticeTab.confirmExitActiveSession = null;
    }
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isPlayingTts = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlayingTts = false);
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        if (mounted) setState(() => _isPlayingTts = false);
      });

      try {
        await _flutterTts.setLanguage("en-US");
        await _flutterTts.setSpeechRate(0.45);
        await _flutterTts.setVolume(1.0);
      } catch (e) {
        debugPrint("TTS Configuration Error: $e");
      }
    } catch (e) {
      debugPrint("TTS Init Error: $e");
    }
  }

  Future<void> _playTtsWord(String word) async {
    if (_isRecording) {
      _stopRecording();
    }
    try {
      await _flutterTts.stop();
      await _flutterTts.setSpeechRate(_isSlowSpeed ? 0.22 : 0.45);
      await _flutterTts.speak(word);
    } catch (e) {
      debugPrint("TTS Play Error: $e");
    }
  }

  void _revealHint() {
    if (_isHintRevealed || _isTransitioning) return;
    setState(() {
      _isHintRevealed = true;
    });
  }

  String _formatScore(double s) => (s % 1 == 0) ? s.toInt().toString() : s.toStringAsFixed(1);

  String _generateFallbackPhonetic(String word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    final regex = RegExp(r'[^aeiouy]*[aeiouy]+(?:[^aeiouy](?=[^aeiouy]))?');
    final matches = regex.allMatches(lower).map((m) => m.group(0)!).toList();
    if (matches.length > 1) {
      return matches.join(' · ');
    }
    return lower;
  }

  Widget _buildHintBreakdownCard(bool isDark) {
    if (_currentIndex >= _sessionWords.length) return const SizedBox.shrink();
    final currentWordObj = _sessionWords[_currentIndex];
    final phonetic = (currentWordObj.phonetic != null && currentWordObj.phonetic!.trim().isNotEmpty)
        ? currentWordObj.phonetic!.trim()
        : _generateFallbackPhonetic(currentWordObj.word);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent & deduction pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.language_rounded,
                    size: 15,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'American Pronunciation',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.2 : 0.8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '-50% points',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Inner Breakdown Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sounds like',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPhoneticBreakdown(phonetic, isDark),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _playTtsWord(currentWordObj.word),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isPlayingTts
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : (isDark ? Colors.white10 : Colors.grey.shade100),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isPlayingTts
                                  ? AppColors.primary
                                  : (isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                          ),
                          child: Icon(
                            _isPlayingTts ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                            size: 22,
                            color: _isPlayingTts
                                ? AppColors.primary
                                : (isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Slow toggle switch
          Row(
            children: [
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: _isSlowSpeed,
                  onChanged: (val) {
                    setState(() => _isSlowSpeed = val);
                  },
                  activeThumbColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Slow',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneticBreakdown(String phonetic, bool isDark) {
    final parts = phonetic.split(RegExp(r'\s*[·•\-]\s*'));
    if (parts.length <= 1) {
      return Text(
        phonetic,
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(parts.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              '·',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade400,
              ),
            ),
          );
        }
        final part = parts[i ~/ 2].trim();
        final isStressed = part == part.toUpperCase() && part.toLowerCase() != part.toUpperCase();
        return Text(
          part.toLowerCase(),
          style: GoogleFonts.outfit(
            fontSize: isStressed ? 22 : 20,
            fontWeight: isStressed ? FontWeight.w900 : FontWeight.w600,
            color: isStressed
                ? AppColors.primary
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        );
      }),
    );
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
    _hintUsedPerWord.add(_isHintRevealed);
    _nextWord();
  }

  Future<void> _startSession(SpellingDifficulty difficulty) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    PracticeTab.isGenerating.value = true;

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
          phonetic: wordData['phonetic'],
          ipa: wordData['ipa'],
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
      PracticeTab.isGenerating.value = false;
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
      _score = 0.0;
      _isGameOver = false;
      _recognizedText = "";
      _userAnswers = [];
      _isHintRevealed = false;
      _hintUsedPerWord.clear();
      _showPreview = false;
      _isLastCorrect = null;
      _isTransitioning = false;
    });
    PracticeTab.confirmExitActiveSession = _confirmQuitSession;

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

  String _normalizeWord(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _submitAnswer() {
    if (_isRecording) {
      _stopRecording();
    }
    if (_isTransitioning || _currentIndex >= _sessionWords.length) return;

    // Clean up the recognized text: lowercase, trim, and remove punctuation
    String rawAnswer = _recognizedText.trim().toLowerCase();
    
    // Apply profanity filter
    String filteredAnswer = _filterProfanity(rawAnswer);
    
    if (filteredAnswer != rawAnswer) {
      _showProfanityWarning();
    }

    final answer = _normalizeWord(filteredAnswer);
    final correctWord = _normalizeWord(_sessionWords[_currentIndex].word);

    _userAnswers.add(_recognizedText);
    final bool hintWasUsed = _isHintRevealed;
    _hintUsedPerWord.add(hintWasUsed);

    // Matching logic: strict 1:1 match between the spoken word and the target word
    bool isCorrect = answer.isNotEmpty && answer == correctWord;

    if (mounted) {
      setState(() {
        _isLastCorrect = isCorrect;
        _isTransitioning = true;
        if (isCorrect) {
          final double pointsAwarded = hintWasUsed ? 0.5 : 1.0;
          _score += pointsAwarded;
        }
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
    try {
      _flutterTts.stop();
    } catch (_) {}
    if (_currentIndex < _sessionWords.length - 1) {
      setState(() {
        _currentIndex++;
        _recognizedText = "";
        _isRecording = false;
        _micVolume = 0.0;
        _isHintRevealed = false;
      });
      _startTimer();
    } else {
      _timer?.cancel();
      if (PracticeTab.confirmExitActiveSession == _confirmQuitSession) {
        PracticeTab.confirmExitActiveSession = null;
      }
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
    _hintUsedPerWord.add(_isHintRevealed);
    _nextWord();
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_isLoading && (_selectedDifficulty == null || _isGameOver),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isLoading) return;
        await _confirmQuitSession();
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
                      if (PracticeTab.confirmExitActiveSession == _confirmQuitSession) {
                        PracticeTab.confirmExitActiveSession = null;
                      }
                      setState(() => _selectedDifficulty = null);
                    } else {
                      await _confirmQuitSession();
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
                            final shouldQuit = await _confirmQuitSession();
                            if (!shouldQuit) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 750;
        final isCompactHeight = constraints.maxHeight < 720;
        final isVeryShort = constraints.maxHeight < 480;

        Widget content = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? (isCompactHeight ? 24 : 48) : 20,
                vertical: isCompactHeight ? 12 : 28,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main Centered Header
                  Text(
                    'Choose your Difficulty',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? (isCompactHeight ? 30 : 40) : 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: isCompactHeight ? 6 : 10),

                  // Subtitle
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Text(
                      'Select a challenge level below to practice speaking. Test real-time speech recognition & accuracy scoring across levels.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isCompactHeight ? 13 : 14.5,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  SizedBox(height: isCompactHeight ? 16 : 32),

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
                                  isCompact: isCompactHeight,
                                  onTap: () =>
                                      _startSession(SpellingDifficulty.novice),
                                ),
                              ),
                              SizedBox(width: isCompactHeight ? 16 : 24),
                              Expanded(
                                child: _DifficultyCard(
                                  title: 'Intermediate',
                                  subtitle:
                                      '60s per word. Practice conversational and everyday pronunciation.',
                                  tag: 'INTERMEDIATE',
                                  icon: Icons.graphic_eq_rounded,
                                  themeColor: const Color(0xFF81B655),
                                  isCompact: isCompactHeight,
                                  onTap: () =>
                                      _startSession(SpellingDifficulty.amateur),
                                ),
                              ),
                              SizedBox(width: isCompactHeight ? 16 : 24),
                              Expanded(
                                child: _DifficultyCard(
                                  title: 'Advanced',
                                  subtitle:
                                      '30s per word. Master complex pronunciations under tight timers.',
                                  tag: 'ADVANCED',
                                  icon: Icons.psychology_rounded,
                                  themeColor: const Color(0xFFEF4444),
                                  isCompact: isCompactHeight,
                                  onTap: () => _startSession(
                                      SpellingDifficulty.professional),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _DifficultyCard(
                                title: 'Beginner',
                                subtitle:
                                    '120s per word. Pronounce foundational words with extended time.',
                                tag: 'BEGINNER',
                                icon: Icons.lightbulb_outline_rounded,
                                themeColor: const Color(0xFFF59E0B),
                                isCompact: isCompactHeight,
                                onTap: () =>
                                    _startSession(SpellingDifficulty.novice),
                              ),
                              const SizedBox(height: 16),
                              _DifficultyCard(
                                title: 'Intermediate',
                                subtitle:
                                    '60s per word. Practice conversational and everyday pronunciation.',
                                tag: 'INTERMEDIATE',
                                icon: Icons.graphic_eq_rounded,
                                themeColor: const Color(0xFF81B655),
                                isCompact: isCompactHeight,
                                onTap: () =>
                                    _startSession(SpellingDifficulty.amateur),
                              ),
                              const SizedBox(height: 16),
                              _DifficultyCard(
                                title: 'Advanced',
                                subtitle:
                                    '30s per word. Master complex pronunciations under tight timers.',
                                tag: 'ADVANCED',
                                icon: Icons.psychology_rounded,
                                themeColor: const Color(0xFFEF4444),
                                isCompact: isCompactHeight,
                                onTap: () => _startSession(
                                    SpellingDifficulty.professional),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (isDesktop && !isVeryShort) {
          return SizedBox(
            width: double.infinity,
            height: constraints.maxHeight,
            child: content,
          );
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: content,
        );
      },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final isCompactHeight = constraints.maxHeight < 680;
        final isVeryCompact = constraints.maxHeight < 560;

        return SizedBox(
          width: double.infinity,
          height: constraints.maxHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 24,
              isCompactHeight ? 6 : 14,
              isMobile ? 12 : 24,
              isCompactHeight ? 8 : 16,
            ),
            child: Column(
              children: [
                // Header Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompactHeight ? 4 : 6),
                  decoration: BoxDecoration(
                    color: difficultyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: difficultyColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded, size: 15, color: difficultyColor),
                      const SizedBox(width: 6),
                      Text(
                        'PRONUNCIATION • $difficultyText',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: difficultyColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompactHeight ? 6 : 12),

                // KPI Stats Cards
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          'Progress',
                          '${_currentIndex + 1} / ${_sessionWords.length}',
                          Icons.subtitles_rounded,
                          AppColors.primary,
                          isMobile: isMobile || isCompactHeight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          'Score',
                          '${_formatScore(_score)} / ${_sessionWords.length}',
                          Icons.stars_rounded,
                          const Color(0xFFF59E0B),
                          isMobile: isMobile || isCompactHeight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox(
                          'Time Left',
                          '$minutes:$seconds',
                          Icons.timer_rounded,
                          const Color(0xFFEF4444),
                          isMobile: isMobile || isCompactHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompactHeight ? 8 : 16),

                // Main Interactive Card
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Container(
                      width: double.infinity,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 28,
                        vertical: isCompactHeight ? 12 : 20,
                      ),
                      child: Column(
                        children: [
                          // Inner Scrollable Section: Word, Description, Phonetic hints, Feedback
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: false,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_currentIndex < _sessionWords.length)
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          vertical: isCompactHeight ? 12 : 18,
                                          horizontal: 16,
                                        ),
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
                                                    fontSize: isVeryCompact ? 28 : (isCompactHeight ? 34 : 40),
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
                                                const SizedBox(height: 6),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  child: Text(
                                                    _sessionWords[_currentIndex].description!,
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.inter(
                                                      fontSize: isCompactHeight ? 13 : 14,
                                                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (!_isTransitioning && !_isHintRevealed) ...[
                                                const SizedBox(height: 10),
                                                OutlinedButton.icon(
                                                  onPressed: _revealHint,
                                                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFD97706)),
                                                  label: Text(
                                                    '(Hint? -50% point)',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.15 : 0.6),
                                                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ],
                                              if (_isHintRevealed) ...[
                                                _buildHintBreakdownCard(isDark),
                                              ],
                                              if (_isTransitioning) ...[
                                                const SizedBox(height: 10),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _isLastCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                      color: _isLastCorrect == true ? AppColors.primary : AppColors.error,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _isLastCorrect == true
                                                          ? (_hintUsedPerWord.isNotEmpty && _hintUsedPerWord.last ? "Great Pronunciation! (+0.5 pts)" : "Great Pronunciation! (+1 pt)")
                                                          : "Needs Practice",
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
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
                                    if (_recognizedText.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _recognizedText == "Listening..." ? "Listening..." : "I heard: \"$_recognizedText\"",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _isTransitioning
                                                ? (_isLastCorrect == true ? AppColors.primary : AppColors.error)
                                                : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Pinned Controls at the bottom of the card
                          const SizedBox(height: 8),
                          Text(
                            "Press the mic and say the word clearly",
                            style: GoogleFonts.inter(
                              fontSize: isCompactHeight ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 6 : 12),

                          // Audio Waveform Meter
                          SizedBox(
                            height: isCompactHeight ? 26 : 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(31, (index) {
                                double maxH = isCompactHeight ? 26.0 : 36.0;
                                double baseHeight = 6.0 + (index % 5) * 2.5;
                                double dynamicHeight = _isRecording ? baseHeight + (_micVolume * (maxH - 10) * (index % 3 + 1)) : baseHeight;
                                if (index == 15) dynamicHeight = _isRecording ? maxH : (maxH * 0.6);

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 80),
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  width: 3.5,
                                  height: dynamicHeight.clamp(4.0, maxH),
                                  decoration: BoxDecoration(
                                    color: _isRecording ? AppColors.primary : (isDark ? Colors.white30 : Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 10 : 16),

                          // Mic Controls Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Mic Button
                              GestureDetector(
                                onTap: _isRecording ? _stopRecording : _startRecording,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isCompactHeight ? 58 : 68,
                                  height: isCompactHeight ? 58 : 68,
                                  decoration: BoxDecoration(
                                    color: _isRecording ? AppColors.error : AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isRecording ? AppColors.error : AppColors.primary).withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        spreadRadius: _isRecording ? 5 : 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                                    size: isCompactHeight ? 30 : 34,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              // Submit Button
                              SizedBox(
                                height: isCompactHeight ? 42 : 46,
                                child: ElevatedButton.icon(
                                  onPressed: (_recognizedText.isNotEmpty && _recognizedText != "Listening...") ? _submitAnswer : null,
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: Text('Submit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: EdgeInsets.symmetric(horizontal: isCompactHeight ? 16 : 20, vertical: 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isCompactHeight ? 10 : 14),

                          // Skip / Quit row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: isCompactHeight ? 36 : 40,
                                child: OutlinedButton.icon(
                                  onPressed: _skipWord,
                                  icon: const Icon(Icons.skip_next_rounded, size: 16),
                                  label: Text('Skip Word', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: isCompactHeight ? 36 : 40,
                                child: TextButton.icon(
                                  onPressed: _confirmQuitSession,
                                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                                  label: Text(
                                    'Quit Session',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmQuitSession() async {
    if (_selectedDifficulty == null || _isGameOver) {
      if (PracticeTab.confirmExitActiveSession == _confirmQuitSession) {
        PracticeTab.confirmExitActiveSession = null;
      }
      return true;
    }
    if (!mounted) return true;
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Quit Session?',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to quit this practice session? Your progress in this session will not be saved.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Stay',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Quit',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    if (shouldQuit == true) {
      _timer?.cancel();
      _submissionDebounceTimer?.cancel();
      _stopRecording();
      try {
        _flutterTts.stop();
      } catch (_) {}
      if (PracticeTab.confirmExitActiveSession == _confirmQuitSession) {
        PracticeTab.confirmExitActiveSession = null;
      }
      if (mounted) {
        setState(() => _selectedDifficulty = null);
      }
      return true;
    }
    return false;
  }

  Widget _buildGameOver() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _sessionWords.length;
    final pct = total > 0 ? ((_score / total) * 100).round() : 0;

    String tierTitle;
    String tierSubtitle;
    Color tierColor;

    if (pct == 100) {
      tierTitle = 'Pronunciation Royalty!';
      tierSubtitle = 'Flawless articulation! Your accent and clarity match native standards!';
      tierColor = const Color(0xFFF59E0B);
    } else if (pct >= 80) {
      tierTitle = 'Outstanding Voice & Clarity!';
      tierSubtitle = 'Superb speech clarity! You sound confident, natural, and expressive!';
      tierColor = const Color(0xFF10B981);
    } else if (pct >= 50) {
      tierTitle = 'Great Vocal Practice!';
      tierSubtitle = 'Solid pronunciation flow! A few more rounds will get you to 100%!';
      tierColor = const Color(0xFF3B82F6);
    } else {
      tierTitle = 'Vocal Journey Begins!';
      tierSubtitle = 'Speaking is a muscle that strengthens with every word. Let\'s try again!';
      tierColor = const Color(0xFF8B5CF6);
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
                                  '${_formatScore(_score)} / $total',
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
                  final cleanUser = userAnswer != null
                      ? _normalizeWord(_filterProfanity(userAnswer.trim().toLowerCase()))
                      : '';
                  final cleanTarget = _normalizeWord(wordObj.word);
                  final isCorrect = cleanUser.isNotEmpty && cleanUser == cleanTarget;
                  double similarity = 0;
                  if (cleanUser.isNotEmpty) {
                    similarity = isCorrect
                        ? 1.0
                        : StringSimilarity.compareTwoStrings(cleanUser, cleanTarget).clamp(0.0, 0.99);
                  }

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
                                  if (index < _hintUsedPerWord.length && _hintUsedPerWord[index]) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.2 : 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        'Hint (-50%)',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    isCorrect
                                        ? ((index < _hintUsedPerWord.length && _hintUsedPerWord[index])
                                            ? '+0.5 pts • ${(similarity * 100).round()}% match'
                                            : '+1 pt • ${(similarity * 100).round()}% match')
                                        : '${(similarity * 100).round()}% match',
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
  final bool isCompact;

  const _DifficultyCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.themeColor,
    required this.onTap,
    this.isCompact = false,
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
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 16 : 24,
              vertical: widget.isCompact ? 14 : 28,
            ),
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
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.tag,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: widget.themeColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                SizedBox(height: widget.isCompact ? 12 : 20),

                // Icon Box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: widget.isCompact ? 52 : 68,
                  height: widget.isCompact ? 52 : 68,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? widget.themeColor
                        : widget.themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: _hovered ? Colors.white : widget.themeColor,
                    size: widget.isCompact ? 26 : 32,
                  ),
                ),
                SizedBox(height: widget.isCompact ? 10 : 18),

                // Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: widget.isCompact ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: widget.isCompact ? 4 : 8),

                // Subtitle / Description
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: widget.isCompact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: widget.isCompact ? 12 : 13.5,
                    height: 1.4,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: widget.isCompact ? 14 : 22),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: widget.isCompact ? 38 : 44,
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
                              fontSize: widget.isCompact ? 13 : 14,
                              fontWeight: FontWeight.w700,
                              color: _hovered
                                  ? Colors.white
                                  : widget.themeColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
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




