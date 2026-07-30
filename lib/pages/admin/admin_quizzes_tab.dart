import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  const AdminQuizzesTab({
    super.key,
    this.isEmbedded = false,
    this.onQuizSaved,
    this.initialQuizId,
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
    if (widget.initialQuizId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadQuiz(widget.initialQuizId!);
      });
    }
  }

  List<_QuestionState> _questions = [_QuestionState()];
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
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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
          const SizedBox(height: 24),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                  onPressed: (_creatingOrUpdating || _title.text.trim().isEmpty) ? null : _saveQuiz,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF88B342),
                  ),
                  icon: _creatingOrUpdating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_selectedQuizId == null ? 'Save Quiz' : 'Update Quiz'),
                ),
              ],
            ),
          ),
        ],
      ),
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
            isAssessment: false,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            
            var quizzes = snapshot.data!.toList();
            
            // Educators should only see and manage their own quizzes
            if (role == UserRole.educator && user != null) {
              quizzes = quizzes.where((q) => q.createdByUid == user.uid).toList();
            }

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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                color: isSelected ? const Color(0xFF88B342).withValues(alpha: 0.1) : Colors.white,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF88B342) : Colors.grey.shade300,
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
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _confirmDeleteQuiz(context, q),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    q.description,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${q.questions.length} Questions',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Widget _buildInputFields() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Details',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2A2A2A)),
          ),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _title,
            label: 'Title',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          _buildStyledTextField(
            controller: _description,
            label: 'Description',
            icon: Icons.description_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDurationDropdown(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMaxAttemptsCounter(),
              ),
            ],
          ),
          if (!widget.isEmbedded) ...[
            const SizedBox(height: 32),
            StreamBuilder<UserRole>(
              stream: RoleService.instance.roleStream(
                AuthService.instance.currentUser?.uid ?? '',
              ),
              builder: (context, roleSnap) {
                final isEducator = roleSnap.data == UserRole.educator;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visibility Options',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2A2A2A)),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ChoiceChip(
                          label: Text('Public', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          avatar: const Icon(Icons.public, size: 18),
                          selected: _visibility == ContentVisibility.public,
                          selectedColor: const Color(0xFF88B342).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF88B342),
                          labelStyle: TextStyle(color: _visibility == ContentVisibility.public ? const Color(0xFF88B342) : Colors.black87),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _visibility = ContentVisibility.public;
                                _isVisible = true;
                                _isMembersOnly = false;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('Standard', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          avatar: const Icon(Icons.people_outline, size: 18),
                          selected: _visibility == ContentVisibility.membersOnly,
                          selectedColor: const Color(0xFF88B342).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF88B342),
                          labelStyle: TextStyle(color: _visibility == ContentVisibility.membersOnly ? const Color(0xFF88B342) : Colors.black87),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _visibility = ContentVisibility.membersOnly;
                                _isVisible = true;
                                _isMembersOnly = true;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('Premium', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          avatar: const Icon(Icons.star_rounded, size: 18),
                          selected: _visibility == ContentVisibility.certainUsers,
                          selectedColor: const Color(0xFF88B342).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF88B342),
                          labelStyle: TextStyle(color: _visibility == ContentVisibility.certainUsers ? const Color(0xFF88B342) : Colors.black87),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _visibility = ContentVisibility.certainUsers;
                                _isVisible = false;
                                _isMembersOnly = false;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (_visibility == ContentVisibility.certainUsers) ...[
                      const SizedBox(height: 16),
                      UserVisibilitySelector(
                        selectedUserIds: _visibleTo,
                        educatorUid: isEducator ? AuthService.instance.currentUser?.uid : null,
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
          if (!widget.isEmbedded) ...[
            const SizedBox(height: 24),
            StreamBuilder<UserRole>(
              stream: RoleService.instance.roleStream(
                AuthService.instance.currentUser?.uid ?? '',
              ),
              builder: (context, snapshot) {
                final role = snapshot.data;
                if (role == UserRole.admin || role == UserRole.superadmin) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF88B342).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF88B342).withValues(alpha: 0.3)),
                    ),
                    child: CheckboxListTile(
                      title: Text('Official Grammatica Content', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF2A2A2A))),
                      subtitle: Text('This will appear in the official folders', style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
                      activeColor: const Color(0xFF88B342),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationDropdown() {
    final options = {
      '00:05:00': '5 Minutes',
      '00:10:00': '10 Minutes',
      '00:15:00': '15 Minutes',
      '00:20:00': '20 Minutes',
      '00:30:00': '30 Minutes',
      '00:45:00': '45 Minutes',
      '01:00:00': '1 Hour',
      '01:30:00': '1.5 Hours',
      '02:00:00': '2 Hours',
      '03:00:00': '3 Hours',
    };

    // Ensure current text is in options or default to 30 mins
    String currentVal = _durationCtrl.text;
    if (!options.containsKey(currentVal)) {
      currentVal = '00:30:00';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _durationCtrl.text = currentVal;
        }
      });
    }

    return DropdownButtonFormField<String>(
      initialValue: currentVal,
      style: GoogleFonts.inter(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        labelText: 'Duration',
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
        prefixIcon: const Icon(Icons.timer_outlined, color: Color(0xFF88B342)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF88B342), width: 2),
        ),
      ),
      items: options.entries.map((e) {
        return DropdownMenuItem(
          value: e.key,
          child: Text(e.value),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _durationCtrl.text = val;
          });
        }
      },
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFF88B342)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF88B342), width: 2),
        ),
      ),
    );
  }

  Widget _buildMaxAttemptsCounter() {
    int currentVal = int.tryParse(_maxAttemptsCtrl.text) ?? 1;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Max Attempts',
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _isGrammaticaQuiz || currentVal <= 1
                ? null
                : () {
                    setState(() {
                      currentVal--;
                      _maxAttemptsCtrl.text = currentVal.toString();
                    });
                  },
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          ),
          Expanded(
            child: TextField(
              controller: _maxAttemptsCtrl,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF88B342)),
              keyboardType: TextInputType.number,
              enabled: !_isGrammaticaQuiz,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                if (val.isNotEmpty) {
                  int parsed = int.tryParse(val) ?? 1;
                  if (parsed < 1) {
                     _maxAttemptsCtrl.text = '1';
                  }
                }
              },
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _isGrammaticaQuiz
                ? null
                : () {
                    setState(() {
                      currentVal++;
                      _maxAttemptsCtrl.text = currentVal.toString();
                    });
                  },
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF88B342)),
          ),
        ],
      ),
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
            ElevatedButton.icon(
              onPressed: _isGeneratingFromPdf ? null : _generateQuestionsFromPdf,
              icon: _isGeneratingFromPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Generate from PDF'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(_questions.length, (index) {
          return _buildQuestionItem(_questions[index], index, _questions);
        }),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _questions.add(_QuestionState());
              });
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Question'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionItem(
    _QuestionState q,
    int index,
    List<_QuestionState> parentList, {
    bool isNested = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isNested ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: isNested ? 1 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isNested ? 'Nested Question' : 'Question ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (parentList.length > 1 || isNested)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        q.dispose();
                        parentList.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: q.questionCtrl,
              decoration: InputDecoration(
                labelText: q.type == 'passage' ? 'Passage Content' : 'Question',
                hintText: q.type == 'passage'
                    ? 'Enter the text passage here...'
                    : 'Enter your question...',
                border: const OutlineInputBorder(),
              ),
              maxLines: q.type == 'passage' ? 8 : null,
              minLines: q.type == 'passage' ? 3 : 1,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: q.type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'text', child: Text('Textfield')),
                const DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
                if (!isNested) const DropdownMenuItem(value: 'passage', child: Text('Passage')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    q.type = v;
                    if (v == 'multiple_choice' && q.optionsCtrls.isEmpty) {
                      q.optionsCtrls = [
                        TextEditingController(),
                        TextEditingController(),
                      ];
                    }
                  });
                }
              },
            ),
            if (q.type == 'multiple_choice') ...[
              const SizedBox(height: 16),
              const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: () {
                  final correctText = q.answerCtrl.text;
                  if (correctText.isEmpty) return -1;
                  return q.optionsCtrls.indexWhere(
                    (ctrl) => ctrl.text == correctText,
                  );
                }(),
                onChanged: (int? val) {
                  if (val != null) {
                    setState(() {
                      q.answerCtrl.text = q.optionsCtrls[val].text;
                    });
                  }
                },
                child: Column(
                  children: List.generate(q.optionsCtrls.length, (optIdx) {
                    return Row(
                      children: [
                        Radio<int>(
                          value: optIdx,
                        ),
                        Expanded(
                          child: TextField(
                            controller: q.optionsCtrls[optIdx],
                            decoration: InputDecoration(
                              labelText: 'Option ${optIdx + 1}',
                            ),
                            onChanged: (val) {
                              setState(() {});
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              q.optionsCtrls.removeAt(optIdx);
                            });
                          },
                        ),
                      ],
                    );
                  }),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    q.optionsCtrls.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Option'),
              ),
            ],
            if (q.type == 'text') ...[
              const SizedBox(height: 16),
              TextField(
                controller: q.answerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correct Answer',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (q.type == 'passage') ...[
              const SizedBox(height: 16),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Questions for this Passage',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...List.generate(q.nestedQuestions.length, (nIdx) {
                return _buildQuestionItem(
                  q.nestedQuestions[nIdx],
                  nIdx,
                  q.nestedQuestions,
                  isNested: true,
                );
              }),
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      q.nestedQuestions.add(_QuestionState());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question to Passage'),
                ),
              ),
            ],
          ],
        ),
      ),
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
          if (_questions.length == 1 && _questions[0].questionCtrl.text.isEmpty) {
            _questions[0].dispose();
            _questions.clear();
          }

          for (final q in generatedQuestions) {
            _questions.add(_QuestionState(
              questionCtrl: TextEditingController(text: q['question']),
              answerCtrl: TextEditingController(text: q['correctAnswer']),
              type: 'multiple_choice',
              optionsCtrls: (q['options'] as List<String>)
                  .map((opt) => TextEditingController(text: opt))
                  .toList(),
            ));
          }

          _isGeneratingFromPdf = false;
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
        const Text('Attach PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  _selectedFiles.isNotEmpty ? _selectedFiles.first.name : (_currentAttachmentName ?? 'No PDF uploaded yet'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  (_selectedFiles.isNotEmpty || _currentAttachmentName != null) ? 'Click to change file' : 'Upload PDF to attach to this quiz.',
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
    for (final q in _questions) {
      q.dispose();
    }
    _questions = [_QuestionState()];
    _isVisible = true;
    _isMembersOnly = false;
    _isGrammaticaQuiz = false;
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    setState(() {});
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

      final questions = _questions
          .map((q) => _mapToQuizQuestion(q))
          .where((q) => q.question.isNotEmpty)
          .toList();

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
          for (final q in _questions) {
            q.dispose();
          }
          _questions = quiz.questions.map((q) => _loadQuestionState(q)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading quiz: $e');
    }
  }

  QuizQuestion _mapToQuizQuestion(_QuestionState q) {
    return QuizQuestion(
      question: q.questionCtrl.text.trim(),
      answer: q.answerCtrl.text.trim(),
      type: q.type,
      options: q.type == 'multiple_choice'
          ? q.optionsCtrls
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : null,
      nestedQuestions: q.type == 'passage'
          ? q.nestedQuestions
              .map((nq) => _mapToQuizQuestion(nq))
              .where((nq) => nq.question.isNotEmpty)
              .toList()
          : null,
    );
  }

  _QuestionState _loadQuestionState(QuizQuestion q) {
    return _QuestionState(
      questionCtrl: TextEditingController(text: q.question),
      answerCtrl: TextEditingController(text: q.answer),
      type: q.type,
      optionsCtrls: (q.options ?? [])
          .map((opt) => TextEditingController(text: opt))
          .toList(),
      nestedQuestions: (q.nestedQuestions ?? [])
          .map((nq) => _loadQuestionState(nq))
          .toList(),
    );
  }
}

class _QuestionState {
  final TextEditingController questionCtrl;
  final TextEditingController answerCtrl;
  String type;
  List<TextEditingController> optionsCtrls;
  List<_QuestionState> nestedQuestions;

  _QuestionState({
    TextEditingController? questionCtrl,
    TextEditingController? answerCtrl,
    this.type = 'text',
    List<TextEditingController>? optionsCtrls,
    List<_QuestionState>? nestedQuestions,
  })  : questionCtrl = questionCtrl ?? TextEditingController(),
        answerCtrl = answerCtrl ?? TextEditingController(),
        optionsCtrls = optionsCtrls ?? [],
        nestedQuestions = nestedQuestions ?? [];

  void dispose() {
    questionCtrl.dispose();
    answerCtrl.dispose();
    for (var ctrl in optionsCtrls) {
      ctrl.dispose();
    }
    for (var q in nestedQuestions) {
      q.dispose();
    }
  }
}