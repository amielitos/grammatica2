import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

import '../../theme/app_colors.dart';
import '../../services/ai_logic_service.dart';
import '../../services/database_service.dart';
import '../../models/ai_models.dart';

/// AI Quiz Generator tab — configure question types, difficulty, custom
/// instructions, upload a PDF or select a Firestore lesson, generate a quiz,
/// preview it interactively, and publish to Firestore.
class AiQuizGeneratorTab extends StatefulWidget {
  const AiQuizGeneratorTab({super.key});

  @override
  State<AiQuizGeneratorTab> createState() => _AiQuizGeneratorTabState();
}

class _AiQuizGeneratorTabState extends State<AiQuizGeneratorTab>
    with AutomaticKeepAliveClientMixin {
  final AILogicService _aiService = AILogicService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _customInstructionsController =
      TextEditingController();

  AIQuizResponse? _generatedQuiz;
  bool _isLoading = false;
  bool _isPublishing = false;
  String? _errorMessage;
  int _numQuestions = 5;

  // ── Configuration state ───────────────────────────────────────────────
  String _difficulty = 'medium';
  bool _includeHints = true;
  final Set<String> _selectedQuestionTypes = {
    'multiple_choice',
    'true_false',
    'short_answer',
    'fill_in_the_blank',
    'matching',
  };

  // ── Source state ──────────────────────────────────────────────────────
  String? _selectedPdfName;
  String? _selectedLessonId;
  String? _selectedLessonTitle;

  // Interactive quiz state
  final Map<int, String?> _selectedAnswers = {};

  static const _allQuestionTypes = <String, String>{
    'multiple_choice': 'Multiple Choice',
    'true_false': 'True / False',
    'short_answer': 'Short Answer',
    'fill_in_the_blank': 'Fill in the Blank',
    'matching': 'Matching',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _textController.dispose();
    _customInstructionsController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _selectedPdfName = file.name;
      _selectedLessonId = null;
      _selectedLessonTitle = null;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawText = await _aiService.extractTextFromPdf(file.bytes!);
      _textController.text = rawText;
    } catch (e) {
      setState(() => _errorMessage = 'PDF extraction failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showLessonPicker() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    if (!mounted) return;
    final lessons = snapshot.docs;
    if (lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lessons found in Firestore.')),
      );
      return;
    }

    final picked = await showDialog<DocumentSnapshot>(
      context: context,
      builder: (ctx) => _LessonPickerDialog(lessons: lessons),
    );
    if (picked == null) return;

    final data = picked.data() as Map<String, dynamic>;
    final title = (data['title'] ?? 'Untitled').toString();
    final answer = (data['answer'] ?? '').toString();
    final prompt = (data['prompt'] ?? '').toString();
    final content = answer.isNotEmpty ? answer : prompt;

    setState(() {
      _selectedLessonId = picked.id;
      _selectedLessonTitle = title;
      _selectedPdfName = null;
      _textController.text = content;
    });
  }

  Future<void> _generateQuiz() async {
    final text = _textController.text.trim();
    if (text.length < 50) {
      setState(() =>
          _errorMessage = 'Please enter at least 50 characters of content.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedQuiz = null;
      _selectedAnswers.clear();
    });

    try {
      final config = QuizGenerationConfig(
        questionTypes: _selectedQuestionTypes.toList(),
        difficulty: _difficulty,
        customInstructions: _customInstructionsController.text.trim(),
        includeHints: _includeHints,
      );
      final quiz = await _aiService.generateQuiz(
        text,
        numQuestions: _numQuestions,
        config: config,
      );
      setState(() {
        _generatedQuiz = quiz;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _publishToFirestore() async {
    if (_generatedQuiz == null) return;
    setState(() => _isPublishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // Map AIQuizQuestion → native QuizQuestion format
      final nativeQuestions = _generatedQuiz!.questions.map((q) {
        final questionText = q.content
            .where((b) => b.type == ContentBlockType.text)
            .map((b) => b.data.toString())
            .join('\n');

        // Map AI question types to native types
        String nativeType;
        switch (q.questionType) {
          case QuizQuestionType.multipleChoice:
            nativeType = 'multiple_choice';
            break;
          case QuizQuestionType.trueFalse:
            nativeType = 'multiple_choice'; // T/F rendered as MC in native
            break;
          case QuizQuestionType.shortAnswer:
          case QuizQuestionType.fillInTheBlank:
            nativeType = 'text';
            break;
          case QuizQuestionType.matching:
            nativeType = 'text';
            break;
        }

        return QuizQuestion(
          question: questionText,
          answer: q.correctAnswer,
          type: nativeType,
          options: q.options.isNotEmpty ? q.options : null,
          hint: q.hint,
          explanation: q.explanation,
        ).toMap();
      }).toList();

      final quizData = {
        'title': _selectedLessonTitle != null
            ? 'AI Quiz: $_selectedLessonTitle'
            : 'AI Generated Quiz',
        'description':
            'Auto-generated quiz with ${_generatedQuiz!.questions.length} questions '
                '($_difficulty difficulty)',
        'questions': nativeQuestions,
        'duration': 0,
        'maxAttempts': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': user?.uid ?? 'ai_studio',
        'createdByEmail': user?.email ?? 'ai_studio',
        'validationStatus': 'approved',
        'isVisible': true,
        'visibleTo': <String>[],
        'isMembersOnly': false,
        'isGrammaticaQuiz': false,
        'isAssessment': false,
        'source': 'ai_studio',
        if (_selectedLessonId != null) 'linkedLessonId': _selectedLessonId,
      };

      await FirebaseFirestore.instance.collection('quizzes').add(quizData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Quiz with ${_generatedQuiz!.questions.length} questions published!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to publish: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _reset() {
    setState(() {
      _generatedQuiz = null;
      _errorMessage = null;
      _selectedAnswers.clear();
      _textController.clear();
      _customInstructionsController.clear();
      _selectedPdfName = null;
      _selectedLessonId = null;
      _selectedLessonTitle = null;
    });
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
              if (_generatedQuiz == null) ...[
                _buildSourceCard(isDark),
                const SizedBox(height: 16),
                _buildInputCard(isDark),
                const SizedBox(height: 16),
                _buildConfigCard(isDark),
              ],

              if (_isLoading) _buildLoadingCard(isDark),
              if (_errorMessage != null) _buildErrorCard(isDark),

              if (_generatedQuiz != null) ...[
                _buildQuizHeader(isDark),
                const SizedBox(height: 16),
                ...List.generate(
                  _generatedQuiz!.questions.length,
                  (i) => _buildQuestionCard(
                      i, _generatedQuiz!.questions[i], isDark),
                ),
                const SizedBox(height: 24),
                _buildActionBar(isDark),
              ],

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Source card — PDF upload + Firestore lesson picker
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSourceCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(isDark, Icons.source_rounded, 'Content Source'),
          const SizedBox(height: 6),
          Text(
            'Upload a PDF, pick a saved lesson, or paste text manually below.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _outlinedActionButton(
                  icon: Icons.upload_file_rounded,
                  label: _selectedPdfName ?? 'Upload PDF',
                  onTap: _isLoading ? null : _pickPdf,
                  isDark: isDark,
                  isActive: _selectedPdfName != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _outlinedActionButton(
                  icon: Icons.library_books_rounded,
                  label: _selectedLessonTitle ?? 'From Lessons',
                  onTap: _isLoading ? null : _showLessonPicker,
                  isDark: isDark,
                  isActive: _selectedLessonId != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outlinedActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.08)
                : (isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? Colors.white54 : Colors.grey)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text input card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInputCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(isDark, Icons.edit_note_rounded, 'Lesson Content'),
          const SizedBox(height: 6),
          Text(
            'Paste, type, or auto-filled from the source above.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 8,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  'Paste lesson content here (at least 50 characters)…',
              hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color:
                      isDark ? Colors.white38 : AppColors.textSecondary),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Configuration card — question types, difficulty, instructions, hints
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildConfigCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(isDark, Icons.tune_rounded, 'Quiz Configuration'),
          const SizedBox(height: 20),

          // ── Question count slider ────────────────────────────────────
          _subLabel(isDark, 'Number of Questions'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _numQuestions.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '$_numQuestions',
                  activeColor: AppColors.primary,
                  onChanged: (v) =>
                      setState(() => _numQuestions = v.round()),
                ),
              ),
              _badge('$_numQuestions'),
            ],
          ),
          const SizedBox(height: 20),

          // ── Question types ───────────────────────────────────────────
          _subLabel(isDark, 'Question Types'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allQuestionTypes.entries.map((entry) {
              final isSelected =
                  _selectedQuestionTypes.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedQuestionTypes.add(entry.key);
                    } else if (_selectedQuestionTypes.length > 1) {
                      _selectedQuestionTypes.remove(entry.key);
                    }
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.18),
                checkmarkColor: AppColors.primary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white70 : AppColors.textPrimary),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Difficulty ───────────────────────────────────────────────
          _subLabel(isDark, 'Difficulty'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'easy', label: Text('Easy')),
              ButtonSegment(value: 'medium', label: Text('Medium')),
              ButtonSegment(value: 'hard', label: Text('Hard')),
            ],
            selected: {_difficulty},
            onSelectionChanged: (v) =>
                setState(() => _difficulty = v.first),
            style: ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return isDark ? Colors.white70 : AppColors.textPrimary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFF5F5F5);
              }),
            ),
          ),
          const SizedBox(height: 20),

          // ── Hints toggle ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _subLabel(isDark, 'Include Hints'),
                    const SizedBox(height: 2),
                    Text(
                      'AI will generate a helpful hint for each question.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _includeHints,
                onChanged: (v) => setState(() => _includeHints = v),
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Custom instructions ──────────────────────────────────────
          _subLabel(isDark, 'Custom Instructions (Optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _customInstructionsController,
            maxLines: 4,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  'E.g. "Questions 1-10 should be multiple choice, 11-20 enumeration. '
                  'Focus on vocabulary from chapter 3."',
              hintStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color:
                      isDark ? Colors.white30 : AppColors.textSecondary),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Generate button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateQuiz,
              icon: const Icon(Icons.auto_awesome),
              label: Text('Generate Quiz',
                  style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w700)),
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
  // Loading / Error
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.all(40),
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
      child: Column(
        children: [
          const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 20),
          Text('Generating quiz questions…',
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
              'Crafting $_numQuestions ${_difficulty.toUpperCase()} questions…',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color:
                      isDark ? Colors.white54 : AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_errorMessage!,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.red.shade200
                        : Colors.red.shade800)),
          ),
          IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _errorMessage = null)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Quiz header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuizHeader(bool isDark) {
    final answered = _selectedAnswers.length;
    final total = _generatedQuiz!.questions.length;
    final correct = _selectedAnswers.entries
        .where(
            (e) => e.value == _generatedQuiz!.questions[e.key].correctAnswer)
        .length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2744), const Color(0xFF2A1A44)]
              : [const Color(0xFFE3F2FD), const Color(0xFFF3E5F5)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz_rounded,
                color: Colors.deepPurpleAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generated Quiz',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total questions • $answered answered • $correct correct '
                  '• ${_difficulty.toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color:
                        isDark ? Colors.white60 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Start Over',
            onPressed: _reset,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Question card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuestionCard(
      int index, AIQuizQuestion question, bool isDark) {
    final selectedAnswer = _selectedAnswers[index];
    final isAnswered = selectedAnswer != null;
    final isCorrect = selectedAnswer == question.correctAnswer;

    // Extract display text from content blocks
    final questionText = question.content
        .where((b) => b.type == ContentBlockType.text)
        .map((b) => b.data.toString())
        .join('\n');

    // Badge color for question type
    Color typeBadgeColor;
    String typeLabel;
    switch (question.questionType) {
      case QuizQuestionType.multipleChoice:
        typeBadgeColor = Colors.blue;
        typeLabel = 'Multiple Choice';
        break;
      case QuizQuestionType.trueFalse:
        typeBadgeColor = Colors.teal;
        typeLabel = 'True / False';
        break;
      case QuizQuestionType.shortAnswer:
        typeBadgeColor = Colors.orange;
        typeLabel = 'Short Answer';
        break;
      case QuizQuestionType.fillInTheBlank:
        typeBadgeColor = Colors.purple;
        typeLabel = 'Fill in the Blank';
        break;
      case QuizQuestionType.matching:
        typeBadgeColor = Colors.indigo;
        typeLabel = 'Matching';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isAnswered
            ? Border.all(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.redAccent.withValues(alpha: 0.5),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number + type badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white70
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  typeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: typeBadgeColor,
                  ),
                ),
              ),
              const Spacer(),
              if (isAnswered)
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 22,
                  color: isCorrect ? Colors.green : Colors.redAccent,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Question text
          Text(
            questionText,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppColors.textPrimary,
            ),
          ),

          // Hint (shown before answering if available)
          if (question.hint != null &&
              question.hint!.isNotEmpty &&
              !isAnswered)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💡 Hint: ${question.hint}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? Colors.amber.shade200
                              : Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 14),

          // Options (for MC / TF)
          if (question.options.isNotEmpty)
            ...question.options.map((option) {
              final isSelected = selectedAnswer == option;
              final showCorrect =
                  isAnswered && option == question.correctAnswer;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isAnswered
                        ? null
                        : () => setState(
                            () => _selectedAnswers[index] = option),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: showCorrect
                            ? Colors.green.withValues(alpha: 0.1)
                            : isSelected && !isCorrect
                                ? Colors.red.withValues(alpha: 0.08)
                                : isDark
                                    ? const Color(0xFF333333)
                                    : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: showCorrect
                              ? Colors.green.withValues(alpha: 0.5)
                              : isSelected
                                  ? (isCorrect
                                      ? Colors.green
                                              .withValues(alpha: 0.5)
                                      : Colors.redAccent
                                              .withValues(alpha: 0.5))
                                  : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: showCorrect
                                ? Colors.green
                                : isSelected
                                    ? (isCorrect
                                        ? Colors.green
                                        : Colors.redAccent)
                                    : (isDark
                                        ? Colors.white38
                                        : Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

          // Short answer / Fill in blank
          if (question.options.isEmpty && !isAnswered)
            TextField(
              onSubmitted: (val) =>
                  setState(() => _selectedAnswers[index] = val.trim()),
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type your answer…',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white38
                        : AppColors.textSecondary),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: const Icon(Icons.send, size: 18),
              ),
            ),

          // Show correct answer after answering
          if (isAnswered && !isCorrect)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Correct answer: ${question.correctAnswer}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),

          // Explanation (shown after answering)
          if (isAnswered &&
              question.explanation != null &&
              question.explanation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.blue.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question.explanation!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade800,
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
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Action bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActionBar(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isPublishing ? null : _publishToFirestore,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                _isPublishing ? 'Publishing…' : 'Save Quiz to App',
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
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text('Start Over',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.white60 : AppColors.textSecondary,
              side: BorderSide(
                  color: isDark ? Colors.white24 : AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _card(bool isDark, {required Widget child}) {
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
      child: child,
    );
  }

  Widget _sectionTitle(bool isDark, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _subLabel(bool isDark, String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : AppColors.textPrimary,
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Lesson Picker Dialog
// ═══════════════════════════════════════════════════════════════════════════

class _LessonPickerDialog extends StatelessWidget {
  final List<QueryDocumentSnapshot> lessons;
  const _LessonPickerDialog({required this.lessons});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Icon(Icons.library_books_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Select a Lesson',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: lessons.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final data =
                      lessons[i].data() as Map<String, dynamic>;
                  final title =
                      (data['title'] ?? 'Untitled').toString();
                  final createdAt = data['createdAt'] as Timestamp?;
                  final dateStr = createdAt != null
                      ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                      : '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.article_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: dateStr.isNotEmpty
                        ? Text(dateStr,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : AppColors.textSecondary))
                        : null,
                    onTap: () => Navigator.pop(context, lessons[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
