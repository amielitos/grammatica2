import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../quiz_detail_page.dart';

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
  final _description = TextEditingController();
  final _durationCtrl = TextEditingController(text: '0');
  final _maxAttemptsCtrl = TextEditingController(text: '1');

  List<TextEditingController> _questionCtrls = [TextEditingController()];
  List<TextEditingController> _answerCtrls = [TextEditingController()];
  List<String> _questionTypes = ['text'];
  List<List<TextEditingController>> _optionsCtrls = [[]];
  bool _isVisible = true;

  List<PlatformFile> _selectedFiles = [];
  String? _currentAttachmentName;
  String? _currentAttachmentUrl;

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
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Manage Quizzes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
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
                                        : const Icon(
                                            CupertinoIcons.floppy_disk,
                                          ),
                                    label: Text(
                                      _selectedQuizId == null
                                          ? 'Create'
                                          : 'Update',
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
                              _buildInputFields(),
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
                stream: DatabaseService.instance.streamQuizzes(
                  approvedOnly: false,
                  userRole: role,
                  userId: user?.uid,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;

                  if (items.isEmpty) {
                    return const Center(child: Text('No quizzes yet'));
                  }

                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final q = items[index];
                      final currentUser = AuthService.instance.currentUser;
                      final isAdmin = role == UserRole.admin;
                      final isOwner = q.createdByUid == currentUser?.uid;
                      final canEdit = isOwner; // Only owners can edit
                      final isPending =
                          q.validationStatus == 'awaiting_approval';
                      final isSelected = _selectedQuizId == q.id;
                      final color = AppColors.primaryGreen;

                      return GlassCard(
                        backgroundColor: isSelected
                            ? color
                            : (!canEdit
                                  ? Colors.grey.withValues(alpha: 0.05)
                                  : null),
                        onTap: () {
                          if (!canEdit) {
                            // If user cannot edit (e.g. educator viewing public content),
                            // navigate to the detail page for viewing/taking the quiz.
                            if (currentUser != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => QuizDetailPage(
                                    user: currentUser,
                                    quiz: q,
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          setState(() {
                            if (isSelected) {
                              _resetForm();
                            } else {
                              _selectedQuizId = q.id;
                              _title.text = q.title;
                              _description.text = q.description;
                              _durationCtrl.text = q.duration.toString();
                              _maxAttemptsCtrl.text = q.maxAttempts.toString();
                              _currentAttachmentName = q.attachmentName;
                              _currentAttachmentUrl = q.attachmentUrl;
                              _selectedFiles = [];
                              _questionCtrls = q.questions
                                  .map(
                                    (qu) => TextEditingController(
                                      text: qu.question,
                                    ),
                                  )
                                  .toList();
                              _answerCtrls = q.questions
                                  .map(
                                    (qu) =>
                                        TextEditingController(text: qu.answer),
                                  )
                                  .toList();
                              _questionTypes = q.questions
                                  .map((qu) => qu.type)
                                  .toList();
                              _optionsCtrls = q.questions
                                  .map(
                                    (qu) => (qu.options ?? [])
                                        .map(
                                          (opt) =>
                                              TextEditingController(text: opt),
                                        )
                                        .toList(),
                                  )
                                  .toList();
                              _isVisible = q.isVisible;
                              if (_questionCtrls.isEmpty) {
                                _questionCtrls = [TextEditingController()];
                                _answerCtrls = [TextEditingController()];
                                _questionTypes = ['text'];
                                _optionsCtrls = [[]];
                              }
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
                                            color: Colors.orange.withValues(
                                              alpha: 0.2,
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
                                    q.description,
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
                                        'Created: ${_fmt(q.createdAt ?? Timestamp.now())} • Qs: ${q.questions.length} • ${q.duration}m • Attempts: ${q.maxAttempts} • Visible: ${q.isVisible ? 'Yes' : 'No'}',
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
                            if (canEdit) // Only show stats to owner/editor
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
          controller: _description,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Duration (Minutes)',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxAttemptsCtrl,
                decoration: const InputDecoration(labelText: 'Max Attempts'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Visible to Public'),
          subtitle: const Text('If off, learners cannot see this quiz'),
          value: _isVisible,
          onChanged: (v) => setState(() => _isVisible = v),
          activeThumbColor: AppColors.primaryGreen,
        ),
        const SizedBox(height: 16),
        _buildUploadUI(),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text('Questions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(_questionCtrls.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: GlassCard(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primaryGreen,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_questionCtrls.length > 1)
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.minus_circle,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                _questionCtrls.removeAt(index);
                                _answerCtrls.removeAt(index);
                                _questionTypes.removeAt(index);
                                _optionsCtrls.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                    TextField(
                      controller: _questionCtrls[index],
                      decoration: const InputDecoration(labelText: 'Question'),
                      maxLines: null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _questionTypes[index],
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'text',
                          child: Text('Textfield'),
                        ),
                        DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Text('Multiple Choice'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _questionTypes[index] = v;
                            if (v == 'multiple_choice' &&
                                _optionsCtrls[index].isEmpty) {
                              _optionsCtrls[index] = [
                                TextEditingController(),
                                TextEditingController(),
                              ];
                            }
                          });
                        }
                      },
                    ),
                    if (_questionTypes[index] == 'multiple_choice') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Options',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...List.generate(_optionsCtrls[index].length, (optIdx) {
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _optionsCtrls[index][optIdx],
                                decoration: InputDecoration(
                                  labelText: 'Option ${optIdx + 1}',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(CupertinoIcons.minus_circle),
                              onPressed: () {
                                setState(() {
                                  _optionsCtrls[index].removeAt(optIdx);
                                });
                              },
                            ),
                          ],
                        );
                      }),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _optionsCtrls[index].add(TextEditingController());
                          });
                        },
                        icon: const Icon(CupertinoIcons.add),
                        label: const Text('Add Option'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _answerCtrls[index],
                      decoration: const InputDecoration(
                        labelText: 'Correct Answer',
                        hintText: 'Should match one of the options for MC',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _questionCtrls.add(TextEditingController());
                _answerCtrls.add(TextEditingController());
                _questionTypes.add('text');
                _optionsCtrls.add([]);
              });
            },
            icon: const Icon(CupertinoIcons.add_circled),
            label: const Text('Add Question'),
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
    _description.clear();
    _durationCtrl.text = '0';
    _maxAttemptsCtrl.text = '1';
    _selectedFiles = [];
    _currentAttachmentName = null;
    _currentAttachmentUrl = null;
    _questionCtrls = [TextEditingController()];
    _answerCtrls = [TextEditingController()];
    _questionTypes = ['text'];
    _optionsCtrls = [[]];
    _isVisible = true;
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

      final questions = List.generate(_questionCtrls.length, (i) {
        return QuizQuestion(
          question: _questionCtrls[i].text.trim(),
          answer: _answerCtrls[i].text.trim(),
          type: _questionTypes[i],
          options: _questionTypes[i] == 'multiple_choice'
              ? _optionsCtrls[i]
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList()
              : null,
        );
      }).where((q) => q.question.isNotEmpty).toList();

      if (questions.isEmpty) throw Exception('Add at least one question');

      if (_selectedQuizId == null) {
        await DatabaseService.instance.createQuiz(
          title: _title.text.trim(),
          description: _description.text.trim(),
          questions: questions,
          duration: int.tryParse(_durationCtrl.text) ?? 0,
          maxAttempts: int.tryParse(_maxAttemptsCtrl.text) ?? 1,
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
                isEducator ? 'Quiz submitted for approval' : 'Quiz created',
              ),
            ),
          );
        }
      } else {
        await DatabaseService.instance.updateQuiz(
          id: _selectedQuizId!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          questions: questions,
          duration: int.tryParse(_durationCtrl.text) ?? 0,
          maxAttempts: int.tryParse(_maxAttemptsCtrl.text),
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          isVisible: _isVisible,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Quiz updated')));
        }
      }
      if (mounted) _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final results = snapshot.data ?? [];
                if (results.isEmpty) {
                  return const Center(child: Text('No attempts recorded.'));
                }
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
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: passed
                                    ? Colors.green.withValues(alpha: 0.5)
                                    : Colors.red.withValues(alpha: 0.5),
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
