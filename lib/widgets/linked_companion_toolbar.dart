import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/notebook_models.dart';
import '../models/published_content_item.dart';
import '../services/database_service.dart';
import '../services/navigation_service.dart';
import '../theme/app_colors.dart';

/// Identifies the active content viewer embedding the toolbar.
enum CompanionMediaType {
  lesson,
  quiz,
  publishedItem,
}

/// Interactive bottom toolbar that links all content generated together within
/// the same AI Notebook (Lessons, Quizzes, Flashcards, Mind Maps, Study Guides, etc.).
///
/// Automatically queries companion materials and provides seamless one-tap switching
/// between study media while maintaining zero-overflow responsive design.
class LinkedCompanionToolbar extends StatefulWidget {
  final User? user;
  final String? notebookId;
  final Lesson? currentLesson;
  final Quiz? currentQuiz;
  final PublishedContentItem? currentPublishedItem;
  final String? currentContentId;
  final CompanionMediaType? activeType;
  final Future<bool> Function()? onBeforeNavigate;

  const LinkedCompanionToolbar({
    super.key,
    this.user,
    this.notebookId,
    this.currentLesson,
    this.currentQuiz,
    this.currentPublishedItem,
    this.currentContentId,
    this.activeType,
    this.onBeforeNavigate,
  });

  @override
  State<LinkedCompanionToolbar> createState() => _LinkedCompanionToolbarState();
}

