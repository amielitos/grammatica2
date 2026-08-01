import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../services/ai_logic_service.dart';
import '../services/database_service.dart';
import '../models/ai_models.dart';
import 'quiz_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// AI Assessment Generator page for Learner Practice Tools.
///
/// Provides two modes: General English and IELTS.
/// Generates passage-based assessments via AI and renders them
/// using the existing quiz layout. Supports local caching of the last
/// generated assessment.
class AiAssessmentGeneratorPage extends StatefulWidget {
  final User user;
  final VoidCallback onBack;

  const AiAssessmentGeneratorPage({
    super.key,
    required this.user,
    required this.onBack,
  });

  @override
  State<AiAssessmentGeneratorPage> createState() =>
      _AiAssessmentGeneratorPageState();
}

class _AiAssessmentGeneratorPageState extends State<AiAssessmentGeneratorPage> {
  final AILogicService _aiService = AILogicService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedMode; // 'general' or 'ielts'

  // Cache keys
  static const _cacheKeyGeneral = 'cached_assessment_general';
  static const _cacheKeyIelts = 'cached_assessment_ielts';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return _buildLoadingView(isDark);
    }

    return _buildSelectionView(isDark);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Selection View — two big buttons
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSelectionView(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: widget.onBack,
        ),
        title: Text(
          'AI Assessment',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  size: 64,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 20),
                Text(
                  'AI-Powered Assessments',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose an assessment type to generate a practice exam with passages and questions.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),

                if (_errorMessage != null) ...[
                  _buildErrorCard(isDark),
                  const SizedBox(height: 20),
                ],

                // Two buttons in a row/column
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 500) {
                      return Row(
                        children: [
                          Expanded(
                            child: _AssessmentTypeCard(
                              title: 'English Assessment',
                              subtitle:
                                  'General English grammar, vocabulary, and reading comprehension.',
                              icon: Icons.menu_book_rounded,
                              color: const Color(0xFF4A7C59),
                              onTap: () => _generateAssessment('general'),
                              onLoadCached: () => _loadCachedAssessment('general'),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _AssessmentTypeCard(
                              title: 'IELTS Assessment',
                              subtitle:
                                  'IELTS-style reading passages with academic question formats.',
                              icon: Icons.school_rounded,
                              color: const Color(0xFF2E5090),
                              onTap: () => _generateAssessment('ielts'),
                              onLoadCached: () => _loadCachedAssessment('ielts'),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _AssessmentTypeCard(
                          title: 'English Assessment',
                          subtitle:
                              'General English grammar, vocabulary, and reading comprehension.',
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFF4A7C59),
                          onTap: () => _generateAssessment('general'),
                          onLoadCached: () => _loadCachedAssessment('general'),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        _AssessmentTypeCard(
                          title: 'IELTS Assessment',
                          subtitle:
                              'IELTS-style reading passages with academic question formats.',
                          icon: Icons.school_rounded,
                          color: const Color(0xFF2E5090),
                          onTap: () => _generateAssessment('ielts'),
                          onLoadCached: () => _loadCachedAssessment('ielts'),
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loading View
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingView(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedMode == 'ielts'
                  ? 'Generating IELTS Assessment…'
                  : 'Generating English Assessment…',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Creating passages and questions. This may take a moment.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.red.shade200 : Colors.red.shade800,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Assessment generation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generateAssessment(String mode) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedMode = mode;
    });

    try {
      final String customInstructions;
      if (mode == 'ielts') {
        customInstructions = '''
Generate an IELTS-style reading assessment. Include:
1. One or two reading passages (200-350 words each) on academic topics.
2. For each passage, create 5-8 questions of mixed types: multiple choice, true/false, short answer, and fill-in-the-blank.
3. Structure the output as passage-type questions with nested questions underneath.
4. Use formal academic English appropriate for IELTS band 6-8.
5. Include questions testing skimming, scanning, inference, and vocabulary in context.
''';
      } else {
        customInstructions = '''
Generate a General English assessment. Include:
1. One or two reading passages (150-300 words each) on general interest topics.
2. For each passage, create 5-8 questions of mixed types: multiple choice, true/false, short answer, and fill-in-the-blank.
3. Structure the output as passage-type questions with nested questions underneath.
4. Test grammar, vocabulary, reading comprehension, and inference skills.
5. Vary difficulty from intermediate to upper-intermediate level.
''';
      }

      final config = QuizGenerationConfig(
        questionTypes: [
          'multiple_choice',
          'true_false',
          'short_answer',
          'fill_in_the_blank',
        ],
        difficulty: 'medium',
        customInstructions: customInstructions,
        includeHints: true,
      );

      // We use a generic prompt since we don't have specific lesson text
      final contextText = mode == 'ielts'
          ? 'Create an IELTS Academic Reading assessment with passages and comprehension questions. The passages should cover academic topics like science, technology, history, or social issues.'
          : 'Create a General English Examination with reading comprehension passages and questions. The passages should cover everyday topics like health, culture, environment, or education.';

      final aiResponse = await _aiService.generateQuiz(
        contextText,
        numQuestions: 10,
        config: config,
      );

      // Convert AI response to native Quiz format for the QuizDetailPage
      final quiz = _convertToNativeQuiz(aiResponse, mode);

      // Cache locally
      await _cacheAssessment(mode, aiResponse);

      if (!mounted) return;

      // Navigate to QuizDetailPage in preview mode
      _navigateToQuiz(quiz);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to generate assessment: $e';
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local caching
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _cacheAssessment(String mode, AIQuizResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = mode == 'ielts' ? _cacheKeyIelts : _cacheKeyGeneral;
      final jsonStr = jsonEncode(response.toJson());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('Failed to cache assessment: $e');
    }
  }

  Future<void> _loadCachedAssessment(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = mode == 'ielts' ? _cacheKeyIelts : _cacheKeyGeneral;
      final jsonStr = prefs.getString(key);

      if (jsonStr == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No cached assessment found. Generate one first.')),
          );
        }
        return;
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final aiResponse = AIQuizResponse.fromJson(parsed);
      final quiz = _convertToNativeQuiz(aiResponse, mode);

      if (mounted) {
        _navigateToQuiz(quiz);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cached assessment: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Conversion & navigation
  // ─────────────────────────────────────────────────────────────────────────

  Quiz _convertToNativeQuiz(AIQuizResponse aiResponse, String mode) {
    final nativeQuestions = aiResponse.questions.map((q) {
      final questionText = q.content
          .where((b) => b.type == ContentBlockType.text)
          .map((b) => b.data.toString())
          .join('\n');

      String nativeType;
      switch (q.questionType) {
        case QuizQuestionType.multipleChoice:
        case QuizQuestionType.trueFalse:
          nativeType = 'multiple_choice';
          break;
        case QuizQuestionType.shortAnswer:
        case QuizQuestionType.fillInTheBlank:
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
      );
    }).toList();

    return Quiz(
      id: 'ai_${mode}_${DateTime.now().millisecondsSinceEpoch}',
      title: mode == 'ielts' ? 'IELTS Practice Assessment' : 'English Assessment',
      description: mode == 'ielts'
          ? 'AI-generated IELTS-style reading assessment'
          : 'AI-generated General English assessment',
      questions: nativeQuestions,
      duration: 30,
      maxAttempts: 1000000, // Unlimited for practice
      createdByUid: 'ai_assessment',
      isVisible: false,
      visibleTo: [],
      isMembersOnly: false,
      isGrammaticaQuiz: false,
      isAssessment: true,
      createdAt: Timestamp.now(),
    );
  }

  void _navigateToQuiz(Quiz quiz) {
    setState(() => _isLoading = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizDetailPage(
          user: widget.user,
          quiz: quiz,
          previewMode: true,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Assessment Type Card
// ═══════════════════════════════════════════════════════════════════════════

class _AssessmentTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLoadCached;
  final bool isDark;

  const _AssessmentTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onLoadCached,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      'Generate New',
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: onLoadCached,
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      'Load Last',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white60 : AppColors.textSecondary,
                      side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
