import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/notebook_models.dart';
import '../../services/notebook_service.dart';
import '../../services/source_ingestion_service.dart';
import '../../theme/app_colors.dart';

/// Left-hand panel in the Notebook detail view for managing, uploading,
/// and inspecting ingested sources (PDFs, text notes, web URLs, audio, video).
class SourceUploadPanel extends StatefulWidget {
  final String notebookId;
  final List<NotebookSource> sources;
  final Function(NotebookSource) onSourceSelected;
  final NotebookSource? selectedSource;

  const SourceUploadPanel({
    super.key,
    required this.notebookId,
    required this.sources,
    required this.onSourceSelected,
    this.selectedSource,
  });

  @override
  State<SourceUploadPanel> createState() => _SourceUploadPanelState();
}

class _SourceUploadPanelState extends State<SourceUploadPanel> {
  bool _isUploading = false;
  String _uploadStatus = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182017) : const Color(0xFFF7F9F6),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.source_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Sources',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.sources.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  tooltip: 'Add Source',
                  onPressed: _isUploading ? null : _showAddSourceModal,
                ),
              ],
            ),
          ),

          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadStatus,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(height: 1),

          // Source List
          Expanded(
            child: widget.sources.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: widget.sources.length,
                    itemBuilder: (context, index) {
                      final source = widget.sources[index];
                      final isSelected = widget.selectedSource?.id == source.id;
                      return _buildSourceCard(source, isSelected, isDark);
                    },
                  ),
          ),

          // Bottom Quick Upload Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _showAddSourceModal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Source'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No sources added yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add PDFs, notes, URLs, audio, or video files to ground AI generations in your material.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(NotebookSource source, bool isSelected, bool isDark) {
    IconData icon;
    Color iconColor;

    switch (source.type) {
      case SourceType.pdf:
        icon = Icons.picture_as_pdf_rounded;
        iconColor = const Color(0xFFE53935);
        break;
      case SourceType.text:
        icon = Icons.edit_note_rounded;
        iconColor = const Color(0xFF2E7D32);
        break;
      case SourceType.url:
        icon = Icons.link_rounded;
        iconColor = const Color(0xFF1976D2);
        break;
      case SourceType.audio:
        icon = Icons.audiotrack_rounded;
        iconColor = const Color(0xFF8E24AA);
        break;
      case SourceType.video:
        icon = Icons.video_file_rounded;
        iconColor = const Color(0xFFFB8C00);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF222B21) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: () => widget.onSourceSelected(source),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          source.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Text(
                '${source.wordCount} words',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              if (source.processingStatus == SourceProcessingStatus.processing)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else if (source.processingStatus == SourceProcessingStatus.error)
                const Icon(Icons.error_outline, size: 12, color: Colors.red),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 18,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          onSelected: (val) {
            if (val == 'delete') {
              _deleteSource(source);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSourceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Source to Notebook',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSourceOption(
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFE53935),
                  title: 'Upload PDF Document',
                  subtitle: 'Extract text, summaries, and concepts from PDF files',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPdf();
                  },
                ),
                _buildSourceOption(
                  icon: Icons.edit_note_rounded,
                  color: const Color(0xFF2E7D32),
                  title: 'Paste Text or Markdown',
                  subtitle: 'Directly paste notes, lectures, or articles',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPasteTextDialog();
                  },
                ),
                _buildSourceOption(
                  icon: Icons.link_rounded,
                  color: const Color(0xFF1976D2),
                  title: 'Web Link / URL',
                  subtitle: 'Fetch and extract readable content from a webpage',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUrlDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      setState(() {
        _isUploading = true;
        _uploadStatus = 'Extracting text from ${file.name}...';
      });

      try {
        final source = await SourceIngestionService.instance.ingestPdf(
          notebookId: widget.notebookId,
          title: file.name,
          bytes: file.bytes!,
          filename: file.name,
        );

        await NotebookService.instance.addSource(widget.notebookId, source);
      } catch (e) {
        _showErrorSnackBar('Error adding PDF: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }


  void _showPasteTextDialog() {
    final titleController = TextEditingController();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Text Note'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Note Title',
                  hintText: 'e.g., Chapter 1 Summary',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Paste lecture notes, study content, or excerpts here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              setState(() {
                _isUploading = true;
                _uploadStatus = 'Saving text note...';
              });

              try {
                final source = await SourceIngestionService.instance.ingestText(
                  notebookId: widget.notebookId,
                  title: titleController.text.trim().isNotEmpty
                      ? titleController.text.trim()
                      : 'Text Note',
                  text: textController.text,
                );

                await NotebookService.instance.addSource(widget.notebookId, source);
              } catch (e) {
                _showErrorSnackBar('Error saving note: $e');
              } finally {
                if (mounted) setState(() => _isUploading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Note'),
          ),
        ],
      ),
    );
  }

  void _showUrlDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Web Link'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Webpage URL',
                  hintText: 'https://en.wikipedia.org/...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Custom Title (Optional)',
                  hintText: 'Leave blank to use page title',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (urlController.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              setState(() {
                _isUploading = true;
                _uploadStatus = 'Fetching webpage content...';
              });

              try {
                final source = await SourceIngestionService.instance.ingestUrl(
                  notebookId: widget.notebookId,
                  url: urlController.text.trim(),
                  customTitle: titleController.text.trim().isNotEmpty
                      ? titleController.text.trim()
                      : null,
                );

                await NotebookService.instance.addSource(widget.notebookId, source);
              } catch (e) {
                _showErrorSnackBar('Error fetching URL: $e');
              } finally {
                if (mounted) setState(() => _isUploading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Fetch & Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSource(NotebookSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Source?'),
        content: Text('Are you sure you want to remove "${source.title}" from this notebook?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotebookService.instance.deleteSource(widget.notebookId, source.id);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
