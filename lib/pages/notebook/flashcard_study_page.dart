import 'package:flutter/material.dart';
import '../../models/flashcard_models.dart';
import '../../services/auth_service.dart';
import '../../services/spaced_repetition_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notebook/flashcard_widget.dart';

/// Full-screen active recall flashcard study interface powered by the SM-2
/// spaced repetition algorithm.
class FlashcardStudyPage extends StatefulWidget {
  final FlashcardDeck deck;

  const FlashcardStudyPage({
    super.key,
    required this.deck,
  });

  @override
  State<FlashcardStudyPage> createState() => _FlashcardStudyPageState();
}

class _FlashcardStudyPageState extends State<FlashcardStudyPage> {
  final GlobalKey<FlashcardWidgetState> _cardKey = GlobalKey<FlashcardWidgetState>();

  int _currentIndex = 0;
  bool _isAnswerRevealed = false;
  final DateTime _sessionStart = DateTime.now();

  final Map<String, FlashcardProgress> _progressMap = {};
  int _cardsStudied = 0;
  int _cardsCorrect = 0;
  double _totalQuality = 0;
  bool _isSessionFinished = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final progress = await SpacedRepetitionService.instance.getDeckProgress(
      uid,
      widget.deck.id,
    );
    if (mounted) {
      setState(() {
        _progressMap.addAll(progress);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.deck.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Session')),
        body: const Center(child: Text('This deck contains no cards.')),
      );
    }

    if (_isSessionFinished) {
      return _buildFinishedView(isDark);
    }

    final card = widget.deck.cards[_currentIndex];
    final progress = _progressMap[card.id];
    final total = widget.deck.cards.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111710) : const Color(0xFFF3F6F2),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.deck.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Card ${_currentIndex + 1} of $total',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress line
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / total,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
            ),

            const Spacer(),

            // Interactive 3D Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FlashcardWidget(
                key: _cardKey,
                card: card,
                onFlipped: () {
                  setState(() {
                    _isAnswerRevealed = !_cardKey.currentState!.isFront;
                  });
                },
              ),
            ),

            const Spacer(),

            // Review buttons (Revealed once answer is shown)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _isAnswerRevealed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _cardKey.currentState?.flip();
                    },
                    icon: const Icon(Icons.touch_app_rounded, size: 20),
                    label: const Text('Show Answer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    Text(
                      'Rate your recall difficulty:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildQualityButton(
                          label: 'Again',
                          intervalDesc: '<10 min',
                          quality: 1,
                          color: const Color(0xFFE53935),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildQualityButton(
                          label: 'Hard',
                          intervalDesc: _estimateInterval(progress, 2),
                          quality: 2,
                          color: const Color(0xFFFB8C00),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildQualityButton(
                          label: 'Good',
                          intervalDesc: _estimateInterval(progress, 4),
                          quality: 4,
                          color: AppColors.primary,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildQualityButton(
                          label: 'Easy',
                          intervalDesc: _estimateInterval(progress, 5),
                          quality: 5,
                          color: const Color(0xFF1E88E5),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityButton({
    required String label,
    required String intervalDesc,
    required int quality,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleRating(quality),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  intervalDesc,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _estimateInterval(FlashcardProgress? prog, int quality) {
    if (prog == null) {
      if (quality == 2) return '1 day';
      if (quality == 4) return '1 day';
      return '3 days';
    }
    if (quality < 3) return '1 day';
    if (prog.repetitions == 0) return '1 day';
    if (prog.repetitions == 1) return '6 days';
    final est = (prog.interval * prog.easeFactor).round();
    return '$est days';
  }

  Future<void> _handleRating(int quality) async {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final card = widget.deck.cards[_currentIndex];
    final currentProg = _progressMap[card.id];

    _cardsStudied++;
    if (quality >= 3) _cardsCorrect++;
    _totalQuality += quality;

    // Save SM-2 progress asynchronously
    SpacedRepetitionService.instance.reviewCard(
      cardId: card.id,
      deckId: widget.deck.id,
      userId: uid,
      quality: quality,
      currentProgress: currentProg,
    ).then((updated) {
      _progressMap[card.id] = updated;
    });

    if (_currentIndex + 1 < widget.deck.cards.length) {
      setState(() {
        _currentIndex++;
        _isAnswerRevealed = false;
      });
    } else {
      _finishSession();
    }
  }

  void _finishSession() {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final session = StudySession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      deckId: widget.deck.id,
      userId: uid,
      startedAt: _sessionStart,
      endedAt: DateTime.now(),
      cardsStudied: _cardsStudied,
      cardsCorrect: _cardsCorrect,
      averageQuality: _cardsStudied > 0 ? _totalQuality / _cardsStudied : 0.0,
    );

    SpacedRepetitionService.instance.logStudySession(session);

    setState(() {
      _isSessionFinished = true;
    });
  }

  Widget _buildFinishedView(bool isDark) {
    final accuracy = _cardsStudied > 0 ? ((_cardsCorrect / _cardsStudied) * 100).round() : 100;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111710) : AppColors.backgroundBase,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 54,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Session Complete!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You practiced $_cardsStudied cards with $accuracy% recall accuracy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 0;
                        _isAnswerRevealed = false;
                        _isSessionFinished = false;
                        _cardsStudied = 0;
                        _cardsCorrect = 0;
                        _totalQuality = 0;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Practice Again'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Back to Deck'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