class _LinkedCompanionToolbarState extends State<LinkedCompanionToolbar> {
  Future<LinkedContentBundle>? _bundleFuture;

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  @override
  void didUpdateWidget(covariant LinkedCompanionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notebookId != widget.notebookId ||
        oldWidget.currentLesson?.id != widget.currentLesson?.id ||
        oldWidget.currentQuiz?.id != widget.currentQuiz?.id ||
        oldWidget.currentPublishedItem?.id != widget.currentPublishedItem?.id) {
      _loadBundle();
    }
  }

  void _loadBundle() {
    _bundleFuture = DatabaseService.instance.getLinkedContentBundle(
      notebookId: widget.notebookId,
      currentLesson: widget.currentLesson,
      currentQuiz: widget.currentQuiz,
      currentPublishedItem: widget.currentPublishedItem,
    );
  }

  Color _getTypeColor(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.mindMap:
        return const Color(0xFFEC4899);
      case NotebookOutputType.flashcards:
        return const Color(0xFF3B82F6);
      case NotebookOutputType.quiz:
        return const Color(0xFFF59E0B);
      case NotebookOutputType.lesson:
        return AppColors.primary;
      case NotebookOutputType.studyGuide:
        return const Color(0xFF10B981);
      case NotebookOutputType.timeline:
        return const Color(0xFF8B5CF6);
      case NotebookOutputType.briefing:
        return const Color(0xFF14B8A6);
      case NotebookOutputType.faq:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getTypeIcon(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.mindMap:
        return Icons.hub_rounded;
      case NotebookOutputType.flashcards:
        return Icons.style_rounded;
      case NotebookOutputType.quiz:
        return Icons.quiz_rounded;
      case NotebookOutputType.lesson:
        return Icons.menu_book_rounded;
      case NotebookOutputType.studyGuide:
        return Icons.auto_stories_rounded;
      case NotebookOutputType.timeline:
        return Icons.timeline_rounded;
      case NotebookOutputType.briefing:
        return Icons.article_rounded;
      case NotebookOutputType.faq:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<LinkedContentBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (widget.notebookId == null &&
              widget.currentLesson?.notebookId == null &&
              widget.currentQuiz?.notebookId == null &&
              widget.currentPublishedItem?.notebookId == null &&
              widget.currentLesson?.quizId == null) {
            return const SizedBox.shrink();
          }
          return Container(
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262626) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 80,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final bundle = snapshot.data!;
        // If there are no companion items to switch between, hide the toolbar
        if (!bundle.hasMultipleItems) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF262626) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Leading label badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.layers_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Bundle',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Horizontal scrollable companion items
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // 1. Lesson Item
                          if (bundle.lesson != null)
                            _buildPill(
                              context: context,
                              isDark: isDark,
                              label: 'Lesson',
                              icon: Icons.menu_book_rounded,
                              color: AppColors.primary,
                              isActive: (widget.activeType == CompanionMediaType.lesson) ||
                                  (widget.activeType == null &&
                                      widget.currentLesson != null &&
                                      widget.currentQuiz == null &&
                                      widget.currentPublishedItem == null &&
                                      widget.currentLesson!.id == bundle.lesson!.id),
                              onTap: () {
                                NavigationService.instance.goToLesson(
                                  context,
                                  bundle.lesson!,
                                  replace: true,
                                );
                              },
                            ),

                          // 2. Quiz Item
                          if (bundle.quiz != null)
                            _buildPill(
                              context: context,
                              isDark: isDark,
                              label: 'Quiz',
                              icon: Icons.quiz_rounded,
                              color: const Color(0xFFF5A623),
                              isActive: (widget.activeType == CompanionMediaType.quiz) ||
                                  (widget.activeType == null &&
                                      widget.currentQuiz != null &&
                                      widget.currentQuiz!.id == bundle.quiz!.id),
                              onTap: () {
                                NavigationService.instance.goToQuiz(
                                  context,
                                  bundle.quiz!,
                                  notebookId: bundle.notebookId,
                                  lesson: bundle.lesson,
                                  replace: true,
                                );
                              },
                            ),

                          // 3. Published Output Items (Flashcards, Mind Map, Study Guide, Timeline, etc.)
                          ...bundle.publishedItems.map((item) {
                            final color = _getTypeColor(item.type);
                            final icon = _getTypeIcon(item.type);
                            final isActive = (widget.activeType == CompanionMediaType.publishedItem &&
                                    (widget.currentPublishedItem?.id == item.id ||
                                        (widget.currentContentId != null &&
                                            (widget.currentContentId == item.id ||
                                                widget.currentContentId == item.outputId)))) ||
                                (widget.activeType == null &&
                                    widget.currentPublishedItem != null &&
                                    widget.currentPublishedItem!.id == item.id);

                            return _buildPill(
                              context: context,
                              isDark: isDark,
                              label: item.type.displayName,
                              icon: icon,
                              color: color,
                              isActive: isActive,
                              onTap: () {
                                NavigationService.instance.goToContent(
                                  context,
                                  item,
                                  replace: true,
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required bool isDark,
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive
              ? null
              : () async {
                  if (widget.onBeforeNavigate != null) {
                    final canProceed = await widget.onBeforeNavigate!();
                    if (!canProceed || !context.mounted) return;
                  }
                  onTap();
                },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.8)
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isActive ? color : (isDark ? Colors.white70 : AppColors.textSecondary),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? color
                        : (isDark ? Colors.white : AppColors.textPrimary),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar card widget that displays each companion material in a lesson bundle
/// as an individual stacked card box with a button at the bottom.
class LinkedCompanionSidebar extends StatefulWidget {
  final User? user;
  final String? notebookId;
  final Lesson? currentLesson;
  final Quiz? currentQuiz;
  final PublishedContentItem? currentPublishedItem;
  final String? currentContentId;
  final CompanionMediaType? activeType;
  final Future<bool> Function()? onBeforeNavigate;
  final bool excludeLesson;
  final bool excludeQuiz;

  const LinkedCompanionSidebar({
    super.key,
    this.user,
    this.notebookId,
    this.currentLesson,
    this.currentQuiz,
    this.currentPublishedItem,
    this.currentContentId,
    this.activeType,
    this.onBeforeNavigate,
    this.excludeLesson = false,
    this.excludeQuiz = false,
  });

  @override
  State<LinkedCompanionSidebar> createState() => _LinkedCompanionSidebarState();
}

class _LinkedCompanionSidebarState extends State<LinkedCompanionSidebar> {
  Future<LinkedContentBundle>? _bundleFuture;

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  @override
  void didUpdateWidget(covariant LinkedCompanionSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notebookId != widget.notebookId ||
        oldWidget.currentLesson?.id != widget.currentLesson?.id ||
        oldWidget.currentQuiz?.id != widget.currentQuiz?.id ||
        oldWidget.currentPublishedItem?.id != widget.currentPublishedItem?.id) {
      _loadBundle();
    }
  }

  void _loadBundle() {
    _bundleFuture = DatabaseService.instance.getLinkedContentBundle(
      notebookId: widget.notebookId,
      currentLesson: widget.currentLesson,
      currentQuiz: widget.currentQuiz,
      currentPublishedItem: widget.currentPublishedItem,
    );
  }

  Color _getTypeColor(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.mindMap:
        return const Color(0xFFEC4899);
      case NotebookOutputType.flashcards:
        return const Color(0xFF3B82F6);
      case NotebookOutputType.quiz:
        return const Color(0xFFF59E0B);
      case NotebookOutputType.lesson:
        return AppColors.primary;
      case NotebookOutputType.studyGuide:
        return const Color(0xFF10B981);
      case NotebookOutputType.timeline:
        return const Color(0xFF8B5CF6);
      case NotebookOutputType.briefing:
        return const Color(0xFF14B8A6);
      case NotebookOutputType.faq:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getTypeIcon(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.mindMap:
        return Icons.hub_rounded;
      case NotebookOutputType.flashcards:
        return Icons.style_rounded;
      case NotebookOutputType.quiz:
        return Icons.quiz_rounded;
      case NotebookOutputType.lesson:
        return Icons.menu_book_rounded;
      case NotebookOutputType.studyGuide:
        return Icons.auto_stories_rounded;
      case NotebookOutputType.timeline:
        return Icons.timeline_rounded;
      case NotebookOutputType.briefing:
        return Icons.article_rounded;
      case NotebookOutputType.faq:
        return Icons.help_outline_rounded;
    }
  }

  String _getButtonLabel(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.flashcards:
        return 'Open Flashcards';
      case NotebookOutputType.mindMap:
        return 'Open Mind Map';
      case NotebookOutputType.studyGuide:
        return 'Open Study Guide';
      case NotebookOutputType.timeline:
        return 'Open Timeline';
      case NotebookOutputType.briefing:
        return 'Open Briefing';
      case NotebookOutputType.faq:
        return 'Open FAQs';
      case NotebookOutputType.quiz:
        return 'Take Quiz';
      case NotebookOutputType.lesson:
        return 'Read Lesson';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<LinkedContentBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final bundle = snapshot.data!;
        if (bundle.isEmpty) {
          return const SizedBox.shrink();
        }

        final List<Widget> cardWidgets = [];

        // 1. Lesson Card (if not excluded)
        if (bundle.lesson != null && !widget.excludeLesson) {
          final isLessonActive = (widget.activeType == CompanionMediaType.lesson) ||
              (widget.activeType == null &&
                  widget.currentLesson != null &&
                  widget.currentQuiz == null &&
                  widget.currentPublishedItem == null &&
                  widget.currentLesson!.id == bundle.lesson!.id);

          cardWidgets.add(
            _buildCompanionCard(
              context: context,
              isDark: isDark,
              cardTitle: bundle.lesson!.title,
              subtitle: 'Interactive Lesson',
              buttonText: 'Read Lesson',
              icon: Icons.menu_book_rounded,
              color: AppColors.primary,
              isActive: isLessonActive,
              onTap: () {
                NavigationService.instance.goToLesson(
                  context,
                  bundle.lesson!,
                  replace: true,
                );
              },
            ),
          );
        }

        // 2. Quiz Card (if not excluded)
        if (bundle.quiz != null && !widget.excludeQuiz) {
          final isQuizActive = (widget.activeType == CompanionMediaType.quiz) ||
              (widget.activeType == null &&
                  widget.currentQuiz != null &&
                  widget.currentQuiz!.id == bundle.quiz!.id);

          cardWidgets.add(
            _buildCompanionCard(
              context: context,
              isDark: isDark,
              cardTitle: bundle.quiz!.title.isNotEmpty ? bundle.quiz!.title : 'Knowledge Quiz',
              subtitle: 'Assessment & Quiz',
              buttonText: 'Take Quiz',
              icon: Icons.quiz_rounded,
              color: const Color(0xFFF59E0B),
              isActive: isQuizActive,
              onTap: () {
                NavigationService.instance.goToQuiz(
                  context,
                  bundle.quiz!,
                  notebookId: bundle.notebookId,
                  lesson: bundle.lesson,
                  replace: true,
                );
              },
            ),
          );
        }

        // 3. Published Items (Flashcards, Mind Map, Study Guide, Timeline, Briefing, FAQ)
        for (final item in bundle.publishedItems) {
          final color = _getTypeColor(item.type);
          final icon = _getTypeIcon(item.type);
          final buttonText = _getButtonLabel(item.type);
          final isActive = (widget.activeType == CompanionMediaType.publishedItem &&
                  (widget.currentPublishedItem?.id == item.id ||
                      (widget.currentContentId != null &&
                          (widget.currentContentId == item.id ||
                              widget.currentContentId == item.outputId)))) ||
              (widget.activeType == null &&
                  widget.currentPublishedItem != null &&
                  widget.currentPublishedItem!.id == item.id);

          cardWidgets.add(
            _buildCompanionCard(
              context: context,
              isDark: isDark,
              cardTitle: item.title,
              subtitle: item.type.displayName,
              buttonText: buttonText,
              icon: icon,
              color: color,
              isActive: isActive,
              onTap: () {
                NavigationService.instance.goToContent(
                  context,
                  item,
                  replace: true,
                );
              },
            ),
          );
        }

        if (cardWidgets.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cardWidgets,
        );
      },
    );
  }

  Widget _buildCompanionCard({
    required BuildContext context,
    required bool isDark,
    required String cardTitle,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final cardBg = isDark ? const Color(0xFF262626) : Colors.white;
    final cardBorder = isActive
        ? color.withValues(alpha: 0.6)
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardBorder,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: isActive ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 10, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    'ACTIVE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isActive
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility_rounded,
                              size: 16,
                              color: isDark ? Colors.white60 : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Currently Open',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (widget.onBeforeNavigate != null) {
                          final canProceed = await widget.onBeforeNavigate!();
                          if (!canProceed || !context.mounted) return;
                        }
                        onTap();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        buttonText,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
