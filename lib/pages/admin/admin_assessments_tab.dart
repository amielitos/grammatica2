import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';

class AdminAssessmentsTab extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onChanged;

  const AdminAssessmentsTab({
    super.key,
    this.isEmbedded = false,
    this.onChanged,
  });

  @override
  State<AdminAssessmentsTab> createState() => AdminAssessmentsTabState();
}

class AdminAssessmentsTabState extends State<AdminAssessmentsTab> {
  String? _selectedAssessmentId;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _durationCtrl = TextEditingController(text: '00:00:00');
  final _maxAttemptsCtrl = TextEditingController(text: '1');

  List<TextEditingController> _questionCtrls = [TextEditingController()];
  List<TextEditingController> _answerCtrls = [TextEditingController()];
  List<String> _questionTypes = ['text'];
  List<List<TextEditingController>> _optionsCtrls = [[]];
  bool _isVisible = true;
  bool _isMembersOnly = false;
  List<String> _visibleTo = [];

  List<PlatformFile> _selectedFiles = [];
  String? _currentAttachmentName;
  String? _currentAttachmentUrl;

  @override
  void initState() {
    super.initState();
    _title.addListener(_notifyChanged);
    _description.addListener(_notifyChanged);
    // Assessments start with a blank form by default.
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

  void resetForm() {
    setState(() {
      _selectedAssessmentId = null;
      _title.clear();
      _description.clear();
      _durationCtrl.text = '00:00:00';
      _maxAttemptsCtrl.text = '1';
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
      _questionCtrls = [TextEditingController()..addListener(_notifyChanged)];
      _answerCtrls = [TextEditingController()..addListener(_notifyChanged)];
      _questionTypes = ['text'];
      _optionsCtrls = [[]];
      _selectedFiles = [];
      _currentAttachmentName = null;
      _currentAttachmentUrl = null;
      _isVisible = true;
      _isMembersOnly = false;
      _visibleTo = [];
    });
    _notifyChanged();
  }

  Future<void> saveIndependent() async {
    final error = validateQuiz();
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    try {
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

      String? attachmentUrl = _currentAttachmentUrl;
      String? attachmentName = _currentAttachmentName;

      // Handle new file uploads
      if (_selectedFiles.isNotEmpty) {
        // This part depends on how you handle file uploads in your app. 
        // Typically you'd call a storage service.
        // For now, I'll assume it's handled or we keep existing URL.
      }

      if (_selectedAssessmentId == null) {
        await DatabaseService.instance.createQuiz(
          title: _title.text.trim(),
          description: _description.text.trim(),
          questions: questions,
          duration: _parseDuration(_durationCtrl.text),
          maxAttempts: int.tryParse(_maxAttemptsCtrl.text) ?? 1,
          isVisible: _isVisible,
          isMembersOnly: _isMembersOnly,
          visibleTo: _visibleTo,
          isAssessment: true, // Key flag
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
        );
      } else {
        await DatabaseService.instance.updateQuiz(
          id: _selectedAssessmentId!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          questions: questions,
          duration: _parseDuration(_durationCtrl.text),
          maxAttempts: int.tryParse(_maxAttemptsCtrl.text) ?? 1,
          isVisible: _isVisible,
          isMembersOnly: _isMembersOnly,
          visibleTo: _visibleTo,
          isAssessment: true,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assessment saved successfully')),
        );
      }
      resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  int _parseDuration(String text) {
    final parts = text.split(':');
    if (parts.length != 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return (h * 3600) + (m * 60) + s;
  }

  String? validateQuiz() {
    if (_title.text.trim().isEmpty) return 'Title is required';
    final questions = List.generate(_questionCtrls.length, (i) {
      return QuizQuestion(
        question: _questionCtrls[i].text.trim(),
        answer: _answerCtrls[i].text.trim(),
        type: _questionTypes[i],
      );
    }).where((q) => q.question.isNotEmpty).toList();

    if (questions.isEmpty) return 'Add at least one question';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAssessmentsList(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputFields(),
                const SizedBox(height: 24),
                _buildQuestionsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsList() {
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
            // Filter only assessments
            final assessments = snapshot.data!.where((q) => q.isAssessment).toList();
            if (assessments.isEmpty) return const SizedBox.shrink();

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
                        'Existing Assessments',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_selectedAssessmentId != null)
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
                      itemCount: assessments.length,
                      itemBuilder: (context, index) {
                        final q = assessments[index];
                        final isSelected = q.id == _selectedAssessmentId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: InkWell(
                            onTap: () => _loadAssessment(q),
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF88B342).withValues(alpha: 0.1)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF88B342) : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(q.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const Spacer(),
                                  Text('${q.questions.length} Questions', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
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

  void _loadAssessment(Quiz q) {
    setState(() {
      _selectedAssessmentId = q.id;
      _title.text = q.title;
      _description.text = q.description;
      _durationCtrl.text = _formatDuration(q.duration);
      _maxAttemptsCtrl.text = q.maxAttempts.toString();
      _isVisible = q.isVisible;
      _isMembersOnly = q.isMembersOnly;
      _visibleTo = List.from(q.visibleTo);
      _currentAttachmentName = q.attachmentName;
      _currentAttachmentUrl = q.attachmentUrl;

      // Dispose old controllers
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

      _questionCtrls = q.questions.map((que) => TextEditingController(text: que.question)..addListener(_notifyChanged)).toList();
      _answerCtrls = q.questions.map((que) => TextEditingController(text: que.answer)..addListener(_notifyChanged)).toList();
      _questionTypes = q.questions.map((que) => que.type).toList();
      _optionsCtrls = q.questions.map((que) {
        return (que.options ?? []).map((o) => TextEditingController(text: o)..addListener(_notifyChanged)).toList();
      }).toList();
    });
    _notifyChanged();
  }

  String _formatDuration(int seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Assessment Title')),
        const SizedBox(height: 16),
        TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextField(controller: _durationCtrl, decoration: const InputDecoration(labelText: 'Duration (HH:MM:SS)'))),
            const SizedBox(width: 16),
            Expanded(child: TextField(controller: _maxAttemptsCtrl, decoration: const InputDecoration(labelText: 'Max Attempts'), keyboardType: TextInputType.number)),
          ],
        ),
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
            const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton.filled(
              onPressed: () {}, // PDF Gen logic can be added later
              icon: const Icon(Icons.picture_as_pdf),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(_questionCtrls.length, (index) {
          return _buildQuestionCard(index);
        }),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _questionCtrls.add(TextEditingController()..addListener(_notifyChanged));
                _answerCtrls.add(TextEditingController()..addListener(_notifyChanged));
                _questionTypes.add('text');
                _optionsCtrls.add([]);
              });
              _notifyChanged();
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Question'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
     return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, child: Text('${index+1}', style: const TextStyle(fontSize: 12))),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _questionCtrls[index].dispose();
                      _answerCtrls[index].dispose();
                      _questionCtrls.removeAt(index);
                      _answerCtrls.removeAt(index);
                      _questionTypes.removeAt(index);
                      _optionsCtrls.removeAt(index);
                    });
                    _notifyChanged();
                  },
                ),
              ],
            ),
            TextField(controller: _questionCtrls[index], decoration: const InputDecoration(labelText: 'Question')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _questionTypes[index],
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Text')),
                DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _questionTypes[index] = v;
                    if (v == 'multiple_choice' && _optionsCtrls[index].isEmpty) {
                      _optionsCtrls[index] = [TextEditingController()..addListener(_notifyChanged), TextEditingController()..addListener(_notifyChanged)];
                    }
                  });
                  _notifyChanged();
                }
              },
            ),
            if (_questionTypes[index] == 'multiple_choice') ...[
              const SizedBox(height: 8),
              ...List.generate(_optionsCtrls[index].length, (oIdx) {
                 return Row(
                   children: [
                     Expanded(child: TextField(controller: _optionsCtrls[index][oIdx], decoration: InputDecoration(labelText: 'Option ${oIdx+1}'))),
                     IconButton(icon: const Icon(Icons.close), onPressed: () {
                       setState(() => _optionsCtrls[index].removeAt(oIdx));
                       _notifyChanged();
                     }),
                   ],
                 );
              }),
              TextButton(onPressed: () {
                setState(() => _optionsCtrls[index].add(TextEditingController()..addListener(_notifyChanged)));
                _notifyChanged();
              }, child: const Text('Add Option')),
            ],
            TextField(controller: _answerCtrls[index], decoration: const InputDecoration(labelText: 'Correct Answer')),
          ],
        ),
      ),
    );
  }

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
}
