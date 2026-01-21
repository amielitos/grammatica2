import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../widgets/markdown_guide_button.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';

class AdminLessonsTab extends StatefulWidget {
  const AdminLessonsTab({super.key});
  @override
  State<AdminLessonsTab> createState() => _AdminLessonsTabState();
}

class _AdminLessonsTabState extends State<AdminLessonsTab> {
  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String? _selectedLessonId;
  Lesson? _selectedLesson;
  bool _creatingLesson = false;
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  bool _preview = true;
  List<PlatformFile> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Editor Section
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 900;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Manage Lessons',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed:
                                    (_creatingLesson ||
                                        _title.text.trim().isEmpty)
                                    ? null
                                    : _saveLesson,
                                icon: _creatingLesson
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(CupertinoIcons.floppy_disk),
                                label: Text(
                                  _selectedLessonId == null
                                      ? 'Create'
                                      : 'Update',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.rainbow.blue,
                                ),
                              ),
                              if (_selectedLessonId != null) ...[
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => setState(() => _resetForm()),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildInputFields()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildPreviewArea()),
                              ],
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: FilterChip(
                                    label: const Center(child: Text('Edit')),
                                    selected: !_preview,
                                    onSelected: (_) =>
                                        setState(() => _preview = false),
                                    checkmarkColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilterChip(
                                    avatar: const Icon(CupertinoIcons.eye),
                                    label: const Center(child: Text('Preview')),
                                    selected: _preview,
                                    onSelected: (_) =>
                                        setState(() => _preview = true),
                                    checkmarkColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _preview
                                ? _buildPreviewArea()
                                : _buildInputFields(),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // List of Lessons
          StreamBuilder<List<Lesson>>(
            stream: DatabaseService.instance.streamLessons(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final lessons = snapshot.data!;
              if (lessons.isEmpty)
                return const Center(child: Text('No lessons yet'));

              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: lessons.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final l = lessons[index];
                  final isSelected = _selectedLessonId == l.id;
                  final color = AppColors.rainbow.elementAt(index);

                  return GlassCard(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _resetForm();
                        } else {
                          _selectedLessonId = l.id;
                          _selectedLesson = l;
                          _title.text = l.title;
                          _prompt.text = l.prompt;
                          _selectedFiles = [];
                        }
                      });
                    },
                    backgroundColor: isSelected ? color : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 60,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                children: [
                                  if (l.attachmentName != null &&
                                      l.attachmentName!.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          CupertinoIcons.paperclip,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          l.attachmentName!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  Text(
                                    'Created: ${_fmt(l.createdAt ?? Timestamp.now())}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash),
                          color: Colors.red[300],
                          onPressed: () => _deleteLesson(l),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _prompt,
          minLines: 6,
          maxLines: 15,
          decoration: const InputDecoration(
            labelText: 'Content (Markdown)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: MarkdownGuideButton(),
        ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUploadUI(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.5),
          ),
          child: MarkdownBody(
            data: _prompt.text.isEmpty ? '_Nothing to preview_' : _prompt.text,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowMultiple: false,
              allowedExtensions: ['pdf'],
              withData: true,
            );
            if (!mounted) return;
            if (result != null) {
              setState(() => _selectedFiles = result.files);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected: ${result.files.first.name}')),
              );
            }
          },
          icon: const Icon(CupertinoIcons.arrow_up_doc),
          label: const Text('Upload PDF Attachment'),
        ),
        if (_selectedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Chip(
              label: Text(_selectedFiles.first.name),
              onDeleted: () => setState(() => _selectedFiles = []),
            ),
          )
        else if (_selectedLesson?.attachmentName != null &&
            _selectedLesson!.attachmentName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Chip(
              avatar: const Icon(CupertinoIcons.paperclip, size: 16),
              label: Text('Current: ${_selectedLesson!.attachmentName}'),
            ),
          ),
      ],
    );
  }

  void _resetForm() {
    _selectedLessonId = null;
    _selectedLesson = null;
    _title.clear();
    _prompt.clear();
    _selectedFiles = [];
  }

  Future<void> _saveLesson() async {
    setState(() => _creatingLesson = true);
    try {
      String? attachmentUrl;
      String? attachmentName;

      if (_selectedFiles.isNotEmpty) {
        final file = _selectedFiles.first;
        if (file.size > 2 * 1024 * 1024)
          throw Exception('File size must be less than 2MB');
        if (file.bytes != null) {
          attachmentUrl = await DatabaseService.instance.uploadDocument(
            fileBytes: file.bytes!,
            fileName: file.name,
            folder: 'lessons',
          );
          attachmentName = file.name;
        }
      } else if (_selectedLesson != null) {
        attachmentUrl = _selectedLesson!.attachmentUrl;
        attachmentName = _selectedLesson!.attachmentName;
      }

      if (_selectedLessonId == null) {
        await DatabaseService.instance.createLesson(
          title: _title.text.trim(),
          prompt: _prompt.text.trim(),
          answer: '',
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lesson created')));
      } else {
        await DatabaseService.instance.updateLesson(
          id: _selectedLessonId!,
          title: _title.text.trim(),
          prompt: _prompt.text.trim(),
          answer: '',
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lesson updated')));
      }
      if (mounted) _resetForm();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _creatingLesson = false);
    }
  }

  Future<void> _deleteLesson(Lesson l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${l.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DatabaseService.instance.deleteLesson(l.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lesson deleted')));
        if (_selectedLessonId == l.id) _resetForm();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}
