import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/flashcard_models.dart';
import '../../models/notebook_models.dart';
import '../../services/notebook_service.dart';
import '../../services/spaced_repetition_service.dart';
import '../../theme/app_colors.dart';
import 'flashcard_deck_viewer.dart';
import 'flashcard_study_page.dart';

/// Learner-facing page listing shared AI flashcard decks from educators,
/// with real-time SM-2 review statuses and study launch buttons.
class LearnerDecksPage extends StatelessWidget {
  final User user;
  final VoidCallback onBack;

  const LearnerDecksPage({
    super.key,
    required this.user,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131812) : AppColors.backgroundBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text(
          'AI Study Decks',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<NotebookOutput>>(
        stream: NotebookService.instance.streamSharedFlashcardDecks(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final outputs = snapshot.data ?? [];

          if (outputs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.style_rounded,
                        size: 50,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No study decks shared yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When your educators publish flashcard decks from their AI Notebooks, they will automatically appear here for your spaced repetition practice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: outputs.length,
            itemBuilder: (context, index) {
              final output = outputs[index];
              final deck = FlashcardDeck.fromNotebookOutput(output);

              return _buildDeckCard(context, deck, output, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildDeckCard(
    BuildContext context,
    FlashcardDeck deck,
    NotebookOutput output,
    bool isDark,
  ) {
    return FutureBuilder<Map<String, FlashcardProgress>>(
      future: SpacedRepetitionService.instance.getDeckProgress(user.uid, deck.id),
      builder: (context, snapshot) {
        final progressMap = snapshot.data ?? {};

        int dueCount = 0;
        int masteredCount = 0;

        for (final card in deck.cards) {
          final prog = progressMap[card.id];
          if (prog == null || prog.isDue) {
            dueCount++;
          }
          if (prog?.isMastered == true) {
            masteredCount++;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E261D) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.style_rounded,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        if (deck.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            deck.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics row
              Row(
                children: [
                  _buildTag('${deck.totalCards} cards', Colors.blue, isDark),
                  const SizedBox(width: 8),
                  if (dueCount > 0)
                    _buildTag('$dueCount due today', Colors.orange, isDark)
                  else
                    _buildTag('All caught up!', Colors.green, isDark),
                  const SizedBox(width: 8),
                  if (masteredCount > 0)
                    _buildTag('$masteredCount mastered', AppColors.primary, isDark),
                ],
              ),
              const SizedBox(height: 18),

              // Actions
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FlashcardDeckViewer(
                            deck: deck,
                            notebookId: output.notebookId,
                            isSharedView: true,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Browse Cards'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: deck.cards.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FlashcardStudyPage(deck: deck),
                                ),
                              );
                            },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        dueCount > 0 ? 'Study Due ($dueCount)' : 'Study All',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
