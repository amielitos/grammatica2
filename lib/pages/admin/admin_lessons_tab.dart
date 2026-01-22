import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../widgets/markdown_guide_button.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../lesson_page.dart';
import '../../services/role_service.dart';

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
  List<PlatformFile> _selectedFiles = [];
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return StreamBuilder<UserRole>(
      stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
      builder: (context, roleSnap) {
        final role = roleSnap.data ?? UserRole.learner;
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
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
                                        : const Icon(
                                            CupertinoIcons.floppy_disk,
                                          ),
                                    label: Text(
                                      _selectedLessonId == null
                                          ? 'Create'
                                          : 'Update',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  ),
                                  if (_selectedLessonId != null) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () =>
                                          setState(() => _resetForm()),
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
                                _buildInputFields(),
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),
                                Text(
                                  'Preview',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                _buildPreviewArea(),
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
                stream: DatabaseService.instance.streamLessons(
                  approvedOnly: false,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lessons = snapshot.data!;
                  final currentUser = AuthService.instance.currentUser;
                  final filteredLessons = lessons.where((l) {
                    final isAdmin = role == UserRole.admin;
                    final isOwner = l.createdByUid == currentUser?.uid;
                    if (isAdmin || isOwner) return true;
                    return l.isVisible;
                  }).toList();

                  if (filteredLessons.isEmpty) {
                    return const Center(child: Text('No lessons yet'));
                  }

                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: filteredLessons.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final l = filteredLessons[index];
                      final isSelected = _selectedLessonId == l.id;
                      final color = AppColors.primaryGreen;

                      final isAdmin = role == UserRole.admin;
                      final isOwner = l.createdByUid == currentUser?.uid;
                      final canEdit = isAdmin || isOwner;
                      final isPending =
                          l.validationStatus == 'awaiting_approval';

                      return GlassCard(
                        onTap: () {
                          if (!canEdit) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LessonPage(user: currentUser!, lesson: l),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            if (isSelected) {
                              _resetForm();
                            } else {
                              _selectedLessonId = l.id;
                              _selectedLesson = l;
                              _title.text = l.title;
                              _prompt.text = l.prompt;
                              _selectedFiles = [];
                              _isVisible = l.isVisible;
                            }
                          });
                        },
                        backgroundColor: isSelected
                            ? color
                            : (!canEdit
                                  ? Colors.grey.withValues(alpha: 0.05)
                                  : null),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isPending ? Colors.orange : color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: !canEdit
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (isPending)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: const Text(
                                            'Awaiting Approval',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l.prompt,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: !canEdit ? Colors.grey : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      if (l.attachmentName != null &&
                                          l.attachmentName!.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
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
                                        'Created: ${_fmt(l.createdAt ?? Timestamp.now())} • Visible: ${l.isVisible ? 'Yes' : 'No'}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      if (l.createdByEmail != null)
                                        Text(
                                          'By: ${l.createdByEmail}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (canEdit)
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
      },
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
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Visible to Public'),
          subtitle: const Text('If off, learners cannot see this lesson'),
          value: _isVisible,
          onChanged: (v) => setState(() => _isVisible = v),
          activeThumbColor: AppColors.primaryGreen,
        ),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: MarkdownGuideButton(),
        ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUploadUI(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
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
    _isVisible = true;
    setState(() {});
  }

  Future<void> _saveLesson() async {
    setState(() => _creatingLesson = true);
    try {
      String? attachmentUrl;
      String? attachmentName;

      if (_selectedFiles.isNotEmpty) {
        final file = _selectedFiles.first;
        if (file.size > 2 * 1024 * 1024) {
          throw Exception('File size must be less than 2MB');
        }
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
          isVisible: _isVisible,
        );
        if (mounted) {
          final role = await RoleService.instance.getRole(
            AuthService.instance.currentUser?.uid ?? '',
          );
          final isEducator = role == UserRole.educator;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEducator ? 'Lesson submitted for approval' : 'Lesson created',
              ),
            ),
          );
        }
      } else {
        await DatabaseService.instance.updateLesson(
          id: _selectedLessonId!,
          title: _title.text.trim(),
          prompt: _prompt.text.trim(),
          answer: '',
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          isVisible: _isVisible,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lesson updated')));
        }
      }
      if (mounted) _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}
