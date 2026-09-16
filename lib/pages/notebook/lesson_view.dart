import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ai_models.dart';
import '../../models/notebook_models.dart';
import '../../services/notebook_service.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/interactive_markdown.dart';
import '../../widgets/lesson_image_dropzone.dart';
import 'publish_content_dialogs.dart';

/// In-Notebook visual workspace and editor for generated interactive lessons.
///
/// Displays generated markdown text, list blocks, tables, and image placeholders,
/// allowing educators to review, make quick inline edits, and publish directly
/// to the live curriculum or open in the full lesson studio.
class LessonView extends StatefulWidget {
  final NotebookOutput output;
  final String notebookId;
  final VoidCallback? onRegenerate;
  final Function(String lessonId)? onLessonPublished;

  const LessonView({
    super.key,
    required this.output,
    required this.notebookId,
    this.onRegenerate,
    this.onLessonPublished,
  });

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  late AILessonResponse _lesson;
  late TextEditingController _titleCtrl;
  final List<TextEditingController> _blockCtrls = [];
  final Set<int> _uploadingBlockIndices = {};
  bool _isEditingInline = false;
  bool _hasUnsavedEdits = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(LessonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.output.id != oldWidget.output.id ||
        widget.output.data != oldWidget.output.data) {
      _disposeControllers();
      _initData();
    }
  }

  void _initData() {
    _lesson = AILessonResponse.fromNotebookOutput(widget.output);
    _titleCtrl = TextEditingController(text: _lesson.title);
    _blockCtrls.clear();

    for (final block in _lesson.content) {
      String text = '';
      switch (block.type) {
        case ContentBlockType.text:
          text = block.data.toString();
          break;
        case ContentBlockType.list:
          if (block.data is List) {
            text = (block.data as List).map((item) => '• $item').join('\n');
          } else {
            text = block.data.toString();
          }
          break;
        case ContentBlockType.table:
          if (block.data is List && (block.data as List).isNotEmpty) {
            final rows = block.data as List;
            final headers = (rows.first as Map<String, dynamic>).keys.toList();
            final buf = StringBuffer('| ${headers.join(' | ')} |\n');
            buf.writeln('| ${headers.map((_) => '---').join(' | ')} |');
            for (final row in rows) {
              final r = row as Map<String, dynamic>;
              buf.writeln(
                  '| ${headers.map((h) => r[h]?.toString() ?? '').join(' | ')} |');
            }
            text = buf.toString();
          } else {
            text = '';
          }
          break;
        case ContentBlockType.image:
          if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
            text = '![${block.data}](${block.imageUrl})';
          } else {
            text = '[Image Placeholder: ${block.data}]';
          }
          break;
      }
      _blockCtrls.add(TextEditingController(text: text));
    }
  }

  void _disposeControllers() {
    _titleCtrl.dispose();
    for (final c in _blockCtrls) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  String _assembleMarkdown() {
    return _blockCtrls.map((c) => c.text.trim()).join('\n\n');
  }

  Future<void> _handleImageUpload(int blockIndex, Uint8List bytes, String fileName) async {
    setState(() => _uploadingBlockIndices.add(blockIndex));
    try {
      final folder = 'lesson_images/notebook_${widget.notebookId}';
      final downloadUrl = await DatabaseService.instance.uploadGeneratedImage(
        bytes,
        fileName,
        folder: folder,
      );

      final oldBlock = _lesson.content[blockIndex];
      final updatedBlock = oldBlock.copyWith(
        type: ContentBlockType.image,
        imageUrl: downloadUrl,
      );

      final newContent = List<ContentBlock>.from(_lesson.content);
      newContent[blockIndex] = updatedBlock;

      final updatedLesson = AILessonResponse(
        title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : _lesson.title,
        content: newContent,
      );

      final updatedOutput = widget.output.copyWith(
        title: updatedLesson.title,
        data: updatedLesson.toJson(),
      );

      await NotebookService.instance.updateOutput(widget.notebookId, updatedOutput);

      if (mounted) {
        setState(() {
          _lesson = updatedLesson;
          _uploadingBlockIndices.remove(blockIndex);
          if (blockIndex < _blockCtrls.length) {
            _blockCtrls[blockIndex].text = '![${oldBlock.data}]($downloadUrl)';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visual aid uploaded and attached to lesson!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingBlockIndices.remove(blockIndex));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleRemoveImage(int blockIndex) async {
    final oldBlock = _lesson.content[blockIndex];
    final updatedBlock = ContentBlock(
      type: ContentBlockType.image,
      data: oldBlock.data,
      imageUrl: null,
    );

    final newContent = List<ContentBlock>.from(_lesson.content);
    newContent[blockIndex] = updatedBlock;

    final updatedLesson = AILessonResponse(
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : _lesson.title,
      content: newContent,
    );

    final updatedOutput = widget.output.copyWith(
      title: updatedLesson.title,
      data: updatedLesson.toJson(),
    );

    await NotebookService.instance.updateOutput(widget.notebookId, updatedOutput);

    if (mounted) {
      setState(() {
        _lesson = updatedLesson;
        if (blockIndex < _blockCtrls.length) {
          _blockCtrls[blockIndex].text = '[Image Placeholder: ${oldBlock.data}]';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image removed from lesson.')),
      );
    }
  }

  Future<void> _saveInlineEdits() async {
    final updatedBlocks = <ContentBlock>[];
    for (int i = 0; i < _blockCtrls.length; i++) {
      final originalBlock = i < _lesson.content.length ? _lesson.content[i] : null;
      final editedText = _blockCtrls[i].text.trim();

      if (originalBlock != null && originalBlock.type == ContentBlockType.image) {
        updatedBlocks.add(originalBlock);
      } else {
        updatedBlocks.add(ContentBlock(
          type: originalBlock?.type ?? ContentBlockType.text,
          data: editedText,
        ));
      }
    }

    final updatedLesson = AILessonResponse(
      title: _titleCtrl.text.trim(),
      content: updatedBlocks,
    );

    final updatedOutput = widget.output.copyWith(
      title: _titleCtrl.text.trim(),
      data: updatedLesson.toJson(),
    );

    await NotebookService.instance.updateOutput(widget.notebookId, updatedOutput);

    setState(() {
      _lesson = updatedLesson;
      _isEditingInline = false;
      _hasUnsavedEdits = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson drafts saved to notebook session!')),
      );
    }
  }

  void _openPublishDialog() {
    showDialog(
      context: context,
      builder: (ctx) => PublishLessonDialog(
        notebookId: widget.notebookId,
        output: widget.output,
        markdownPrompt: _assembleMarkdown(),
        onPublished: () {
          setState(() {});
          widget.onLessonPublished?.call(widget.output.publishedId ?? '');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBar(isDark),
          const SizedBox(height: 24),
          _buildActionRibbon(isDark),
          const SizedBox(height: 24),
          _buildLessonContentBlocks(isDark),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E261D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'INTERACTIVE LESSON',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (widget.output.isPublished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'Live in Curriculum',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Local Draft Session',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              if (_hasUnsavedEdits)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Unsaved changes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _isEditingInline
              ? TextField(
                  controller: _titleCtrl,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _hasUnsavedEdits = true,
                )
              : Text(
                  _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Untitled Lesson',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
          const SizedBox(height: 8),
          Text(
            'Synthesized from ${widget.output.sourceIds.length} notebook sources. Review blocks below.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white60 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRibbon(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Publish to Curriculum Button
        ElevatedButton.icon(
          onPressed: _openPublishDialog,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: Text(
            widget.output.isPublished ? 'Update in Curriculum' : 'Publish to Curriculum',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),


        // Inline Edit / Save Toggle
        if (!_isEditingInline)
          OutlinedButton.icon(
            onPressed: () => setState(() => _isEditingInline = true),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(
              'Quick Edit Text',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : AppColors.textPrimary,
              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _saveInlineEdits,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              'Save Edits',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

        if (widget.onRegenerate != null)
          TextButton.icon(
            onPressed: widget.onRegenerate,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Regenerate', style: GoogleFonts.inter(fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildLessonContentBlocks(bool isDark) {
    if (_blockCtrls.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E261D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No content blocks available in this lesson.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(_blockCtrls.length, (index) {
        final ctrl = _blockCtrls[index];
        final rawBlock = index < _lesson.content.length ? _lesson.content[index] : null;
        final isImage = rawBlock?.type == ContentBlockType.image;

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E261D) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header tag per block
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SECTION ${index + 1} (${rawBlock?.type.name.toUpperCase() ?? 'TEXT'})',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isImage)
                _buildImageBlockPlaceholder(index, rawBlock!, isDark)
              else if (_isEditingInline)
                TextField(
                  controller: ctrl,
                  maxLines: 10,
                  minLines: 3,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A3428) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  onChanged: (_) => _hasUnsavedEdits = true,
                )
              else
                InteractiveMarkdown(data: ctrl.text.trim()),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildImageBlockPlaceholder(int blockIndex, ContentBlock block, bool isDark) {
    return LessonImageDropzone(
      imagePrompt: block.data.toString(),
      currentImageUrl: block.imageUrl,
      isUploading: _uploadingBlockIndices.contains(blockIndex),
      onImageSelected: (bytes, fileName) => _handleImageUpload(blockIndex, bytes, fileName),
      onRemoveImage: (block.imageUrl != null && block.imageUrl!.isNotEmpty)
          ? () => _handleRemoveImage(blockIndex)
          : null,
      isDark: isDark,
    );
  }
}
