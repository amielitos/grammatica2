import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/flashcard_models.dart';
import '../models/notebook_models.dart';
import '../models/published_content_item.dart';
import '../models/study_guide_models.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import 'notebook/briefing_view.dart';
import 'notebook/faq_view.dart';
import 'notebook/flashcard_study_page.dart';
import 'notebook/mind_map_view.dart';
import 'notebook/study_guide_view.dart';
import 'notebook/timeline_view.dart';
import '../widgets/linked_companion_toolbar.dart';

/// Universal content viewer for all published non-lesson/non-quiz output types
/// (Mind Maps, Flashcards, Study Guides, Timelines, Briefings, FAQs).
///
/// Ensures zero-overflow responsive rendering and integrated learner completion tracking.
class ContentViewerPage extends StatefulWidget {
  final User user;
  final PublishedContentItem? item;
  final NotebookOutput? output;

  const ContentViewerPage({
    super.key,
    required this.user,
    this.item,
    this.output,
  }) : assert(item != null || output != null, 'Either item or output must be provided.');

  @override
  State<ContentViewerPage> createState() => _ContentViewerPageState();
}

class _ContentViewerPageState extends State<ContentViewerPage> {
  late final String _contentId;
  late final NotebookOutputType _type;
  late final String _title;
  late final String? _authorEmail;
  late final bool _isGrammaticaContent;
  late final bool _isMembersOnly;
  late final String _notebookId;
  late final String _outputId;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final i = widget.item!;
      _contentId = i.id;
      _type = i.type;
      _title = i.title;
      _authorEmail = i.createdByEmail;
      _isGrammaticaContent = i.isGrammaticaContent;
      _isMembersOnly = i.isMembersOnly;
      _notebookId = i.notebookId ?? '';
      _outputId = i.outputId ?? i.id;
    } else {
      final o = widget.output!;
      _contentId = o.publishedId ?? o.id;
      _type = o.type;
      _title = o.title;
      _authorEmail = null;
      _isGrammaticaContent = o.publishMetadata?['isGrammaticaContent'] as bool? ?? false;
      _isMembersOnly = o.publishMetadata?['isMembersOnly'] as bool? ?? false;
      _notebookId = o.notebookId;
      _outputId = o.id;
    }
  }

  Color _getTypeColor(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.mindMap:
        return const Color(0xFFEC4899);
      case NotebookOutputType.flashcards:
        return const Color(0xFF3B82F6);
      case NotebookOutputType.studyGuide:
        return const Color(0xFF10B981);
      case NotebookOutputType.timeline:
        return const Color(0xFF8B5CF6);
      case NotebookOutputType.briefing:
        return const Color(0xFF14B8A6);
      case NotebookOutputType.faq:
        return const Color(0xFFF59E0B);
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.mindMap:
        return Icons.hub_rounded;
      case NotebookOutputType.flashcards:
        return Icons.style_rounded;
      case NotebookOutputType.studyGuide:
        return Icons.menu_book_rounded;
      case NotebookOutputType.timeline:
        return Icons.timeline_rounded;
      case NotebookOutputType.briefing:
        return Icons.assignment_rounded;
      case NotebookOutputType.faq:
        return Icons.help_outline_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Widget _buildContentWidget(BuildContext context, bool isDark) {
    switch (_type) {
      case NotebookOutputType.mindMap:
        final mm = widget.item != null
            ? widget.item!.mindMap
            : MindMap.fromNotebookOutput(widget.output!);
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: MindMapView(
            mindMap: mm,
            notebookId: _notebookId,
            outputId: _outputId,
            isLearnerView: true,
          ),
        );

      case NotebookOutputType.flashcards:
        final deck = widget.item != null
            ? widget.item!.flashcardDeck
            : FlashcardDeck.fromNotebookOutput(widget.output!);
        return _buildFlashcardsDeckView(context, deck, isDark);

      case NotebookOutputType.studyGuide:
        final sg = widget.item != null
            ? widget.item!.studyGuide
            : StudyGuide.fromNotebookOutput(widget.output!);
        return StudyGuideView(
          guide: sg,
          notebookId: _notebookId,
          outputId: _outputId,
          isLearnerView: true,
        );

      case NotebookOutputType.timeline:
        final tl = widget.item != null
            ? widget.item!.timeline
            : Timeline.fromNotebookOutput(widget.output!);
        return TimelineView(
          timeline: tl,
          notebookId: _notebookId,
          outputId: _outputId,
          isLearnerView: true,
        );

      case NotebookOutputType.briefing:
        final br = widget.item != null
            ? widget.item!.briefing
            : Briefing.fromNotebookOutput(widget.output!);
        return BriefingView(
          briefing: br,
          notebookId: _notebookId,
          outputId: _outputId,
          isLearnerView: true,
        );

      case NotebookOutputType.faq:
        final fq = widget.item != null
            ? widget.item!.faq
            : FAQ.fromNotebookOutput(widget.output!);
        return FAQView(
          faq: fq,
          notebookId: _notebookId,
          outputId: _outputId,
          isLearnerView: true,
        );

      default:
        return Center(
          child: Text(
            'Unknown content type',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        );
    }
  }

  Widget _buildFlashcardsDeckView(BuildContext context, FlashcardDeck deck, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E261D) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.style_rounded, color: Color(0xFF3B82F6), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deck.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${deck.totalCards} Flashcards • Spaced Repetition Practice',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (deck.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    deck.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
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
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      'Launch Spaced Repetition Study',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Cards Preview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: deck.cards.length,
            itemBuilder: (context, idx) {
              final card = deck.cards[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E261D) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${idx + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            card.front,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      card.back,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(_type);
    final typeIcon = _getTypeIcon(_type);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131812) : AppColors.backgroundBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(typeIcon, color: typeColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _title,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Completion status button synced with Firestore progress
          StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: DatabaseService.instance.progressStream(widget.user),
            builder: (context, snapshot) {
              final progressMap = snapshot.data ?? {};
              final isCompleted = progressMap[_contentId]?['completed'] == true;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: () async {
                    await DatabaseService.instance.markContentCompleted(
                      user: widget.user,
                      contentId: _contentId,
                      completed: !isCompleted,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            !isCompleted
                                ? 'Marked as completed! Great progress! 🎉'
                                : 'Marked as incomplete.',
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: !isCompleted ? const Color(0xFF10B981) : Colors.black87,
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.black54),
                    size: 18,
                  ),
                  label: Text(
                    isCompleted ? 'Completed' : 'Mark Done',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner with metadata
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, color: typeColor, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            _type.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isGrammaticaContent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8B84B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: Color(0xFFE8B84B), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'GRAMMATICA OFFICIAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8B84B),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_authorEmail != null && _authorEmail.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline_rounded,
                                color: isDark ? Colors.white60 : Colors.black54, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'By: $_authorEmail',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isMembersOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, color: Color(0xFF9B59B6), size: 13),
                            SizedBox(width: 4),
                            Text(
                              'MEMBERS ONLY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B59B6),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Main Viewer Container
              Expanded(
                child: _type == NotebookOutputType.mindMap
                    ? _buildContentWidget(context, isDark)
                    : SingleChildScrollView(
                        child: _buildContentWidget(context, isDark),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: LinkedCompanionToolbar(
        user: widget.user,
        notebookId: _notebookId.isNotEmpty ? _notebookId : widget.item?.notebookId,
        currentPublishedItem: widget.item,
        currentContentId: _contentId,
        activeType: CompanionMediaType.publishedItem,
      ),
    );
  }
}
