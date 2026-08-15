import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../theme/app_colors.dart';
import '../../services/ai_logic_service.dart';
import '../../models/ai_models.dart';

/// AI Lesson Generator tab — upload PDF or paste text, generate structured
/// lesson content via Gemini, preview it, and optionally publish to Firestore.
class AiLessonGeneratorTab extends StatefulWidget {
  const AiLessonGeneratorTab({super.key});

  @override
  State<AiLessonGeneratorTab> createState() => _AiLessonGeneratorTabState();
}

class _AiLessonGeneratorTabState extends State<AiLessonGeneratorTab>
    with AutomaticKeepAliveClientMixin {
  final AILogicService _aiService = AILogicService();
  final TextEditingController _textController = TextEditingController();

  AILessonResponse? _generatedLesson;
  bool _isLoading = false;
  bool _isPublishing = false;
  String? _errorMessage;
  String? _selectedFileName;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickAndProcessPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;
      List<int> bytes;
      if (platformFile.bytes != null) {
        bytes = platformFile.bytes!;
      } else if (!kIsWeb && platformFile.path != null) {
        bytes = await File(platformFile.path!).readAsBytes();
      } else {
        throw Exception('Could not read file data.');
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _generatedLesson = null;
        _selectedFileName = platformFile.name;
      });

      // Generate structured lesson
      final lesson = await _aiService.generateLessonFromPdf(bytes);

      setState(() {
        _generatedLesson = lesson;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _generateFromText() async {
    final text = _textController.text.trim();
    if (text.length < 50) {
      setState(
          () => _errorMessage = 'Please enter at least 50 characters of text.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedLesson = null;
    });

    try {
      final lesson = await _aiService.generateLesson(text);
      setState(() {
        _generatedLesson = lesson;
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
    if (_generatedLesson == null) return;

    setState(() => _isPublishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final lessonData = {
        'title': _generatedLesson!.title,
        'content': _generatedLesson!.content.map((b) => b.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid ?? 'ai_studio',
        'isVisible': true,
        'isGrammaticaLesson': false,
        'source': 'ai_studio',
      };

      if (_errorMessage != null) {
        setState(() => _isPublishing = false);
        return;
      }
      await FirebaseFirestore.instance.collection('lessons').add(lessonData);
      // Removed confusing success toast that triggers even on errors.
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
      _generatedLesson = null;
      _errorMessage = null;
      _selectedFileName = null;
      _textController.clear();
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
              // ── Input section ──────────────────────────────────────────
              if (_generatedLesson == null) ...[
                _buildInputCard(isDark),
                const SizedBox(height: 16),
                _buildTextInputCard(isDark),
              ],

              // ── Loading indicator ──────────────────────────────────────
              if (_isLoading) _buildLoadingCard(isDark),

              // ── Error message ──────────────────────────────────────────
              if (_errorMessage != null) _buildErrorCard(isDark),

              // ── Generated lesson preview ───────────────────────────────
              if (_generatedLesson != null) ...[
                _buildResultHeader(isDark),
                const SizedBox(height: 16),
                ..._generatedLesson!.content
                    .map((block) => _buildContentBlock(block, isDark)),
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
  // Input: PDF upload
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInputCard(bool isDark) {
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
        children: [
          Icon(
            Icons.upload_file_rounded,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload a PDF to generate a lesson',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The AI will extract text, summarise it, and structure it into engaging content blocks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedFileName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Chip(
                avatar: const Icon(Icons.picture_as_pdf,
                    size: 18, color: Colors.redAccent),
                label: Text(_selectedFileName!,
                    style: GoogleFonts.inter(fontSize: 13)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: _reset,
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickAndProcessPdf,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(
                _selectedFileName != null ? 'Choose Different PDF' : 'Select PDF File',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w600),
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
  // Input: Raw text
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTextInputCard(bool isDark) {
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
          Text(
            'Or paste lesson text directly',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: 6,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  'Paste your lesson content here (at least 50 characters)…',
              hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : AppColors.textSecondary),
              filled: true,
              fillColor: isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _generateFromText,
              icon: const Icon(Icons.auto_awesome),
              label: Text('Generate from Text',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
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
  // Loading
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
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Generating lesson content…',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grammatica AI model is analysing and structuring your content.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildErrorCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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
  // Result header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildResultHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A2F), const Color(0xFF1A2744)]
              : [const Color(0xFFE8F5E9), const Color(0xFFE3F2FD)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _generatedLesson!.title,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_generatedLesson!.content.length} content blocks generated',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
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
  // Content block renderer
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContentBlock(ContentBlock block, bool isDark) {
    Widget child;

    switch (block.type) {
      case ContentBlockType.text:
        child = _buildTextBlock(block.data as String, isDark);
        break;
      case ContentBlockType.list:
        child = _buildListBlock(
            (block.data as List).map((e) => e.toString()).toList(), isDark);
        break;
      case ContentBlockType.table:
        child = _buildTableBlock(block.data as List, isDark);
        break;
      case ContentBlockType.image:
        child = _buildImageBlock(block.data as String, isDark);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildTextBlock(String text, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.text_fields, size: 16, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text('Text', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14.5,
            height: 1.7,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildListBlock(List<String> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_bulleted, size: 16, color: AppColors.secondary.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text('Key Points', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: isDark ? Colors.white.withValues(alpha: 0.85) : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildTableBlock(List<dynamic> rows, bool isDark) {
    if (rows.isEmpty) {
      return Text('Empty table',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary));
    }

    final headers =
        (rows.first as Map<String, dynamic>).keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.table_chart, size: 16, color: Colors.blueAccent.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text('Table', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF333333) : const Color(0xFFF0F4F0)),
            dataRowColor: WidgetStateProperty.all(Colors.transparent),
            border: TableBorder.all(
              color: isDark ? Colors.white12 : AppColors.divider,
              borderRadius: BorderRadius.circular(8),
            ),
            columns: headers
                .map((h) => DataColumn(
                      label: Text(
                        h,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ))
                .toList(),
            rows: rows.map((row) {
              final r = row as Map<String, dynamic>;
              return DataRow(
                cells: headers
                    .map((h) => DataCell(Text(
                          r[h]?.toString() ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : AppColors.textPrimary),
                        )))
                    .toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildImageBlock(String prompt, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A35) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD0D8E0),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined,
              size: 32, color: isDark ? Colors.white38 : Colors.blueGrey),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Image Placeholder',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.blueGrey),
                ),
                const SizedBox(height: 4),
                Text(
                  prompt,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white38 : Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Action bar (Publish / Reset)
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
                _isPublishing ? 'Publishing…' : 'Save to Firestore',
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
              foregroundColor: isDark ? Colors.white60 : AppColors.textSecondary,
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
}
