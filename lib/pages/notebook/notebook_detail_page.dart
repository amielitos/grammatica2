import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ai_models.dart';
import '../../models/flashcard_models.dart';
import '../../models/notebook_models.dart';
import '../../models/study_guide_models.dart';
import '../../services/ai_generation_service.dart';
import '../../services/notebook_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notebook/generation_confirm_dialog.dart';
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

                return Scaffold(
                  backgroundColor: isDark ? const Color(0xFF131812) : AppColors.backgroundBase,
                  appBar: _buildAppBar(context, notebook, isDark, outputs),
                  body: Stack(
                    children: [
                      isDesktop
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

                      if (_isGenerating)
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
                            child: GenerationLoadingOverlay(
                              title: 'Generating ${_selectedOutputType.displayName}...',
                              subtitle: _generationMessage,
                            ),
                          ),
                        ),
                    ],
                  ),
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
      backgroundColor: isDark ? const Color(0xFF182017) : Colors.white,
      title: InkWell(
        onTap: () => _showRenameDialog(context, notebook),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notebook.title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
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
        if (outputs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: Text(
                'Publish All to Curriculum',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        // Left Column: Source Upload Panel (fixed 320px)
        SizedBox(
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

      case NotebookOutputType.quiz:
        final quiz = AIQuizResponse.fromNotebookOutput(activeOutput);
        return _buildQuizPreview(quiz, activeOutput, isDark, sources);
    }
  }

  Widget _buildNoOutputPlaceholder(List<NotebookSource> sources, bool isDark) {
    final hasSources = sources.any((s) => s.processingStatus == SourceProcessingStatus.ready);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No ${_selectedOutputType.displayName} generated yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hasSources
                  ? 'Synthesize all ingested sources into a high-quality ${_selectedOutputType.displayName.toLowerCase()}.'
                  : 'Add one or more sources on the left panel to begin generating.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: hasSources
                  ? () => _confirmAndGenerate(sources, _selectedOutputType, hasExistingOutput: false)
                  : null,
              icon: const Icon(Icons.bolt_rounded),
              label: Text('Generate ${_selectedOutputType.displayName}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
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

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => GenerationConfirmDialog(
        type: type,
        sources: sources,
        hasExistingOutput: hasExistingOutput,
      ),
    );

    if (result != null && result['confirmed'] == true) {
      final isAssessment = result['isAssessment'] as bool? ?? false;
      await _generateOutput(sources, type, isAssessment: isAssessment);
    }
  }

  Future<void> _generateOutput(
    List<NotebookSource> sources,
    NotebookOutputType type, {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showRenameDialog(BuildContext context, Notebook notebook) {
    final controller = TextEditingController(text: notebook.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Notebook'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await NotebookService.instance.updateNotebook(
                notebook.copyWith(title: controller.text.trim()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
