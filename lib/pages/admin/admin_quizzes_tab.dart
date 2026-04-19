import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/content_visibility.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../widgets/user_visibility_selector.dart';
import '../../services/ai_logic_service.dart';
import 'dart:io';

class AdminQuizzesTab extends StatefulWidget {
  final bool isEmbedded;
  final Function(String?)? onQuizSaved;
  final String? initialQuizId;
  final VoidCallback? onChanged;

  const AdminQuizzesTab({
    super.key,
    this.isEmbedded = false,
    this.onQuizSaved,
    this.initialQuizId,
    this.onChanged,
  });

  @override
  State<AdminQuizzesTab> createState() => AdminQuizzesTabState();
}

class AdminQuizzesTabState extends State<AdminQuizzesTab> {
  String? _selectedQuizId;
  bool _creatingOrUpdating = false;
  bool _isGeneratingFromPdf = false;
  final AILogicService _aiLogicService = AILogicService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _durationCtrl = TextEditingController(text: '00:00:00');
  final _maxAttemptsCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _title.addListener(_notifyChanged);
    _description.addListener(_notifyChanged);
    if (widget.initialQuizId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadQuiz(widget.initialQuizId!);
      });
    }
  }

  void _notifyChanged() {
    if (widget.onChanged != null) {
      widget.onChanged!();
    }
  }

  bool get isEmpty {
    if (_title.text.trim().isNotEmpty) return false;
    if (_description.text.trim().isNotEmpty) return false;
    if (_questionCtrls.any((c) => c.text.trim().isNotEmpty)) return false;
    return true;
  }

  String? validateQuiz() {
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

    if (questions.isEmpty) return 'Add at least one question';

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (q.question.isEmpty) return 'Question ${i + 1} is empty';
      if (q.answer.isEmpty)
        return 'Question ${i + 1} has no correct answer selected';
      if (q.type == 'multiple_choice') {
        if (q.options == null || q.options!.length < 2) {
          return 'Question ${i + 1} must have at least 2 options';
        }
        if (!q.options!.contains(q.answer)) {
          return 'Question ${i + 1} correct answer is not among the options';
        }
      }
    }
    return null;
  }

  List<TextEditingController> _questionCtrls = [];
  List<TextEditingController> _answerCtrls = [];
  List<String> _questionTypes = ['text'];
  List<List<TextEditingController>> _optionsCtrls = [[]];
  bool _isVisible = true;
  bool _isMembersOnly = false;
  bool _isGrammaticaQuiz = false;
  List<String> _visibleTo = [];

  ContentVisibility _visibility = ContentVisibility.public;

  List<PlatformFile> _selectedFiles = [];
  String? _currentAttachmentName;
  String? _currentAttachmentUrl;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _durationCtrl.dispose();
    _maxAttemptsCtrl.dispose();
    for (final ctrl in _questionCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _answerCtrls) {
      ctrl.dispose();
    }
    for (final list in _optionsCtrls) {
      for (final ctrl in list) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isEmbedded) _buildQuizzesList(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildInputFields()),
                    const SizedBox(width: 32),
                    Expanded(flex: 1, child: _buildUploadUI()),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputFields(),
                    const SizedBox(height: 24),
                    _buildUploadUI(),
                  ],
                );
              }
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Divider(),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _buildQuestionsSection(),
        ),
        if (!widget.isEmbedded) ...[
          const SizedBox(height: 24),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: resetForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: (_creatingOrUpdating || _title.text.trim().isEmpty)
                      ? null
                      : _saveQuiz,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF88B342),
                  ),
                  icon: _creatingOrUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _selectedQuizId == null ? 'Save Quiz' : 'Update Quiz',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuizzesList() {
    final user = AuthService.instance.currentUser;
    return StreamBuilder<UserRole>(
      stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
      builder: (context, roleSnap) {
        final role = roleSnap.data ?? UserRole.learner;
        return StreamBuilder<List<Quiz>>(
          stream: DatabaseService.instance.streamQuizzes(
            approvedOnly: false,
            userRole: role,
            userId: user?.uid,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final quizzes = snapshot.data!;
            if (quizzes.isEmpty) return const SizedBox.shrink();

            return Container(
              height: 180,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Existing Quizzes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_selectedQuizId != null)
                        TextButton.icon(
                          onPressed: resetForm,
                          icon: const Icon(Icons.add),
                          label: const Text('Create New'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: quizzes.length,
                      itemBuilder: (context, index) {
                        final q = quizzes[index];
                        final isSelected = q.id == _selectedQuizId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: InkWell(
                            onTap: () => loadQuiz(q.id),
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF88B342).withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF88B342)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          q.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _confirmDeleteQuiz(context, q),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    q.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${q.questions.length} Questions',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteQuiz(BuildContext context, Quiz quiz) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: Text('Are you sure you want to delete "${quiz.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await DatabaseService.instance.deleteQuiz(quiz.id);
        if (_selectedQuizId == quiz.id) resetForm();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Quiz deleted')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
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
                  labelText: 'Duration (HH:MM:SS)',
                  hintText: '00:30:00',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxAttemptsCtrl,
                decoration: const InputDecoration(labelText: 'Max Attempts'),
                keyboardType: TextInputType.number,
                enabled: !_isGrammaticaQuiz,
              ),
            ),
          ],
        ),
        if (!widget.isEmbedded) ...[
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          StreamBuilder<UserRole>(
            stream: RoleService.instance.roleStream(
              AuthService.instance.currentUser?.uid ?? '',
            ),
            builder: (context, roleSnap) {
              final isEducator = roleSnap.data == UserRole.educator;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visibility',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ContentVisibility>(
                    segments: [
                      const ButtonSegment(
                        value: ContentVisibility.public,
                        label: Text('Public'),
                        icon: Icon(Icons.public),
                      ),
                      const ButtonSegment(
                        value: ContentVisibility.membersOnly,
                        label: Text('Standard'),
                        icon: Icon(Icons.people_outline),
                      ),
                      const ButtonSegment(
                        value: ContentVisibility.certainUsers,
                        label: Text('Premium'),
                        icon: Icon(Icons.star),
                      ),
                    ],
                    selected: {_visibility},
                    onSelectionChanged: (Set<ContentVisibility> newSelection) {
                      setState(() {
                        _visibility = newSelection.first;
                        // Map visibility to database flags
                        if (_visibility == ContentVisibility.public) {
                          _isVisible = true;
                          _isMembersOnly = false;
                        } else if (_visibility ==
                            ContentVisibility.membersOnly) {
                          _isVisible = true;
                          _isMembersOnly = true;
                        } else if (_visibility ==
                            ContentVisibility.certainUsers) {
                          _isVisible = false;
                          _isMembersOnly = false;
                        }
                      });
                    },
                  ),
                  if (_visibility == ContentVisibility.certainUsers) ...[
                    const SizedBox(height: 16),
                    UserVisibilitySelector(
                      selectedUserIds: _visibleTo,
                      educatorUid: isEducator
                          ? AuthService.instance.currentUser?.uid
                          : null,
                      onChanged: (users) {
                        setState(() => _visibleTo = users);
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        if (!widget.isEmbedded)
          StreamBuilder<UserRole>(
            stream: RoleService.instance.roleStream(
              AuthService.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final role = snapshot.data;
              if (role == UserRole.admin || role == UserRole.superadmin) {
                return CheckboxListTile(
                  title: const Text('Upload as Grammatica Quiz'),
                  subtitle: const Text(
                    'This will appear in the official "Grammatica Quizzes" folder',
                  ),
                  value: _isGrammaticaQuiz,
                  onChanged: (val) {
                    setState(() {
                      _isGrammaticaQuiz = val ?? false;
                      if (_isGrammaticaQuiz) {
                        _maxAttemptsCtrl.text = '1000000';
                      } else {
                        _maxAttemptsCtrl.text = '1';
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Questions', style: Theme.of(context).textTheme.titleMedium),
            _isGeneratingFromPdf
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton.filled(
                    onPressed: _generateQuestionsFromPdf,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF88B342),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: 'Generate from PDF',
                  ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_questionCtrls.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
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
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                _questionCtrls[index].dispose();
                                _answerCtrls[index].dispose();
                                for (var c in _optionsCtrls[index]) {
                                  c.dispose();
                                }
                                _questionCtrls.removeAt(index);
                                _answerCtrls.removeAt(index);
                                _questionTypes.removeAt(index);
                                _optionsCtrls.removeAt(index);
                                _notifyChanged();
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
                      initialValue: _questionTypes[index],
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
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _questionTypes[index] = v;
                            if (v == 'multiple_choice' &&
                                _optionsCtrls[index].isEmpty) {
                              _optionsCtrls[index] = [
                                TextEditingController()
                                  ..addListener(_notifyChanged),
                                TextEditingController()
                                  ..addListener(_notifyChanged),
                              ];
                            }
                            _notifyChanged();
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
                      RadioGroup<int>(
                        groupValue: () {
                          final correctText = _answerCtrls[index].text;
                          if (correctText.isEmpty) return -1;
                          return _optionsCtrls[index].indexWhere(
                            (ctrl) => ctrl.text == correctText,
                          );
                        }(),
                        onChanged: (int? val) {
                          if (val != null) {
                            setState(() {
                              _answerCtrls[index].text =
                                  _optionsCtrls[index][val].text;
                              _notifyChanged();
                            });
                          }
                        },
                        child: Column(
                          children: [
                            ...List.generate(_optionsCtrls[index].length, (
                              optIdx,
                            ) {
                              return Row(
                                children: [
                                  Radio<int>(value: optIdx),
                                  Expanded(
                                    child: TextField(
                                      controller: _optionsCtrls[index][optIdx],
                                      decoration: InputDecoration(
                                        labelText: 'Option ${optIdx + 1}',
                                      ),
                                      onChanged: (val) {
                                        final correctText =
                                            _answerCtrls[index].text;
                                        final selectedIdx = _optionsCtrls[index]
                                            .indexWhere(
                                              (ctrl) =>
                                                  ctrl.text == correctText,
                                            );

                                        if (selectedIdx == optIdx) {
                                          _answerCtrls[index].text = val;
                                        }
                                        setState(() {});
                                        _notifyChanged();
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _optionsCtrls[index][optIdx].dispose();
                                        _optionsCtrls[index].removeAt(optIdx);
                                        _notifyChanged();
                                      });
                                    },
                                  ),
                                ],
                              );
                            }),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _optionsCtrls[index].add(
                                    TextEditingController()
                                      ..addListener(_notifyChanged),
                                  );
                                  _notifyChanged();
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Option'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_questionTypes[index] == 'text')
                      TextField(
                        controller: _answerCtrls[index],
                        decoration: const InputDecoration(
                          labelText: 'Correct Answer',
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Correct Answer: ${_answerCtrls[index].text.isEmpty ? "(None selected)" : _answerCtrls[index].text}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                _questionCtrls.add(
                  TextEditingController()..addListener(_notifyChanged),
                );
                _answerCtrls.add(
                  TextEditingController()..addListener(_notifyChanged),
                );
                _questionTypes.add('text');
                _optionsCtrls.add([]);
                _notifyChanged();
              });
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Question'),
          ),
        ),
      ],
    );
  }

  Future<void> _generateQuestionsFromPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isGeneratingFromPdf = true);

        final platformFile = result.files.single;
        List<int> bytes;
        if (platformFile.bytes != null) {
          bytes = platformFile.bytes!;
        } else if (platformFile.path != null) {
          bytes = await File(platformFile.path!).readAsBytes();
        } else {
          throw Exception('Could not read file data');
        }

        final extractedText = await _aiLogicService.extractTextFromPdf(bytes);

        final generatedQuestions = await _aiLogicService.generateQuizFromText(
          extractedText,
        );

        setState(() {
          // Clear default first empty question if it's the only one and empty
          if (_questionCtrls.length == 1 && _questionCtrls[0].text.isEmpty) {
            _questionCtrls.clear();
            _answerCtrls.clear();
            _questionTypes.clear();
            _optionsCtrls.clear();
          }

          for (final q in generatedQuestions) {
            _questionCtrls.add(
              TextEditingController(text: q['question'])
                ..addListener(_notifyChanged),
            );
            _answerCtrls.add(
              TextEditingController(text: q['correctAnswer'])
                ..addListener(_notifyChanged),
            );
            _questionTypes.add('multiple_choice');

            final options = (q['options'] as List<String>)
                .map(
                  (opt) =>
                      TextEditingController(text: opt)
                        ..addListener(_notifyChanged),
                )
                .toList();
            _optionsCtrls.add(options);
          }

          _isGeneratingFromPdf = false;
          _notifyChanged();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully generated questions from PDF!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingFromPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating from PDF: $e')),
        );
      }
    }
  }

  Widget _buildUploadUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attach PDF',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 48, color: Colors.grey.shade500),
                const SizedBox(height: 16),
                Text(
                  _selectedFiles.isNotEmpty
                      ? _selectedFiles.first.name
                      : (_currentAttachmentName ?? 'No PDF uploaded yet'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  (_selectedFiles.isNotEmpty || _currentAttachmentName != null)
                      ? 'Click to change file'
                      : 'Upload PDF to attach to this quiz.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void resetForm() {
    _selectedQuizId = null;
    _title.clear();
    _description.clear();
    _durationCtrl.text = '0';
    _maxAttemptsCtrl.text = '1';
    _selectedFiles = [];
    _currentAttachmentName = null;
    _currentAttachmentUrl = null;
    for (var c in _questionCtrls) {
      c.dispose();
    }
    for (var c in _answerCtrls) {
      c.dispose();
    }
    for (var list in _optionsCtrls) {
      for (var c in list) {
        c.dispose();
      }
    }

    _questionCtrls = [TextEditingController()..addListener(_notifyChanged)];
    _answerCtrls = [TextEditingController()..addListener(_notifyChanged)];
    _optionsCtrls = [[]];
    _questionTypes = ['text'];

    _isVisible = true;
    _isMembersOnly = false;
    _isGrammaticaQuiz = false;
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    setState(() {});
    _notifyChanged();
  }

  Future<String?> _saveQuiz() async {
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

      final durationSegments = _durationCtrl.text.split(':');
      int durationInMinutes = 0;
      if (durationSegments.length == 3) {
        final hh = int.tryParse(durationSegments[0]) ?? 0;
        final mm = int.tryParse(durationSegments[1]) ?? 0;
        final ss = int.tryParse(durationSegments[2]) ?? 0;
        durationInMinutes =
            (hh * 60) + mm + (ss > 0 ? 1 : 0); // Round up if any seconds
      } else if (durationSegments.length == 1) {
        durationInMinutes = int.tryParse(durationSegments[0]) ?? 0;
      }

      final maxAttempts = int.tryParse(_maxAttemptsCtrl.text) ?? 1;

      if (durationInMinutes <= 0) {
        throw Exception('Quiz duration must be greater than 00:00:00');
      }
      if (maxAttempts <= 0) {
        throw Exception('Max attempts must be at least 1');
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

      String quizId;
      if (_selectedQuizId == null) {
        quizId = await DatabaseService.instance.createQuiz(
          title: _title.text.trim(),
          description: _description.text.trim(),
          questions: questions,
          duration: durationInMinutes,
          maxAttempts: maxAttempts,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          isVisible: _isVisible,
          visibleTo: _visibleTo,
          isMembersOnly: _isMembersOnly,
          isGrammaticaQuiz: _isGrammaticaQuiz,
        );
        if (mounted && !widget.isEmbedded) {
          final role = await RoleService.instance.getRole(
            AuthService.instance.currentUser?.uid ?? '',
          );
          if (!mounted) return quizId;
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
        quizId = _selectedQuizId!;
        await DatabaseService.instance.updateQuiz(
          id: quizId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          questions: questions,
          duration: durationInMinutes,
          maxAttempts: maxAttempts,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          isVisible: _isVisible,
          visibleTo: _visibleTo,
          isMembersOnly: _isMembersOnly,
          isGrammaticaQuiz: _isGrammaticaQuiz,
        );
        if (mounted && !widget.isEmbedded) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Quiz updated')));
        }
      }
      if (mounted && !widget.isEmbedded) resetForm();
      if (widget.onQuizSaved != null) widget.onQuizSaved!(quizId);
      return quizId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _creatingOrUpdating = false);
    }
  }

  // Expose save method for parent
  Future<String?> saveForLesson() => _saveQuiz();

  // Expose load method for parent
  Future<void> loadQuiz(String quizId) async {
    try {
      final quiz = await DatabaseService.instance.getQuiz(quizId);
      if (quiz != null) {
        setState(() {
          _selectedQuizId = quiz.id;
          _title.text = quiz.title;
          _description.text = quiz.description;
          // Format duration as HH:MM:SS
          final h = quiz.duration ~/ 60;
          final m = quiz.duration % 60;
          _durationCtrl.text =
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
          _maxAttemptsCtrl.text = quiz.maxAttempts.toString();
          _isVisible = quiz.isVisible;
          _isMembersOnly = quiz.isMembersOnly;
          _isGrammaticaQuiz = quiz.isGrammaticaQuiz;
          _visibleTo = quiz.visibleTo;
          _currentAttachmentName = quiz.attachmentName;
          _currentAttachmentUrl = quiz.attachmentUrl;
          for (var c in _questionCtrls) {
            c.dispose();
          }
          for (var c in _answerCtrls) {
            c.dispose();
          }
          for (var list in _optionsCtrls) {
            for (var c in list) {
              c.dispose();
            }
          }

          _questionCtrls = quiz.questions
              .map(
                (q) =>
                    TextEditingController(text: q.question)
                      ..addListener(_notifyChanged),
              )
              .toList();
          _answerCtrls = quiz.questions
              .map(
                (q) =>
                    TextEditingController(text: q.answer)
                      ..addListener(_notifyChanged),
              )
              .toList();
          _questionTypes = quiz.questions.map((q) => q.type).toList();
          _optionsCtrls = quiz.questions.map((q) {
            return (q.options ?? [])
                .map(
                  (opt) =>
                      TextEditingController(text: opt)
                        ..addListener(_notifyChanged),
                )
                .toList();
          }).toList();
        });
        _notifyChanged();
      }
    } catch (e) {
      debugPrint('Error loading quiz: $e');
    }
  }
}
