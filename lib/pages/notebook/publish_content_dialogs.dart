import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ai_models.dart';
import '../../models/content_visibility.dart';
import '../../models/notebook_models.dart';
import '../../services/auth_service.dart';
import '../../services/notebook_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_visibility_selector.dart';

/// Modal dialog for configuring and publishing a generated Lesson directly to Firestore curriculum.
class PublishLessonDialog extends StatefulWidget {
  final String notebookId;
  final NotebookOutput output;
  final String markdownPrompt;
  final VoidCallback? onPublished;

  const PublishLessonDialog({
    super.key,
    required this.notebookId,
    required this.output,
    required this.markdownPrompt,
    this.onPublished,
  });

  @override
  State<PublishLessonDialog> createState() => _PublishLessonDialogState();
}

class _PublishLessonDialogState extends State<PublishLessonDialog> {
  late final TextEditingController _titleCtrl;
  ContentVisibility _visibility = ContentVisibility.public;
  List<String> _visibleTo = [];
  String? _selectedQuizId;
  NotebookOutput? _notebookQuizOutput;
  List<NotebookOutput> _companionOutputs = [];
  bool _isLoadingQuiz = true;
  bool _isPublishing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.output.title);
    _checkNotebookCompanions();
  }

  Future<void> _checkNotebookCompanions() async {
    try {
      final outputs = NotebookService.instance.getOutputsForNotebook(widget.notebookId);
      final quizOutput = outputs.cast<NotebookOutput?>().firstWhere(
            (o) => o?.type == NotebookOutputType.quiz,
            orElse: () => null,
          );
      final companions = outputs.where((o) =>
            o.type != NotebookOutputType.quiz &&
            o.type != NotebookOutputType.lesson).toList();
      if (mounted) {
        setState(() {
          _notebookQuizOutput = quizOutput;
          _companionOutputs = companions;
          _selectedQuizId = quizOutput?.publishedId;
          _isLoadingQuiz = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingQuiz = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Lesson title cannot be empty.');
      return;
    }

    setState(() {
      _isPublishing = true;
      _errorMessage = null;
    });

    try {
      // Auto-publish notebook quiz if present and not yet published to Firestore
      if (_selectedQuizId == null && _notebookQuizOutput != null) {
        final quizResponse = AIQuizResponse.fromNotebookOutput(_notebookQuizOutput!);
        final questions = quizResponse.toQuizQuestions();
        if (questions.isNotEmpty) {
          final publishedQuizId = await NotebookService.instance.publishQuiz(
            notebookId: widget.notebookId,
            outputId: _notebookQuizOutput!.id,
            title: _notebookQuizOutput!.title.isNotEmpty ? _notebookQuizOutput!.title : 'Quiz for $title',
            description: _notebookQuizOutput!.data['description']?.toString() ?? '',
            questions: questions,
            visibility: _visibility,
            visibleTo: _visibleTo,
            isAssessment: _notebookQuizOutput!.data['isAssessment'] as bool? ?? false,
          );
          _selectedQuizId = publishedQuizId;
        }
      }

      final lessonId = await NotebookService.instance.publishLesson(
        notebookId: widget.notebookId,
        outputId: widget.output.id,
        title: title,
        prompt: widget.markdownPrompt,
        visibility: _visibility,
        visibleTo: _visibleTo,
        quizId: _selectedQuizId,
      );

      // Auto-publish all companion outputs (Flashcards, Mind Maps, Study Guides, etc.) generated in this notebook!
      for (final out in _companionOutputs) {
        try {
          await NotebookService.instance.publishContent(
            notebookId: widget.notebookId,
            outputId: out.id,
            type: out.type,
            title: out.title.isNotEmpty ? out.title : out.type.displayName,
            data: out.data,
            visibility: _visibility,
            visibleTo: _visibleTo,
          );
        } catch (e) {
          debugPrint('Error auto-publishing companion ${out.type}: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context, lessonId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lesson and companion materials successfully published to Grammatica curriculum!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onPublished?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _errorMessage = 'Publish failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E261D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publish Lesson to Curriculum',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Publish this notebook lesson into the Grammatica course catalog.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Lesson Title Input
              Text(
                'Lesson Title',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. Mastering English Relative Clauses',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A3428) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Visibility Selection
              Text(
                'Visibility Tier',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Public'),
                    avatar: const Icon(Icons.public_rounded, size: 16),
                    selected: _visibility == ContentVisibility.public,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.public);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Standard / Members'),
                    avatar: const Icon(Icons.people_outline, size: 16),
                    selected: _visibility == ContentVisibility.membersOnly,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.membersOnly);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Premium / Specific Users'),
                    avatar: const Icon(Icons.star_outline_rounded, size: 16),
                    selected: _visibility == ContentVisibility.certainUsers,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.certainUsers);
                    },
                  ),
                ],
              ),
              if (_visibility == ContentVisibility.certainUsers) ...[
                const SizedBox(height: 16),
                StreamBuilder<UserRole>(
                  stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
                  builder: (context, snapshot) {
                    final isEducator = snapshot.data == UserRole.educator;
                    return UserVisibilitySelector(
                      selectedUserIds: _visibleTo,
                      educatorUid: isEducator ? user?.uid : null,
                      onChanged: (users) => setState(() => _visibleTo = users),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),

              // In-Notebook Quiz Link
              Text(
                'Linked Quiz',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (_isLoadingQuiz)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                )
              else if (_notebookQuizOutput != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.link_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Linked Notebook Quiz',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _notebookQuizOutput!.title.isNotEmpty
                                  ? _notebookQuizOutput!.title
                                  : 'Quiz generated in this notebook',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No Quiz has been generated for this notebook. Generate one by clicking the Quiz button.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_companionOutputs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Companion Materials in Bundle (${_companionOutputs.length})',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.layers_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Will be published & linked with this lesson:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _companionOutputs.map((out) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  out.type == NotebookOutputType.flashcards
                                      ? Icons.style_rounded
                                      : out.type == NotebookOutputType.mindMap
                                          ? Icons.hub_rounded
                                          : Icons.auto_stories_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${out.type.displayName}: ${out.title.isNotEmpty ? out.title : "Untitled"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isPublishing ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isPublishing ? null : _publish,
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      _isPublishing ? 'Publishing...' : 'Publish to Curriculum',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
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

/// Modal dialog for configuring and publishing a generated Quiz directly to Firestore curriculum.
class PublishQuizDialog extends StatefulWidget {
  final String notebookId;
  final NotebookOutput output;
  final VoidCallback? onPublished;

  const PublishQuizDialog({
    super.key,
    required this.notebookId,
    required this.output,
    this.onPublished,
  });

  @override
  State<PublishQuizDialog> createState() => _PublishQuizDialogState();
}

class _PublishQuizDialogState extends State<PublishQuizDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  int _durationMinutes = 30;
  int _maxAttempts = 1;
  ContentVisibility _visibility = ContentVisibility.public;
  List<String> _visibleTo = [];
  bool _isAssessment = false;
  bool _isPublishing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isAssessment = widget.output.data['isAssessment'] as bool? ?? false;
    _titleCtrl = TextEditingController(text: widget.output.title);
    _descCtrl = TextEditingController(
      text: widget.output.data['description']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Quiz title cannot be empty.');
      return;
    }

    setState(() {
      _isPublishing = true;
      _errorMessage = null;
    });

    try {
      final quizResponse = AIQuizResponse.fromNotebookOutput(widget.output);
      final questions = quizResponse.toQuizQuestions();

      if (questions.isEmpty) {
        throw Exception('Quiz contains no questions to publish.');
      }

      final quizId = await NotebookService.instance.publishQuiz(
        notebookId: widget.notebookId,
        outputId: widget.output.id,
        title: title,
        description: _descCtrl.text.trim(),
        questions: questions,
        durationMinutes: _durationMinutes,
        maxAttempts: _maxAttempts,
        visibility: _visibility,
        visibleTo: _visibleTo,
        isAssessment: _isAssessment,
      );

      if (mounted) {
        Navigator.pop(context, quizId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz successfully published to Grammatica curriculum!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onPublished?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _errorMessage = 'Publish failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;

    final durationOptions = {
      5: '5 Minutes',
      10: '10 Minutes',
      15: '15 Minutes',
      20: '20 Minutes',
      30: '30 Minutes',
      45: '45 Minutes',
      60: '1 Hour',
      90: '1.5 Hours',
      120: '2 Hours',
    };

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E261D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publish Quiz to Curriculum',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Publish this quiz into the live student quiz catalog.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Title
              Text('Quiz Title', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. Relative Clauses Quiz',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A3428) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text('Description', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Instructions or summary for students...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A3428) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Duration & Max Attempts
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time Limit', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _durationMinutes,
                          style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A3428) : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                          ),
                          items: durationOptions.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _durationMinutes = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Max Attempts', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A3428) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _maxAttempts > 1 ? () => setState(() => _maxAttempts--) : null,
                              ),
                              Text('$_maxAttempts', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => setState(() => _maxAttempts++),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Visibility Tier
              Text('Visibility Tier', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Public'),
                    avatar: const Icon(Icons.public_rounded, size: 16),
                    selected: _visibility == ContentVisibility.public,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.public);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Standard / Members'),
                    avatar: const Icon(Icons.people_outline, size: 16),
                    selected: _visibility == ContentVisibility.membersOnly,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.membersOnly);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Premium / Specific Users'),
                    avatar: const Icon(Icons.star_outline_rounded, size: 16),
                    selected: _visibility == ContentVisibility.certainUsers,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.certainUsers);
                    },
                  ),
                ],
              ),
              if (_visibility == ContentVisibility.certainUsers) ...[
                const SizedBox(height: 16),
                StreamBuilder<UserRole>(
                  stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
                  builder: (context, snapshot) {
                    final isEducator = snapshot.data == UserRole.educator;
                    return UserVisibilitySelector(
                      selectedUserIds: _visibleTo,
                      educatorUid: isEducator ? user?.uid : null,
                      onChanged: (users) => setState(() => _visibleTo = users),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isPublishing ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isPublishing ? null : _publish,
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      _isPublishing ? 'Publishing...' : 'Publish to Curriculum',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
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

/// Modal dialog for configuring and publishing any Notebook output (Mind Maps, Flashcards, Study Guides, etc.)
/// directly to the Firestore `published_content` collection.
class PublishContentDialog extends StatefulWidget {
  final String notebookId;
  final NotebookOutput output;
  final VoidCallback? onPublished;

  const PublishContentDialog({
    super.key,
    required this.notebookId,
    required this.output,
    this.onPublished,
  });

  @override
  State<PublishContentDialog> createState() => _PublishContentDialogState();
}

class _PublishContentDialogState extends State<PublishContentDialog> {
  late final TextEditingController _titleCtrl;
  ContentVisibility _visibility = ContentVisibility.public;
  List<String> _visibleTo = [];
  bool _isPublishing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.output.title);
    if (widget.output.publishMetadata != null) {
      final visStr = widget.output.publishMetadata!['visibility'] as String?;
      if (visStr != null) {
        _visibility = ContentVisibility.values.firstWhere(
          (v) => v.name == visStr,
          orElse: () => ContentVisibility.public,
        );
      }
      final visTo = widget.output.publishMetadata!['visibleTo'] as List?;
      if (visTo != null) {
        _visibleTo = List<String>.from(visTo);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Title cannot be empty.');
      return;
    }

    setState(() {
      _isPublishing = true;
      _errorMessage = null;
    });

    try {
      final publishedId = await NotebookService.instance.publishContent(
        notebookId: widget.notebookId,
        outputId: widget.output.id,
        type: widget.output.type,
        title: title,
        data: widget.output.data,
        visibility: _visibility,
        visibleTo: _visibleTo,
      );

      if (mounted) {
        Navigator.pop(context, publishedId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.output.type.displayName} successfully published to Grammatica curriculum!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onPublished?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _errorMessage = 'Publish failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;

    IconData typeIcon;
    Color typeColor;
    switch (widget.output.type) {
      case NotebookOutputType.mindMap:
        typeIcon = Icons.hub_rounded;
        typeColor = const Color(0xFFEC4899);
        break;
      case NotebookOutputType.flashcards:
        typeIcon = Icons.style_rounded;
        typeColor = const Color(0xFF3B82F6);
        break;
      case NotebookOutputType.studyGuide:
        typeIcon = Icons.menu_book_rounded;
        typeColor = const Color(0xFF10B981);
        break;
      case NotebookOutputType.timeline:
        typeIcon = Icons.timeline_rounded;
        typeColor = const Color(0xFF8B5CF6);
        break;
      case NotebookOutputType.briefing:
        typeIcon = Icons.assignment_rounded;
        typeColor = const Color(0xFF14B8A6);
        break;
      case NotebookOutputType.faq:
        typeIcon = Icons.help_outline_rounded;
        typeColor = const Color(0xFFF59E0B);
        break;
      default:
        typeIcon = Icons.auto_awesome_rounded;
        typeColor = AppColors.primary;
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E261D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publish ${widget.output.type.displayName}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Make this ${widget.output.type.displayName.toLowerCase()} viewable by learners in the curriculum.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Title Field
              Text(
                'Content Title',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Enter title...',
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Visibility Choice Chips
              Text(
                'Audience & Visibility',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: _visibility == ContentVisibility.public,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.public);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Members Only'),
                    selected: _visibility == ContentVisibility.membersOnly,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.membersOnly);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Certain Users'),
                    selected: _visibility == ContentVisibility.certainUsers,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.certainUsers);
                    },
                  ),
                ],
              ),
              if (_visibility == ContentVisibility.certainUsers) ...[
                const SizedBox(height: 16),
                StreamBuilder<UserRole>(
                  stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
                  builder: (context, snapshot) {
                    final isEducator = snapshot.data == UserRole.educator;
                    return UserVisibilitySelector(
                      selectedUserIds: _visibleTo,
                      educatorUid: isEducator ? user?.uid : null,
                      onChanged: (users) => setState(() => _visibleTo = users),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isPublishing ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isPublishing ? null : _publish,
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      _isPublishing ? 'Publishing...' : 'Publish to Curriculum',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
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

/// Modal dialog for publishing all generated outputs in a notebook at once to the curriculum.
class PublishAllOutputsDialog extends StatefulWidget {
  final String notebookId;
  final List<NotebookOutput> outputs;
  final VoidCallback? onPublishedAll;

  const PublishAllOutputsDialog({
    super.key,
    required this.notebookId,
    required this.outputs,
    this.onPublishedAll,
  });

  @override
  State<PublishAllOutputsDialog> createState() => _PublishAllOutputsDialogState();
}

class _PublishAllOutputsDialogState extends State<PublishAllOutputsDialog> {
  ContentVisibility _visibility = ContentVisibility.public;
  List<String> _visibleTo = [];
  bool _isPublishing = false;
  String _publishingStatus = '';
  String? _errorMessage;

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
    }
  }

  Future<void> _publishAll() async {
    if (widget.outputs.isEmpty) return;

    setState(() {
      _isPublishing = true;
      _errorMessage = null;
    });

    try {
      // 1. Publish quiz first if present to acquire publishedQuizId
      String? publishedQuizId;
      final quizOutputs = widget.outputs.where((o) => o.type == NotebookOutputType.quiz).toList();
      if (quizOutputs.isNotEmpty) {
        final quizOut = quizOutputs.first;
        setState(() => _publishingStatus = 'Publishing quiz: ${quizOut.title}...');
        final quizResponse = AIQuizResponse.fromNotebookOutput(quizOut);
        final questions = quizResponse.toQuizQuestions();
        if (questions.isNotEmpty) {
          publishedQuizId = await NotebookService.instance.publishQuiz(
            notebookId: widget.notebookId,
            outputId: quizOut.id,
            title: quizOut.title.isNotEmpty ? quizOut.title : 'Notebook Quiz',
            description: quizOut.data['description']?.toString() ?? '',
            questions: questions,
            visibility: _visibility,
            visibleTo: _visibleTo,
            isAssessment: quizOut.data['isAssessment'] as bool? ?? false,
          );
        }
      }

      // 2. Publish lessons with automatic link to the published quiz
      final lessonOutputs = widget.outputs.where((o) => o.type == NotebookOutputType.lesson).toList();
      for (final lessonOut in lessonOutputs) {
        setState(() => _publishingStatus = 'Publishing lesson: ${lessonOut.title}...');
        final lesson = AILessonResponse.fromNotebookOutput(lessonOut);
        await NotebookService.instance.publishLesson(
          notebookId: widget.notebookId,
          outputId: lessonOut.id,
          title: lessonOut.title.isNotEmpty ? lessonOut.title : 'Notebook Lesson',
          prompt: lesson.toMarkdownContent(),
          visibility: _visibility,
          visibleTo: _visibleTo,
          quizId: publishedQuizId,
        );
      }

      // 3. Publish all other outputs
      final otherOutputs = widget.outputs.where((o) =>
          o.type != NotebookOutputType.quiz && o.type != NotebookOutputType.lesson).toList();

      for (int i = 0; i < otherOutputs.length; i++) {
        final out = otherOutputs[i];
        setState(() => _publishingStatus = 'Publishing ${out.type.displayName} (${i + 1}/${otherOutputs.length})...');
        await NotebookService.instance.publishContent(
          notebookId: widget.notebookId,
          outputId: out.id,
          type: out.type,
          title: out.title.isNotEmpty ? out.title : out.type.displayName,
          data: out.data,
          visibility: _visibility,
          visibleTo: _visibleTo,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully published all ${widget.outputs.length} notebook materials to the curriculum!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onPublishedAll?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _errorMessage = 'Batch publishing failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.instance.currentUser;
    final hasQuiz = widget.outputs.any((o) => o.type == NotebookOutputType.quiz);
    final hasLesson = widget.outputs.any((o) => o.type == NotebookOutputType.lesson);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E261D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publish All to Curriculum',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upload all ${widget.outputs.length} generated outputs directly to live curriculum.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Output items list
              Text(
                'Materials to Publish (${widget.outputs.length})',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.outputs.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  itemBuilder: (context, idx) {
                    final out = widget.outputs[idx];
                    final color = _getTypeColor(out.type);
                    final icon = _getTypeIcon(out.type);

                    return ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      title: Text(
                        out.title.isNotEmpty ? out.title : out.type.displayName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: out.type == NotebookOutputType.lesson && hasQuiz
                          ? Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 12, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  'Auto-links to notebook quiz',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981)),
                                ),
                              ],
                            )
                          : Text(
                              out.type.displayName,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                            ),
                      trailing: out.isPublished
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Published',
                                style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Draft',
                                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              if (hasLesson && hasQuiz)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your generated lesson will be automatically linked with this notebook\'s quiz.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasLesson && !hasQuiz)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No Quiz has been generated for this notebook. Generate one by clicking the Quiz button.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Visibility Selector
              Text(
                'Audience & Visibility',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Public (All Learners)'),
                    selected: _visibility == ContentVisibility.public,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.public);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Members Only'),
                    selected: _visibility == ContentVisibility.membersOnly,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.membersOnly);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Certain Users'),
                    selected: _visibility == ContentVisibility.certainUsers,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    onSelected: (val) {
                      if (val) setState(() => _visibility = ContentVisibility.certainUsers);
                    },
                  ),
                ],
              ),
              if (_visibility == ContentVisibility.certainUsers) ...[
                const SizedBox(height: 16),
                StreamBuilder<UserRole>(
                  stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
                  builder: (context, snapshot) {
                    final isEducator = snapshot.data == UserRole.educator;
                    return UserVisibilitySelector(
                      selectedUserIds: _visibleTo,
                      educatorUid: isEducator ? user?.uid : null,
                      onChanged: (users) => setState(() => _visibleTo = users),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),

              if (_isPublishing) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _publishingStatus.isNotEmpty ? _publishingStatus : 'Publishing materials...',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isPublishing ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isPublishing ? null : _publishAll,
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      _isPublishing ? 'Publishing All...' : 'Publish All (${widget.outputs.length})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
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
