import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ai_models.dart';
import '../../models/flashcard_models.dart';
import '../../models/notebook_models.dart';
import '../../models/study_guide_models.dart';
import '../../services/ai_generation_service.dart';
import '../../services/notebook_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notebook/generation_loading_overlay.dart';
import '../../widgets/notebook/output_toolbar.dart';
import '../../widgets/notebook/source_upload_panel.dart';
import 'briefing_view.dart';
import 'faq_view.dart';
import 'flashcard_deck_viewer.dart';
import 'lesson_view.dart';
import 'mind_map_view.dart';
import 'publish_content_dialogs.dart';
import 'study_guide_view.dart';
import 'timeline_view.dart';
import 'presentation_view.dart';
import '../../services/ai_rate_limit_service.dart';
import '../../widgets/ai_quota_badge.dart';
import '../../widgets/ai_quota_exceeded_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Main interactive workspace for a Notebook, featuring a split-pane layout
/// inspired by NotebookLM with sources panel, output workspace, and output toolbar.
class NotebookDetailPage extends StatefulWidget {
  final String notebookId;

  const NotebookDetailPage({
    super.key,
    required this.notebookId,
  });

  @override
  State<NotebookDetailPage> createState() => _NotebookDetailPageState();
}

class _NotebookDetailPageState extends State<NotebookDetailPage> {
  NotebookSource? _selectedSource;
  NotebookOutputType _selectedOutputType = NotebookOutputType.flashcards;

  bool _isGenerating = false;
  String _generationMessage = '';
  bool _isAssessment = false;
  bool _isSourcesCollapsed = false;

  // Mobile tab index: 0 = Sources, 1 = Outputs
  int _mobileTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 850;

