import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../theme/app_colors.dart';
import '../../services/ai_service.dart';
import '../../models/spelling_word.dart';

/// AI Vocabulary / Spelling Studio tab — generates words by difficulty,
/// displays them as interactive flashcards with TTS pronunciation.
class AiSpellingStudioTab extends StatefulWidget {
  const AiSpellingStudioTab({super.key});

  @override
  State<AiSpellingStudioTab> createState() => _AiSpellingStudioTabState();
}

class _AiSpellingStudioTabState extends State<AiSpellingStudioTab>
    with AutomaticKeepAliveClientMixin {
  final FlutterTts _tts = FlutterTts();

  SpellingDifficulty _selectedDifficulty = SpellingDifficulty.amateur;
  int _wordCount = 10;
  List<SpellingWord>? _generatedWords;
  bool _isLoading = false;

  // Flashcard tracking
  int _currentCardIndex = 0;
  final Set<int> _revealedCards = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generateWords() async {
    setState(() {
      _isLoading = true;
      _generatedWords = null;
      _currentCardIndex = 0;
      _revealedCards.clear();
    });

    try {
      final words = await AIService.instance.generateWords(
        count: _wordCount,
        difficulty: _selectedDifficulty,
      );
      setState(() {
        _generatedWords = words;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _speak(String word) async {
    await _tts.speak(word);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 16,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Config card
              _buildConfigCard(isDark),
              const SizedBox(height: 24),

              // Flashcards or loading
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),

              if (_generatedWords != null && _generatedWords!.isNotEmpty) ...[
                _buildFlashcardArea(isDark),
                const SizedBox(height: 20),
                _buildWordGrid(isDark),
              ],

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Config card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildConfigCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spellcheck, size: 24, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Vocabulary Studio',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Generate vocabulary words by difficulty level. Listen to pronunciations and test yourself.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Difficulty selector
          Text(
            'Difficulty',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: SpellingDifficulty.values.map((d) {
              final isSelected = d == _selectedDifficulty;
              Color color;
              switch (d) {
                case SpellingDifficulty.novice:
                  color = Colors.green;
                  break;
                case SpellingDifficulty.amateur:
                  color = Colors.orange;
                  break;
                case SpellingDifficulty.professional:
                  color = Colors.redAccent;
                  break;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(
                    d.name[0].toUpperCase() + d.name.substring(1),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                  onSelected: (_) =>
                      setState(() => _selectedDifficulty = d),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Word count slider
          Row(
            children: [
              Text('Words:',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textPrimary)),
              Expanded(
                child: Slider(
                  value: _wordCount.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 25,
                  label: '$_wordCount',
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _wordCount = v.round()),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$_wordCount',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Generate button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateWords,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                _generatedWords != null ? 'Regenerate' : 'Generate Words',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Flashcard area
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFlashcardArea(bool isDark) {
    final word = _generatedWords![_currentCardIndex];
    final isRevealed = _revealedCards.contains(_currentCardIndex);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2744), const Color(0xFF2A1A44)]
              : [const Color(0xFFE8F5E9), const Color(0xFFF3E5F5)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(
            '${_currentCardIndex + 1} / ${_generatedWords!.length}',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Word display
          GestureDetector(
            onTap: () => setState(
                () => _revealedCards.add(_currentCardIndex)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 40),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    isRevealed ? word.word : '• • •',
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: isRevealed ? 2 : 6,
                    ),
                  ),
                  if (!isRevealed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tap to reveal',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentCardIndex > 0
                    ? () => setState(() => _currentCardIndex--)
                    : null,
                icon: const Icon(Icons.arrow_back_rounded),
                iconSize: 28,
                color: isDark ? Colors.white70 : AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: 'tts',
                mini: true,
                backgroundColor: AppColors.primary,
                onPressed: () => _speak(word.word),
                child: const Icon(Icons.volume_up, color: Colors.white),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed:
                    _currentCardIndex < _generatedWords!.length - 1
                        ? () => setState(() => _currentCardIndex++)
                        : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                iconSize: 28,
                color: isDark ? Colors.white70 : AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Word grid
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWordGrid(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_generatedWords!.length, (i) {
        final word = _generatedWords![i];
        final isActive = i == _currentCardIndex;
        final isRevealed = _revealedCards.contains(i);

        return ActionChip(
          label: Text(
            isRevealed ? word.word : 'Word ${i + 1}',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.white70 : AppColors.textPrimary),
            ),
          ),
          backgroundColor: isActive
              ? AppColors.primary
              : (isDark ? const Color(0xFF333333) : Colors.grey.shade100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: () => setState(() => _currentCardIndex = i),
        );
      }),
    );
  }
}
