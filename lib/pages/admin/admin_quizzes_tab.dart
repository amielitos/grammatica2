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
import '../../services/role_service.dart';

class AdminQuizzesTab extends StatefulWidget {
  const AdminQuizzesTab({super.key});
  @override
  State<AdminQuizzesTab> createState() => _AdminQuizzesTabState();
}

class _AdminQuizzesTabState extends State<AdminQuizzesTab> {
  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String? _selectedQuizId;
  bool _creatingOrUpdating = false;
  final _title = TextEditingController();
  final _question = TextEditingController();
  final _answer = TextEditingController();
  final _maxAttemptsCtrl = TextEditingController(text: '1');
  List<PlatformFile> _selectedFiles = []; // Store selected files
  String? _currentAttachmentName;
  String? _currentAttachmentUrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                                'Manage Quizzes',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed:
                                    (_creatingOrUpdating ||
                                        _title.text.trim().isEmpty)
                                    ? null
                                    : _saveQuiz,
                                icon: _creatingOrUpdating
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
                                  _selectedQuizId == null ? 'Create' : 'Update',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                              ),
                              if (_selectedQuizId != null) ...[
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _resetForm,
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
                              style: Theme.of(context).textTheme.titleMedium,
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

          StreamBuilder<List<Quiz>>(
            stream: DatabaseService.instance.streamQuizzes(approvedOnly: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              if (items.isEmpty)
                return const Center(child: Text('No quizzes yet'));

              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final q = items[index];
                  final isSelected = _selectedQuizId == q.id;
                  final color = AppColors.primaryGreen;

                  final currentUser = AuthService.instance.currentUser;
                  return StreamBuilder<UserRole>(
                    stream: currentUser != null
                        ? RoleService.instance.roleStream(currentUser.uid)
                        : null,
                    builder: (context, roleSnap) {
                      final role = roleSnap.data;
                      final isOwner = q.createdByUid == currentUser?.uid;
                      final isAdmin = role == UserRole.admin;
                      final canEdit = isAdmin || isOwner;
                      final isPending =
                          q.validationStatus == 'awaiting_approval';

                      return GlassCard(
                        backgroundColor: isSelected
                            ? color
                            : (!canEdit ? Colors.grey.withOpacity(0.05) : null),
                        onTap: () {
                          if (!canEdit) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You can only edit your own quizzes.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            if (isSelected) {
                              _resetForm();
                            } else {
                              _selectedQuizId = q.id;
                              _title.text = q.title;
                              _question.text = q.question;
                              _answer.text = q.answer;
                              _maxAttemptsCtrl.text = q.maxAttempts.toString();
                              _currentAttachmentName = q.attachmentName;
                              _currentAttachmentUrl = q.attachmentUrl;
                              _selectedFiles = [];
                            }
                          });
                        },
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
                                          q.title,
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
                                              color: Colors.orange.withOpacity(
                                                0.5,
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
                                    q.question,
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
                                      if (q.attachmentName != null &&
                                          q.attachmentName!.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              CupertinoIcons.paperclip,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              q.attachmentName!,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      Text(
                                        'Created: ${_fmt(q.createdAt ?? Timestamp.now())} • Attempts: ${q.maxAttempts}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      if (q.createdByEmail != null)
                                        Text(
                                          'By: ${q.createdByEmail}',
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
                              icon: const Icon(CupertinoIcons.graph_square),
                              onPressed: () => _showResults(q.id, q.title),
                            ),
                            if (canEdit)
                              IconButton(
                                icon: const Icon(CupertinoIcons.trash),
                                color: Colors.red[300],
                                onPressed: () => _deleteQuiz(q),
                              ),
                          ],
                        ),
                      );
                    },
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
          controller: _question,
          minLines: 6,
          maxLines: 15,
          decoration: const InputDecoration(
            labelText: 'Question (Markdown)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: MarkdownGuideButton(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _answer,
          decoration: const InputDecoration(labelText: 'Answer'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _maxAttemptsCtrl,
          decoration: const InputDecoration(labelText: 'Max Attempts'),
          keyboardType: TextInputType.number,
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
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          ),
          child: MarkdownBody(
            data: _question.text.isEmpty
                ? '_Nothing to preview_'
                : _question.text,
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
            }
          },
          icon: const Icon(CupertinoIcons.arrow_up_doc),
          label: const Text('Upload PDF'),
        ),
        if (_selectedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Chip(
              label: Text(_selectedFiles.first.name),
              onDeleted: () => setState(() => _selectedFiles = []),
            ),
          )
        else if (_currentAttachmentName != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Chip(
              avatar: const Icon(CupertinoIcons.paperclip, size: 16),
              label: Text('Current: $_currentAttachmentName'),
            ),
          ),
      ],
    );
  }

  void _resetForm() {
    _selectedQuizId = null;
    _title.clear();
    _question.clear();
    _answer.clear();
    _maxAttemptsCtrl.text = '1';
    _selectedFiles = [];
    _currentAttachmentName = null;
    _currentAttachmentUrl = null;
    setState(() {});
  }

  Future<void> _saveQuiz() async {
    setState(() => _creatingOrUpdating = true);
    try {
      String? attachmentUrl;
      String? attachmentName;

      if (_selectedFiles.isNotEmpty) {
        final file = _selectedFiles.first;
        if (file.size > 2 * 1024 * 1024) throw Exception('File size > 2MB');
        if (file.bytes != null) {
          attachmentUrl = await DatabaseService.instance.uploadDocument(
            fileBytes: file.bytes!,
            fileName: file.name,
            folder: 'quizzes',
          );
          attachmentName = file.name;
        }
      } else if (_selectedQuizId != null) {
        attachmentUrl = _currentAttachmentUrl;
        attachmentName = _currentAttachmentName;
      }

      if (_selectedQuizId == null) {
        await DatabaseService.instance.createQuiz(
          title: _title.text.trim(),
          question: _question.text.trim(),
          answer: _answer.text.trim(),
          maxAttempts: int.tryParse(_maxAttemptsCtrl.text) ?? 1,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
        );
        if (mounted) {
          final role = await RoleService.instance.getRole(
            AuthService.instance.currentUser?.uid ?? '',
          );
          final isEducator = role == UserRole.educator;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEducator ? 'Quiz submitted for approval' : 'Quiz created',
              ),
            ),
          );
        }
      } else {
        await DatabaseService.instance.updateQuiz(
          id: _selectedQuizId!,
          title: _title.text.trim(),
          question: _question.text.trim(),
          answer: _answer.text.trim(),
          maxAttempts: int.tryParse(_maxAttemptsCtrl.text),
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Quiz updated')));
      }
      if (mounted) _resetForm();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _creatingOrUpdating = false);
    }
  }

  Future<void> _deleteQuiz(Quiz q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${q.title}"?'),
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
    await DatabaseService.instance.deleteQuiz(q.id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quiz deleted')));
      if (_selectedQuizId == q.id) _resetForm();
    }
  }

  void _showResults(String quizId, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Results: $title'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseService.instance.fetchQuizResults(quizId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final results = snapshot.data ?? [];
                if (results.isEmpty)
                  return const Center(child: Text('No attempts recorded.'));
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final r = results[index];
                    final passed = r['completed'] == true;
                    return ListTile(
                      title: Text(
                        r['username'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(r['email'] ?? ''),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: passed
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: passed
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.red.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              passed ? "Passed" : "Failed",
                              style: TextStyle(
                                color: passed
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attempts: ${r['attemptsUsed']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