    return StreamBuilder<Notebook?>(
      stream: NotebookService.instance.streamNotebook(widget.notebookId),
      builder: (context, notebookSnap) {
        final notebook = notebookSnap.data;

        if (notebookSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (notebook == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Notebook Not Found')),
            body: const Center(child: Text('This notebook could not be loaded.')),
          );
        }

        return StreamBuilder<List<NotebookSource>>(
          stream: NotebookService.instance.streamSources(widget.notebookId),
          builder: (context, sourcesSnap) {
            final sources = sourcesSnap.data ?? [];

            return StreamBuilder<List<NotebookOutput>>(
              stream: NotebookService.instance.streamOutputs(widget.notebookId),
              builder: (context, outputsSnap) {
                final outputs = outputsSnap.data ?? [];

                // Count outputs by type
                final Map<NotebookOutputType, int> outputCounts = {};
                for (final out in outputs) {
                  outputCounts[out.type] = (outputCounts[out.type] ?? 0) + 1;
                }

                // Find active output of selected type
                final activeOutput = outputs.cast<NotebookOutput?>().firstWhere(
                      (o) => o?.type == _selectedOutputType,
                      orElse: () => null,
                    );

                return Stack(
                  children: [
                    Scaffold(
                      backgroundColor: isDark ? const Color(0xFF181818) : AppColors.backgroundBase,
                      appBar: _buildAppBar(context, notebook, isDark, outputs),
                      body: isDesktop
                          ? _buildDesktopLayout(
                              sources: sources,
                              outputs: outputs,
                              outputCounts: outputCounts,
                              activeOutput: activeOutput,
                              isDark: isDark,
                            )
                          : _buildMobileLayout(
                              sources: sources,
                              outputs: outputs,
                              outputCounts: outputCounts,
                              activeOutput: activeOutput,
                              isDark: isDark,
                            ),
                    ),
                    if (_isGenerating)
                      Positioned.fill(
                        child: AbsorbPointer(
                          absorbing: true,
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.92),
                            child: Center(
                              child: GenerationLoadingOverlay(
                                title: 'Generating ${_selectedOutputType.displayName}...',
                                subtitle: _generationMessage,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Notebook notebook,
    bool isDark,
    List<NotebookOutput> outputs,
  ) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF222222) : Colors.white,
      title: InkWell(
        onTap: () => _showRenameDialog(context, notebook),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                notebook.title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: _isSourcesCollapsed ? 'Show Sources Sidebar' : 'Full Screen Workspace',
          icon: Icon(
            _isSourcesCollapsed ? Icons.view_sidebar_rounded : Icons.fullscreen_rounded,
            color: _isSourcesCollapsed ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54),
          ),
          onPressed: () => setState(() => _isSourcesCollapsed = !_isSourcesCollapsed),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: AIQuotaBadge(),
          ),
        ),
        if (outputs.isNotEmpty)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('lessons')
                .where('notebookId', isEqualTo: widget.notebookId)
                .limit(1)
                .snapshots(),
            builder: (context, lessonSnap) {
              final hasFirestoreLesson = (lessonSnap.data?.docs.isNotEmpty ?? false);
              final isUploaded = outputs.any((o) => o.isPublished) || hasFirestoreLesson;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                child: ElevatedButton.icon(
                  icon: Icon(isUploaded ? Icons.update_rounded : Icons.cloud_upload_rounded, size: 16),
                  label: Text(
                    isUploaded ? 'Update' : 'Publish All to Curriculum',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => PublishAllOutputsDialog(
                        notebookId: widget.notebookId,
                        outputs: outputs,
                        onPublishedAll: () => setState(() {}),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDesktopLayout({
    required List<NotebookSource> sources,
    required List<NotebookOutput> outputs,
    required Map<NotebookOutputType, int> outputCounts,
    required NotebookOutput? activeOutput,
    required bool isDark,
  }) {
    return Row(
      children: [
        // Left Column: Source Upload Panel (fixed 320px, collapsible for full-screen)
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _isSourcesCollapsed
              ? const SizedBox.shrink()
              : SizedBox(
                  width: 320,
                  child: SourceUploadPanel(
                    notebookId: widget.notebookId,
                    sources: sources,
                    selectedSource: _selectedSource,
                    onSourceSelected: (s) {
                      setState(() {
                        _selectedSource = (_selectedSource?.id == s.id) ? null : s;
                      });
                    },
                  ),
                ),
        ),

        // Right Column: Active Output Workspace + Bottom Toolbar
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _selectedSource != null
                    ? _buildSourcePreview(_selectedSource!, isDark)
                    : _buildOutputWorkspace(
                        sources: sources,
                        activeOutput: activeOutput,
                        isDark: isDark,
                      ),
              ),
              OutputToolbar(
                hasSources: sources.any((s) => s.processingStatus == SourceProcessingStatus.ready),
                isGenerating: _isGenerating,
                selectedType: _selectedOutputType,
                outputCounts: outputCounts,
                onSelectOutput: (type) {
                  setState(() {
                    _selectedSource = null;
                    _selectedOutputType = type;
                  });
                },
                onGenerateRequested: (type) {
                  final hasExisting = (outputCounts[type] ?? 0) > 0;
                  _confirmAndGenerate(sources, type, hasExistingOutput: hasExisting);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout({
    required List<NotebookSource> sources,
    required List<NotebookOutput> outputs,
    required Map<NotebookOutputType, int> outputCounts,
    required NotebookOutput? activeOutput,
    required bool isDark,
  }) {
    return Column(
      children: [
        // Top Mobile Tab Selector
        Container(
          color: isDark ? const Color(0xFF182017) : Colors.white,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _mobileTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _mobileTabIndex == 0 ? AppColors.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sources (${sources.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _mobileTabIndex == 0 ? AppColors.primary : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _mobileTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _mobileTabIndex == 1 ? AppColors.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'AI Outputs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _mobileTabIndex == 1 ? AppColors.primary : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: _mobileTabIndex == 0
              ? SourceUploadPanel(
                  notebookId: widget.notebookId,
                  sources: sources,
                  selectedSource: _selectedSource,
                  onSourceSelected: (s) {
                    setState(() {
                      _selectedSource = s;
                    });
                  },
                )
              : _buildOutputWorkspace(
                  sources: sources,
                  activeOutput: activeOutput,
                  isDark: isDark,
                ),
        ),

        // Bottom Generation Toolbar
        OutputToolbar(
          hasSources: sources.any((s) => s.processingStatus == SourceProcessingStatus.ready),
          isGenerating: _isGenerating,
          selectedType: _selectedOutputType,
          outputCounts: outputCounts,
          onSelectOutput: (type) {
            setState(() {
              _mobileTabIndex = 1;
              _selectedSource = null;
              _selectedOutputType = type;
            });
          },
          onGenerateRequested: (type) {
            final hasExisting = (outputCounts[type] ?? 0) > 0;
            _confirmAndGenerate(sources, type, hasExistingOutput: hasExisting);
          },
        ),
      ],
    );
  }

  Widget _buildSourcePreview(NotebookSource source, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedSource = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${source.type.displayName} • ${source.wordCount} words extracted',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E261D) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  source.rawContent.isNotEmpty
                      ? source.rawContent
                      : 'No extractable text found in this source.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputWorkspace({
    required List<NotebookSource> sources,
    required NotebookOutput? activeOutput,
    required bool isDark,
  }) {
    if (activeOutput == null) {
      return _buildNoOutputPlaceholder(sources, isDark);
    }

    switch (activeOutput.type) {
      case NotebookOutputType.lesson:
        return LessonView(
          output: activeOutput,
          notebookId: widget.notebookId,
          onRegenerate: () => _confirmAndGenerate(
            sources,
            NotebookOutputType.lesson,
            hasExistingOutput: true,
          ),
          onLessonPublished: (lessonId) {
            setState(() {});
          },
        );

      case NotebookOutputType.flashcards:
        final deck = FlashcardDeck.fromNotebookOutput(activeOutput);
        return FlashcardDeckViewer(
          deck: deck,
          notebookId: widget.notebookId,
          isLearnerView: false,
        );

      case NotebookOutputType.studyGuide:
        final guide = StudyGuide.fromNotebookOutput(activeOutput);
        return StudyGuideView(
          guide: guide,
          notebookId: widget.notebookId,
          outputId: activeOutput.id,
          isLearnerView: false,
        );

      case NotebookOutputType.timeline:
        final timeline = Timeline.fromNotebookOutput(activeOutput);
        return TimelineView(
          timeline: timeline,
          notebookId: widget.notebookId,
          outputId: activeOutput.id,
          isLearnerView: false,
        );

      case NotebookOutputType.briefing:
        final briefing = Briefing.fromNotebookOutput(activeOutput);
        return BriefingView(
          briefing: briefing,
          notebookId: widget.notebookId,
          outputId: activeOutput.id,
          isLearnerView: false,
        );

      case NotebookOutputType.faq:
        final faq = FAQ.fromNotebookOutput(activeOutput);
        return FAQView(
          faq: faq,
          notebookId: widget.notebookId,
          outputId: activeOutput.id,
          isLearnerView: false,
        );

      case NotebookOutputType.mindMap:
        final mindMap = MindMap.fromNotebookOutput(activeOutput);
        return MindMapView(
          mindMap: mindMap,
          notebookId: widget.notebookId,
          outputId: activeOutput.id,
          isLearnerView: false,
        );

      case NotebookOutputType.presentation:
        final pres = Presentation.fromNotebookOutput(activeOutput);
        return PresentationView(
          presentation: pres,
          notebookId: widget.notebookId,
          outputId: activeOutput.id,
          isLearnerView: false,
        );

      case NotebookOutputType.quiz:
        final quiz = AIQuizResponse.fromNotebookOutput(activeOutput);
        return _buildQuizPreview(quiz, activeOutput, isDark, sources);
    }
  }

  Color _getTypeColor(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.lesson:
        return const Color(0xFF10B981);
      case NotebookOutputType.flashcards:
        return const Color(0xFF3B82F6);
      case NotebookOutputType.quiz:
        return const Color(0xFFEF4444);
      case NotebookOutputType.studyGuide:
        return AppColors.primary;
      case NotebookOutputType.timeline:
        return const Color(0xFF8B5CF6);
      case NotebookOutputType.briefing:
        return const Color(0xFF14B8A6);
      case NotebookOutputType.faq:
        return const Color(0xFFF59E0B);
      case NotebookOutputType.mindMap:
        return const Color(0xFFEC4899);
      case NotebookOutputType.presentation:
        return const Color(0xFF6366F1);
    }
  }

  IconData _getTypeIcon(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.lesson:
        return Icons.school_rounded;
      case NotebookOutputType.flashcards:
        return Icons.style_rounded;
      case NotebookOutputType.quiz:
        return Icons.quiz_rounded;
      case NotebookOutputType.studyGuide:
        return Icons.menu_book_rounded;
      case NotebookOutputType.timeline:
        return Icons.timeline_rounded;
      case NotebookOutputType.briefing:
        return Icons.assignment_rounded;
      case NotebookOutputType.faq:
        return Icons.help_outline_rounded;
      case NotebookOutputType.mindMap:
        return Icons.hub_rounded;
      case NotebookOutputType.presentation:
        return Icons.slideshow_rounded;
    }
  }

  String _getTypeDescription(NotebookOutputType type) {
    switch (type) {
      case NotebookOutputType.lesson:
        return 'Generates an interactive, structured lesson with key concepts, rich markdown formatting, and clear pedagogical explanations based on your sources.';
      case NotebookOutputType.flashcards:
        return 'Creates high-yield study flashcards with key terms, definitions, and front/back pairs optimized for active recall.';
      case NotebookOutputType.quiz:
        return 'Generates comprehensive assessment questions with answer keys and explanations based on your ingested source materials.';
      case NotebookOutputType.studyGuide:
        return 'Compiles an in-depth study guide featuring key takeaways, essential vocabulary terms, and chapter-by-chapter summaries.';
      case NotebookOutputType.timeline:
        return 'Constructs a chronological milestone sequence tracking key historical events, steps, or developments.';
      case NotebookOutputType.briefing:
        return 'Synthesizes an executive overview summarizing primary arguments, important takeaways, and critical insights.';
      case NotebookOutputType.faq:
        return 'Answers the most frequently asked questions and foundational concepts extracted from your sources.';
      case NotebookOutputType.mindMap:
        return 'Constructs a visual hierarchical mind map connecting central topics to sub-concepts and branches.';
      case NotebookOutputType.presentation:
        return 'Generates a clean instructional presentation slide deck with key concepts, bulleted takeaways, and speaker notes.';
    }
  }

  Widget _buildNoOutputPlaceholder(List<NotebookSource> sources, bool isDark) {
    final readySources = sources
        .where((s) => s.processingStatus == SourceProcessingStatus.ready && s.rawContent.isNotEmpty)
        .toList();
    final hasSources = readySources.isNotEmpty;
    final color = _getTypeColor(_selectedOutputType);
    final icon = _getTypeIcon(_selectedOutputType);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E261D) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  'Generate ${_selectedOutputType.displayName}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getTypeDescription(_selectedOutputType),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Active Source Badges
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151C14) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasSources ? Icons.check_circle_outline : Icons.info_outline,
                            size: 16,
                            color: hasSources ? const Color(0xFF10B981) : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasSources
                                ? '${readySources.length} Ready Source(s) will be synthesized'
                                : 'No ready sources found',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (hasSources) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: readySources.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_rounded, size: 12, color: color),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_selectedOutputType == NotebookOutputType.quiz) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151C14) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Assessment Style Quiz',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Format questions for formal graded testing instead of study practice.',
                        style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      value: _isAssessment,
                      activeThumbColor: const Color(0xFFEF4444),
                      activeTrackColor: const Color(0xFFEF4444).withValues(alpha: 0.5),
                      onChanged: (v) => setState(() => _isAssessment = v),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Generate button on the middle of application!
                ElevatedButton.icon(
                  onPressed: hasSources
                      ? () => _confirmAndGenerate(
                            sources,
                            _selectedOutputType,
                            hasExistingOutput: false,
                            isAssessment: _isAssessment,
                          )
                      : null,
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: Text('Generate ${_selectedOutputType.displayName}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!hasSources)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Please upload at least one readable document/source to enable generation.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizPreview(
    AIQuizResponse quiz,
    NotebookOutput output,
    bool isDark,
    List<NotebookSource> sources,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quiz.title ?? 'Generated Quiz',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (output.isPublished)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Published to Curriculum',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note, size: 14, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Local Session Draft',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          '${quiz.questions.length} questions • ${quiz.isAssessment ? "Reading Assessment" : "Practice Quiz"}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Regenerate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : AppColors.textPrimary,
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _confirmAndGenerate(
                  sources,
                  NotebookOutputType.quiz,
                  hasExistingOutput: true,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: Icon(output.isPublished ? Icons.cloud_done : Icons.cloud_upload_outlined, size: 18),
                label: Text(output.isPublished ? 'Re-publish' : 'Publish to Curriculum'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => PublishQuizDialog(
                      notebookId: widget.notebookId,
                      output: output,
                      onPublished: () {
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...quiz.questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E261D) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${idx + 1}. ${q.content.isNotEmpty ? q.content.first.data : ''}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...q.options.map(
                    (opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Icon(
                            opt == q.correctAnswer
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: opt == q.correctAnswer ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : AppColors.textPrimary,
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
          }),
        ],
      ),
    );
  }

  Future<void> _confirmAndGenerate(
    List<NotebookSource> sources,
    NotebookOutputType type, {
    bool hasExistingOutput = false,
    bool isAssessment = false,
  }) async {
    final readySources = sources
        .where((s) => s.processingStatus == SourceProcessingStatus.ready && s.rawContent.isNotEmpty)
        .toList();

    if (readySources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one source with readable text first.')),
      );
      return;
    }

    if (hasExistingOutput) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Regenerate ${type.displayName}?'),
          content: Text(
            'Regenerating will replace your current ${type.displayName.toLowerCase()} output for this notebook. Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    await _generateOutput(sources, type, isAssessment: isAssessment);
  }

  Future<void> _generateOutput(
    List<NotebookSource> sources,
    NotebookOutputType type, {
    bool isAssessment = false,
  }) async {
    if (_isGenerating) return;

    final readySources = sources
        .where((s) => s.processingStatus == SourceProcessingStatus.ready && s.rawContent.isNotEmpty)
        .toList();

    if (readySources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one source with readable text first.')),
      );
      return;
    }

    final combinedText = readySources
        .map((s) => '=== SOURCE: ${s.title} ===\n${s.rawContent}')
        .join('\n\n---\n\n');

    final sourceIds = readySources.map((s) => s.id).toList();

    setState(() {
      _isGenerating = true;
      _generationMessage = 'Synthesizing ${readySources.length} source documents...';
    });

    try {
      NotebookOutput output;

      switch (type) {
        case NotebookOutputType.lesson:
          final lesson = await AIGenerationService.instance.generateLesson(
            combinedText,
            notebookId: widget.notebookId,
          );
          output = lesson.toNotebookOutput(
            id: 'lesson_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;

        case NotebookOutputType.flashcards:
          final deck = await AIGenerationService.instance.generateFlashcards(
            combinedText,
            notebookId: widget.notebookId,
          );
          output = deck.toNotebookOutput(sourceIds: sourceIds);
          break;

        case NotebookOutputType.studyGuide:
          final guide = await AIGenerationService.instance.generateStudyGuide(combinedText);
          output = guide.toNotebookOutput(
            id: 'guide_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;

        case NotebookOutputType.timeline:
          final timeline = await AIGenerationService.instance.generateTimeline(combinedText);
          output = timeline.toNotebookOutput(
            id: 'timeline_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;

        case NotebookOutputType.briefing:
          final briefing = await AIGenerationService.instance.generateBriefing(combinedText);
          output = briefing.toNotebookOutput(
            id: 'briefing_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;

        case NotebookOutputType.faq:
          final faq = await AIGenerationService.instance.generateFAQ(combinedText);
          output = faq.toNotebookOutput(
            id: 'faq_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;

        case NotebookOutputType.mindMap:
          final mindMap = await AIGenerationService.instance.generateMindMap(combinedText);
          output = mindMap.toNotebookOutput(
            id: 'mindmap_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;

        case NotebookOutputType.presentation:
          final pres = await AIGenerationService.instance.generatePresentation(combinedText);
          output = pres.toNotebookOutput(
            id: 'presentation_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;

        case NotebookOutputType.quiz:
          final quiz = await AIGenerationService.instance.generateQuiz(
            combinedText,
            isAssessment: isAssessment,
          );
          output = quiz.toNotebookOutput(
            id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
            notebookId: widget.notebookId,
            sourceIds: sourceIds,
          );
          break;
      }

      await NotebookService.instance.addOutput(widget.notebookId, output);

      if (mounted) {
        AIRateLimitService.instance.showQuotaNotification(
          context,
          title: '${type.displayName} Generated',
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
            AIRateLimitService.instance
                .getStatus(FirebaseAuth.instance.currentUser?.uid ?? '')
                .then((stat) {
              if (mounted) {
                AIQuotaExceededDialog.showExceeded(context, stat);
              }
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showRenameDialog(BuildContext context, Notebook notebook) {
    final controller = TextEditingController(text: notebook.title);
    String? duplicateWarning;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void checkDuplicate(String value) async {
            final exists = await NotebookService.instance.hasNotebookTitle(
              value.trim(),
              excludeNotebookId: notebook.id,
            );
            setDialogState(() {
              duplicateWarning = exists
                  ? 'A notebook with the name "${value.trim()}" already exists. Please choose a unique name.'
                  : null;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Rename Notebook'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: checkDuplicate,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    border: const OutlineInputBorder(),
                    errorText: duplicateWarning != null ? 'Duplicate name detected' : null,
                  ),
                ),
                if (duplicateWarning != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            duplicateWarning!,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: duplicateWarning != null
                    ? null
                    : () async {
                        final title = controller.text.trim();
                        if (title.isEmpty) return;

                        final isDup = await NotebookService.instance.hasNotebookTitle(
                          title,
                          excludeNotebookId: notebook.id,
                        );
                        if (isDup) {
                          setDialogState(() {
                            duplicateWarning = 'A notebook with the name "$title" already exists. Please choose a unique name.';
                          });
                          return;
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await NotebookService.instance.updateNotebook(
                          notebook.copyWith(title: title),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
