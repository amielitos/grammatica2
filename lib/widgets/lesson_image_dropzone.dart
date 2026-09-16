import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../theme/app_colors.dart';
import '../utils/file_helper.dart';

/// Interactive drag-and-drop & click-to-upload card for lesson visual placeholders.
///
/// Supports cross-platform drag-and-drop via [desktop_drop] and file picker
/// browsing via [file_picker]. Displays live uploading progress, high-resolution
/// image previews, and allows replacing or removing images.
class LessonImageDropzone extends StatefulWidget {
  final String imagePrompt;
  final String? currentImageUrl;
  final Uint8List? pendingBytes;
  final bool isUploading;
  final String? uploadStatus;
  final Future<void> Function(Uint8List bytes, String fileName) onImageSelected;
  final VoidCallback? onRemoveImage;
  final bool isDark;

  const LessonImageDropzone({
    super.key,
    required this.imagePrompt,
    this.currentImageUrl,
    this.pendingBytes,
    this.isUploading = false,
    this.uploadStatus,
    required this.onImageSelected,
    this.onRemoveImage,
    required this.isDark,
  });

  @override
  State<LessonImageDropzone> createState() => _LessonImageDropzoneState();
}

class _LessonImageDropzoneState extends State<LessonImageDropzone> {
  bool _isDragging = false;

  bool get _hasImage =>
      widget.pendingBytes != null ||
      (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty);

  Future<void> _pickFile() async {
    if (widget.isUploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;
      final bytes = await FileHelper.readBytes(platformFile.path, platformFile.bytes);
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Could not read image file data.');
      }

      await widget.onImageSelected(Uint8List.fromList(bytes), platformFile.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  bool _isSupportedExtension(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  Future<void> _handleDropDone(DropDoneDetails detail) async {
    setState(() => _isDragging = false);
    if (widget.isUploading || detail.files.isEmpty) return;

    final file = detail.files.first;
    if (!_isSupportedExtension(file.name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please drop a valid image file (PNG, JPG, WEBP, or GIF).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Dropped file is empty.');
      }
      await widget.onImageSelected(bytes, file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing dropped image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = AppColors.primary;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _handleDropDone,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isDragging
              ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF222B21) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDragging
                ? primaryColor
                : (_hasImage
                    ? primaryColor.withValues(alpha: 0.6)
                    : (isDark ? Colors.white12 : Colors.grey.shade300)),
            width: _isDragging ? 2.2 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: widget.isUploading
              ? _buildUploadingView(isDark)
              : (_hasImage ? _buildPreviewView(isDark) : _buildEmptyDropzone(isDark)),
        ),
      ),
    );
  }

  Widget _buildUploadingView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.uploadStatus ?? 'Uploading image to storage...',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compressing and attaching visual aid to lesson',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image display area
        Stack(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 320),
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.04),
              child: Center(
                child: widget.pendingBytes != null
                    ? Image.memory(
                        widget.pendingBytes!,
                        fit: BoxFit.contain,
                        height: 280,
                      )
                    : Image.network(
                        widget.currentImageUrl!,
                        fit: BoxFit.contain,
                        height: 280,
                        errorBuilder: (context, error, stackTrace) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'Could not preview image',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Top Status Pill
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      'Visual Aid Ready',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Drag over banner if hovering a replacement
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload_rounded, size: 48, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          'Drop photo to replace image',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Caption & action buttons footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B231A) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.imagePrompt.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.imagePrompt,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : AppColors.textPrimary,
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _pickFile,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Change Photo',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.onRemoveImage != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: widget.onRemoveImage,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(
                        'Remove',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDropzone(bool isDark) {
    return InkWell(
      onTap: _pickFile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with animated highlight
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isDragging
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDragging ? Icons.file_download_rounded : Icons.cloud_upload_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isDragging ? 'Drop photo to upload' : 'Drag & drop photo or click to upload',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Supports PNG, JPG, JPEG, WEBP, or GIF',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            // AI suggested prompt bubble
            if (widget.imagePrompt.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF192018) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.imagePrompt,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
