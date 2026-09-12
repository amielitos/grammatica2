import 'package:flutter/material.dart';
import '../../models/flashcard_models.dart';
import '../../services/auth_service.dart';
import '../../services/spaced_repetition_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notebook/flashcard_widget.dart';
import 'flashcard_study_page.dart';

import 'publish_content_dialogs.dart';

/// Deck preview and card browser page, providing deck mastery stats
/// and the primary launchpad into spaced-repetition study sessions.
class FlashcardDeckViewer extends StatefulWidget {
  final FlashcardDeck deck;
  final String notebookId;
  final bool isLearnerView;

  const FlashcardDeckViewer({
    super.key,
    required this.deck,
    required this.notebookId,
    bool? isLearnerView,
    bool isSharedView = false,
  }) : isLearnerView = isLearnerView ?? isSharedView;

  @override
  State<FlashcardDeckViewer> createState() => _FlashcardDeckViewerState();
}

class _FlashcardDeckViewerState extends State<FlashcardDeckViewer> {
  String _selectedTag = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = AuthService.instance.currentUser?.uid ?? '';

    final allTags = <String>{'All'};
    for (final card in widget.deck.cards) {
      allTags.addAll(card.tags);
    }

    final filteredCards = widget.deck.cards.where((card) {
      final matchesTag = _selectedTag == 'All' || card.tags.contains(_selectedTag);
      final matchesQuery = _searchQuery.isEmpty ||
          card.front.toLowerCase().contains(_searchQuery) ||
          card.back.toLowerCase().contains(_searchQuery);
      return matchesTag && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131812) : AppColors.backgroundBase,
      appBar: AppBar(
        title: Text(
          widget.deck.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!widget.isLearnerView)
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined),
              tooltip: 'Publish to Curriculum',
              onPressed: () => _publishDeckDialog(context),
            ),
        ],
      ),
      body: StreamBuilder<Map<String, FlashcardProgress>>(
        stream: SpacedRepetitionService.instance.streamDeckProgress(
          currentUid,
          widget.deck.id,
        ),
        builder: (context, snapshot) {
          final progressMap = snapshot.data ?? {};

          int masteredCount = 0;
          int learningCount = 0;
          int dueCount = 0;

          for (final card in widget.deck.cards) {
            final prog = progressMap[card.id];
            if (prog == null) {
              dueCount++;
            } else if (prog.isMastered) {
              masteredCount++;
            } else if (prog.isLearning) {
              learningCount++;
              if (prog.isDue) dueCount++;
            } else if (prog.isDue) {
              dueCount++;
            }
          }

          return Column(
            children: [
              // Mastery Stats Header Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                        const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.25 : 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Total Cards', '${widget.deck.totalCards}', Colors.blue, isDark),
                          _buildStatItem('Due Today', '$dueCount', Colors.orange, isDark),
                          _buildStatItem('Learning', '$learningCount', Colors.purple, isDark),
                          _buildStatItem('Mastered', '$masteredCount', AppColors.primary, isDark),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.deck.cards.isEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FlashcardStudyPage(
                                        deck: widget.deck,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: Text(
                            dueCount > 0
                                ? 'Study Due Cards ($dueCount)'
                                : 'Study All Cards (${widget.deck.totalCards})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
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
                    ],
                  ),
                ),
              ),

              // Search & Filter row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search cards in deck...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F281E) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tag Filter chips
              if (allTags.length > 1)
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: allTags.map((tag) {
                      final isSelected = _selectedTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedTag = tag),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.textPrimary),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 10),

              // Cards Grid
              Expanded(
                child: filteredCards.isEmpty
                    ? Center(
                        child: Text(
                          'No cards match filter',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                        itemCount: filteredCards.length,
                        itemBuilder: (context, index) {
                          final card = filteredCards[index];
                          final progress = progressMap[card.id];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Stack(
                              children: [
                                FlashcardWidget(card: card),
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: _buildProgressPill(progress, isDark),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressPill(FlashcardProgress? progress, bool isDark) {
    if (progress == null) {
      return _pill('NEW', Colors.blue);
    }
    if (progress.isMastered) {
      return _pill('MASTERED', AppColors.primary);
    }
    if (progress.isDue) {
      return _pill('DUE', Colors.orange);
    }
    return _pill('IN ${progress.interval}d', Colors.purple);
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _publishDeckDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PublishContentDialog(
        notebookId: widget.notebookId,
        output: widget.deck.toNotebookOutput(),
        onPublished: () {
          setState(() {});
        },
      ),
    );
  }
}
