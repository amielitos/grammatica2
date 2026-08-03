import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/content_visibility.dart';
import '../../models/ai_models.dart';
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

  List<_QuestionState> _questions = [];
  bool _isVisible = true;
  bool _isMembersOnly = false;
  bool _isGrammaticaQuiz = false;
  List<String> _visibleTo = [];

  ContentVisibility _visibility = ContentVisibility.public;

  // AI Configuration state
  String _aiSourceMode = 'pdf'; // 'pdf', 'text', 'lesson'
  final _aiPasteTextCtrl = TextEditingController();
  String? _aiSelectedLessonId;
  String _aiDifficulty = 'medium';
  int _aiNumQuestions = 10;
  final _aiCustomInstructionsCtrl = TextEditingController();
  bool _aiIncludeHints = true;
  List<String> _aiQuestionTypes = ['multiple_choice'];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _durationCtrl.dispose();
    _maxAttemptsCtrl.dispose();
    _aiCustomInstructionsCtrl.dispose();
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
                      Expanded(flex: 1, child: _buildAiConfigPanel()),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInputFields(),
                      const SizedBox(height: 24),
                      _buildAiConfigPanel(),
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
      value: currentVal,
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
    // Check if we have real questions (not just the default empty one)
    final hasGeneratedQuestions = _questions.isNotEmpty &&
        !(_questions.length == 1 && _questions[0].questionCtrl.text.isEmpty);

    if (!hasGeneratedQuestions) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF88B342).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 40, color: Color(0xFF88B342)),
            ),
            const SizedBox(height: 20),
            Text(
              'AI Generated Questions',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF2A2A2A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the AI Generation Config panel to select a source (PDF, text, or existing lesson) and generate questions. They will appear here as editable blocks.',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 2),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_awesome, size: 48, color: const Color(0xFF88B342).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'AI Content Blocks',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Questions will appear here once generated by the AI.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Questions (${_questions.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              'Remove only — questions are AI-generated',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(_questions.length, (index) {
          return _buildQuestionItem(_questions[index], index, _questions);
        }),
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
              value: q.type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'text', child: Text('Textfield')),
                const DropdownMenuItem(value: 'fill_in_the_blank', child: Text('Fill in the Blank')),
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
              ...List.generate(q.optionsCtrls.length, (optIdx) {
                final correctText = q.answerCtrl.text;
                return Row(
                  children: [
                    Radio<int>(
                      value: optIdx,
                      groupValue: () {
                        if (correctText.isEmpty) return -1;
                        return q.optionsCtrls.indexWhere(
                          (ctrl) => ctrl.text == correctText,
                        );
                      }(),
                      activeColor: const Color(0xFF88B342),
                      onChanged: (int? val) {
                        if (val != null) {
                          setState(() {
                            q.answerCtrl.text = q.optionsCtrls[val].text;
                          });
                        }
                      },
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
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    q.optionsCtrls.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add_circle_outline, size: 16),
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

  /// AI Config panel — replaces old PDF attachment panel.
  Widget _buildAiConfigPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Generation Config',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2A2A2A),
            ),
          ),
          const SizedBox(height: 16),

          // Question Types Checkboxes
          Text('Question Types', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: Column(
              children: [
                CheckboxListTile(
                  title: Text('Multiple Choice', style: GoogleFonts.inter(fontSize: 13)),
                  value: _aiQuestionTypes.contains('multiple_choice'),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _aiQuestionTypes.add('multiple_choice');
                      } else {
                        _aiQuestionTypes.remove('multiple_choice');
                      }
                    });
                  },
                  activeColor: const Color(0xFF88B342),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text('Fill in the Blanks / Textfield', style: GoogleFonts.inter(fontSize: 13)),
                  value: _aiQuestionTypes.contains('fill_in_the_blank'),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _aiQuestionTypes.add('fill_in_the_blank');
                      } else {
                        _aiQuestionTypes.remove('fill_in_the_blank');
                      }
                    });
                  },
                  activeColor: const Color(0xFF88B342),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text('Passage / Reading', style: GoogleFonts.inter(fontSize: 13)),
                  value: _aiQuestionTypes.contains('passage'),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _aiQuestionTypes.add('passage');
                      } else {
                        _aiQuestionTypes.remove('passage');
                      }
                    });
                  },
                  activeColor: const Color(0xFF88B342),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Difficulty
          Text('Difficulty', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'easy', label: Text('Easy')),
              ButtonSegment(value: 'medium', label: Text('Medium')),
              ButtonSegment(value: 'hard', label: Text('Hard')),
            ],
            selected: {_aiDifficulty},
            onSelectionChanged: (val) => setState(() => _aiDifficulty = val.first),
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 16),

          // Number of questions
          Text('Number of Questions', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _aiNumQuestions > 1 ? () => setState(() => _aiNumQuestions--) : null,
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
              Text(
                '$_aiNumQuestions',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF88B342)),
              ),
              IconButton(
                onPressed: _aiNumQuestions < 30 ? () => setState(() => _aiNumQuestions++) : null,
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF88B342)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Include hints
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: Text('Include Hints', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              value: _aiIncludeHints,
              onChanged: (val) => setState(() => _aiIncludeHints = val),
              activeColor: const Color(0xFF88B342),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),

          // Custom instructions
          Text('Custom Instructions (Optional)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          TextField(
            controller: _aiCustomInstructionsCtrl,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. "Generate matching questions"',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF88B342), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Source Material Selection
          Text('Generate from Source', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2A2A2A))),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pdf', label: Text('PDF File')),
              ButtonSegment(value: 'text', label: Text('Paste Text')),
              ButtonSegment(value: 'lesson', label: Text('Existing Lesson')),
            ],
            selected: {_aiSourceMode},
            onSelectionChanged: (val) => setState(() => _aiSourceMode = val.first),
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 16),

          // Dynamic Source Input & Generate Button
          if (_aiSourceMode == 'pdf')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGeneratingFromPdf ? null : _generateQuestionsWithAi,
                icon: _isGeneratingFromPdf 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_isGeneratingFromPdf ? 'Generating...' : 'Select PDF & Generate'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF88B342),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else if (_aiSourceMode == 'text')
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _aiPasteTextCtrl,
                  maxLines: 4,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Paste raw text here...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF88B342), width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isGeneratingFromPdf ? null : _generateQuestionsWithAi,
                  icon: _isGeneratingFromPdf 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isGeneratingFromPdf ? 'Generating...' : 'Generate from Text'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF88B342),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            )
          else if (_aiSourceMode == 'lesson')
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: StreamBuilder<List<Lesson>>(
                    stream: DatabaseService.instance.streamLessons(),
                    builder: (context, snapshot) {
                      final lessons = snapshot.data ?? [];
                      // Ensure selected ID is valid
                      if (_aiSelectedLessonId != null && !lessons.any((l) => l.id == _aiSelectedLessonId)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _aiSelectedLessonId = null);
                        });
                      }

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _aiSelectedLessonId,
                          hint: const Text('Select a lesson'),
                          items: lessons.map((l) {
                            return DropdownMenuItem(
                              value: l.id,
                              child: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _aiSelectedLessonId = val);
                          },
                        ),
                      );
                    }
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isGeneratingFromPdf ? null : _generateQuestionsWithAi,
                  icon: _isGeneratingFromPdf 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_isGeneratingFromPdf ? 'Generating...' : 'Generate from Lesson'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF88B342),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// AI-powered question generation — replaces old PDF-only flow.
  Future<void> _generateQuestionsWithAi() async {
    setState(() => _isGeneratingFromPdf = true);

    try {
      String extractedText = '';

      if (_aiSourceMode == 'pdf') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );

        if (result == null || result.files.isEmpty) {
          setState(() => _isGeneratingFromPdf = false);
          return;
        }

        final platformFile = result.files.single;
        List<int> bytes;
        if (platformFile.bytes != null) {
          bytes = platformFile.bytes!;
        } else if (platformFile.path != null) {
          bytes = await File(platformFile.path!).readAsBytes();
        } else {
          throw Exception('Could not read file data');
        }

        extractedText = await _aiLogicService.extractTextFromPdf(bytes);
      } else if (_aiSourceMode == 'text') {
        extractedText = _aiPasteTextCtrl.text.trim();
        if (extractedText.isEmpty) {
          throw Exception('Please paste some text first.');
        }
      } else if (_aiSourceMode == 'lesson') {
        if (_aiSelectedLessonId == null) {
          throw Exception('Please select a lesson first.');
        }
        final lesson = await DatabaseService.instance.getLessonById(_aiSelectedLessonId!);
        if (lesson == null) {
          throw Exception('Could not load the selected lesson.');
        }
        extractedText = '${lesson.title}\n\n${lesson.prompt}\n\n${lesson.answer}';
      }

      final config = QuizGenerationConfig(
        questionTypes: _aiQuestionTypes,
        difficulty: _aiDifficulty,
        customInstructions: _aiCustomInstructionsCtrl.text.trim(),
        includeHints: _aiIncludeHints,
      );

      final aiResponse = await _aiLogicService.generateQuiz(
        extractedText,
        numQuestions: _aiNumQuestions,
        config: config,
      );

      // Map AI response to native _QuestionState objects
      setState(() {
        if (aiResponse.title != null && aiResponse.title!.isNotEmpty) {
          _title.text = aiResponse.title!;
        }

        // If generated from a lesson, ensure the lesson title is appended/indicated
        if (_aiSourceMode == 'lesson' && _aiSelectedLessonId != null) {
          DatabaseService.instance.getLessonById(_aiSelectedLessonId!).then((lesson) {
            if (lesson != null && lesson.title.isNotEmpty && mounted) {
              if (!_title.text.toLowerCase().contains(lesson.title.toLowerCase())) {
                setState(() {
                  _title.text = '${lesson.title} - Quiz';
                });
              }
            }
          });
        }

        if (aiResponse.description != null && aiResponse.description!.isNotEmpty) {
          _description.text = aiResponse.description!;
        }

        // Clear default first empty question if it's the only one and empty
        if (_questions.length == 1 && _questions[0].questionCtrl.text.isEmpty) {
          _questions[0].dispose();
          _questions.clear();
        }

        for (final q in aiResponse.questions) {
          final questionText = q.content
              .where((b) => b.type == ContentBlockType.text)
              .map((b) => b.data.toString())
              .join('\n');

          _questions.add(_QuestionState(
            questionCtrl: TextEditingController(text: questionText),
            answerCtrl: TextEditingController(text: q.correctAnswer),
            type: q.questionType.toJsonString(),
            optionsCtrls: q.options
                .map((opt) => TextEditingController(text: opt))
                .toList(),
            hintCtrl: q.hint != null ? TextEditingController(text: q.hint) : null,
            explanationCtrl: q.explanation != null ? TextEditingController(text: q.explanation) : null,
          ));
        }

        _isGeneratingFromPdf = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${aiResponse.questions.length} questions!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingFromPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating questions: $e')),
        );
      }
    }
  }

  void resetForm() {
    _selectedQuizId = null;
    _title.clear();
    _description.clear();
    _durationCtrl.text = '00:30:00';
    _maxAttemptsCtrl.text = '1';
    for (final q in _questions) {
      q.dispose();
    }
    _questions = [];
    _isVisible = true;
    _isMembersOnly = false;
    _isGrammaticaQuiz = false;
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    _aiCustomInstructionsCtrl.clear();
    setState(() {});
  }

  Future<String?> _saveQuiz() async {
    setState(() => _creatingOrUpdating = true);
    try {
      final role = await RoleService.instance.getRole(
        AuthService.instance.currentUser?.uid ?? '',
      );
      final isEducator = role == UserRole.educator;
      final status = isEducator ? 'awaiting_approval' : 'approved';

      String? attachmentUrl;
      String? attachmentName;

      // No more file upload — attachment fields left null

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
          validationStatus: status,
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
          validationStatus: status,
        );
        if (mounted && !widget.isEmbedded) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(isEducator ? 'Quiz submitted for approval' : 'Quiz updated')));
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
      hint: q.hintCtrl?.text.trim().isNotEmpty == true ? q.hintCtrl!.text.trim() : null,
      explanation: q.explanationCtrl?.text.trim().isNotEmpty == true ? q.explanationCtrl!.text.trim() : null,
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
      hintCtrl: q.hint != null ? TextEditingController(text: q.hint) : null,
      explanationCtrl: q.explanation != null ? TextEditingController(text: q.explanation) : null,
    );
  }
}

class _QuestionState {
  final TextEditingController questionCtrl;
  final TextEditingController answerCtrl;
  String type;
  List<TextEditingController> optionsCtrls;
  List<_QuestionState> nestedQuestions;
  TextEditingController? hintCtrl;
  TextEditingController? explanationCtrl;

  _QuestionState({
    TextEditingController? questionCtrl,
    TextEditingController? answerCtrl,
    this.type = 'text',
    List<TextEditingController>? optionsCtrls,
    List<_QuestionState>? nestedQuestions,
    this.hintCtrl,
    this.explanationCtrl,
  })  : questionCtrl = questionCtrl ?? TextEditingController(),
        answerCtrl = answerCtrl ?? TextEditingController(),
        optionsCtrls = optionsCtrls ?? [],
        nestedQuestions = nestedQuestions ?? [];

  void dispose() {
    questionCtrl.dispose();
    answerCtrl.dispose();
    hintCtrl?.dispose();
    explanationCtrl?.dispose();
    for (var ctrl in optionsCtrls) {
      ctrl.dispose();
    }
    for (var q in nestedQuestions) {
      q.dispose();
    }
  }
}