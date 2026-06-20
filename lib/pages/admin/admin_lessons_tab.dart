import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../services/database_service.dart';
import '../../services/ai_logic_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/markdown_guide_button.dart';
import '../../widgets/user_visibility_selector.dart';
import '../../models/content_visibility.dart';

import 'admin_quizzes_tab.dart'; 
import 'admin_assessments_tab.dart';

class AdminLessonsTab extends StatelessWidget {
  final Lesson? initialLesson;
  final VoidCallback? onReset;
  final int initialTabIndex;

  const AdminLessonsTab({
    super.key,
    this.initialLesson,
    this.onReset,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _ManageLessonsView(
      initialLesson: initialLesson,
      onReset: onReset,
      initialTabIndex: initialTabIndex,
    );
  }
}

class _ManageLessonsView extends StatefulWidget {
  final Lesson? initialLesson;
  final VoidCallback? onReset;
  final int initialTabIndex;

  const _ManageLessonsView({
    this.initialLesson,
    this.onReset,
    this.initialTabIndex = 0,
  });

  @override
  State<_ManageLessonsView> createState() => _ManageLessonsViewState();
}

class _ManageLessonsViewState extends State<_ManageLessonsView> {
  String? _selectedLessonId;
  Lesson? _selectedLesson;
  bool _creatingLesson = false;
  bool _isGeneratingFromPdf = false;

  final AILogicService _aiLogicService = AILogicService();
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  List<PlatformFile> _selectedFiles = [];
  bool _isVisible = true;
  bool _isMembersOnly = false;
  bool _isGrammaticaLesson = false;
  List<String> _visibleTo = [];
  final _quizKey = GlobalKey<AdminQuizzesTabState>();
  String? _selectedQuizId;

  ContentVisibility _visibility = ContentVisibility.public;
  int _tabIndex = 0; 

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex;
    if (widget.initialLesson != null) {
      _loadInitialLesson();
    }
  }

  @override
  void didUpdateWidget(_ManageLessonsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      setState(() => _tabIndex = widget.initialTabIndex);
    }
    if (widget.initialLesson != oldWidget.initialLesson) {
      if (widget.initialLesson != null) {
        _loadInitialLesson();
      } else {
        _resetForm(callOnReset: false);
      }
    }
  }

  void _loadInitialLesson() {
    final l = widget.initialLesson!;
    _selectedLessonId = l.id;
    _selectedLesson = l;
    _title.text = l.title;
    _prompt.text = l.prompt;
    _isVisible = l.isVisible;
    _isMembersOnly = l.isMembersOnly;
    _isGrammaticaLesson = l.isGrammaticaLesson;
    _visibleTo = l.visibleTo;
    _selectedQuizId = l.quizId;

    if (l.isMembersOnly) {
      _visibility = ContentVisibility.membersOnly;
    } else if (!l.isVisible && l.visibleTo.isNotEmpty) {
      _visibility = ContentVisibility.certainUsers;
    } else {
      _visibility = ContentVisibility.public;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (l.quizId != null) {
        _quizKey.currentState?.loadQuiz(l.quizId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<UserRole>(
      stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
      builder: (context, roleSnap) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Manage Content',
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create or edit your lessons, quizzes, and assessments.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Custom Segmented Toggle
              Center(
                child: Container(
                  height: 52,
                  width: 500,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildTabBtn('Lessons', 0),
                      _buildTabBtn('Quizzes', 1),
                      _buildTabBtn('Assessments', 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Main Card Content
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    _buildLessonForm(roleSnap.data, isDark),
                    AdminQuizzesTab(
                      key: _quizKey,
                      initialQuizId: _selectedQuizId,
                    ),
                    AdminAssessmentsTab(
                      isEmbedded: true,
                      initialQuizId: _tabIndex == 2 ? _selectedQuizId : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonForm(UserRole? role, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildLessonLeftCol(role, isDark)),
                    const SizedBox(width: 48),
                    Expanded(flex: 2, child: _buildPdfAttachZone(isDark)),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLessonLeftCol(role, isDark),
                    const SizedBox(height: 32),
                    _buildPdfAttachZone(isDark),
                  ],
                );
              }
            },
          ),
        ),
        Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _resetForm(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: (_creatingLesson || _title.text.trim().isEmpty) ? null : _saveIntegratedLesson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _creatingLesson
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text('Save Content', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLessonLeftCol(UserRole? role, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lesson Details',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2A2A2A),
            ),
          ),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _title,
            label: 'Lesson Title',
            hint: 'e.g. Introduction to Nouns',
            icon: Icons.menu_book_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lesson Content',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const MarkdownGuideButton(),
            ],
          ),
          const SizedBox(height: 8),
          _buildStyledTextField(
            controller: _prompt,
            label: 'Write your lesson content using markdown...',
            hint: 'Write your lesson content using markdown...',
            icon: Icons.text_snippet_rounded,
            maxLines: 12,
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildVisibilitySettings(role, isDark)),
              const SizedBox(width: 24),
              ElevatedButton.icon(
                onPressed: _isGeneratingFromPdf ? null : _generateFromPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFF88B342).withValues(alpha: 0.1),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF88B342),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isGeneratingFromPdf
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text('AI Generate', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: maxLines == 1 ? label : null,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600),
        hintStyle: GoogleFonts.inter(color: isDark ? Colors.white30 : Colors.grey.shade400),
        prefixIcon: maxLines == 1 ? Icon(icon, color: const Color(0xFF88B342)) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF88B342), width: 2),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: isDark ? Colors.white30 : Colors.black26),
      filled: true,
      fillColor: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(20),
    );
  }

  Widget _buildPdfAttachZone(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Reference Material (Optional)'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickFiles,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.picture_as_pdf_rounded, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  _selectedFiles.isNotEmpty ? _selectedFiles.first.name : 'No PDF uploaded',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFiles.isNotEmpty ? 'Click to change file' : 'Click to browse files',
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilitySettings(UserRole? userRole, bool isDark) {
    final isEducator = userRole == UserRole.educator;
    final isAdminOrSuperAdmin = userRole == UserRole.admin || userRole == UserRole.superadmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Visibility Options'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ChoiceChip(
              label: Text('Public', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              avatar: const Icon(Icons.public_rounded, size: 18),
              selected: _visibility == ContentVisibility.public,
              selectedColor: const Color(0xFF88B342).withValues(alpha: 0.2),
              backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
              checkmarkColor: const Color(0xFF88B342),
              labelStyle: TextStyle(color: _visibility == ContentVisibility.public ? const Color(0xFF88B342) : (isDark ? Colors.white : Colors.black87)),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
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
              avatar: const Icon(Icons.people_alt_rounded, size: 18),
              selected: _visibility == ContentVisibility.membersOnly,
              selectedColor: const Color(0xFF88B342).withValues(alpha: 0.2),
              backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
              checkmarkColor: const Color(0xFF88B342),
              labelStyle: TextStyle(color: _visibility == ContentVisibility.membersOnly ? const Color(0xFF88B342) : (isDark ? Colors.white : Colors.black87)),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
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
              backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
              checkmarkColor: const Color(0xFF88B342),
              labelStyle: TextStyle(color: _visibility == ContentVisibility.certainUsers ? const Color(0xFF88B342) : (isDark ? Colors.white : Colors.black87)),
              side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
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
          const SizedBox(height: 20),
          UserVisibilitySelector(
            selectedUserIds: _visibleTo,
            educatorUid: isEducator ? AuthService.instance.currentUser?.uid : null,
            onChanged: (users) => setState(() => _visibleTo = users),
          ),
        ],
        if (isAdminOrSuperAdmin) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF88B342).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFF88B342).withValues(alpha: 0.3)),
            ),
            child: CheckboxListTile(
              title: Text('Upload as Grammatica Lesson', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF2A2A2A))),
              subtitle: Text('Shows in the global learning section for all users', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
              value: _isGrammaticaLesson,
              activeColor: const Color(0xFF88B342),
              onChanged: (value) => setState(() => _isGrammaticaLesson = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _generateFromPdf() async {
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

        final generatedMarkdown = await _aiLogicService.convertToMarkdown(bytes);

        setState(() {
          _prompt.text = generatedMarkdown;
          _isGeneratingFromPdf = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully generated lesson from PDF!')),
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

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && mounted) {
      setState(() => _selectedFiles = result.files);
    }
  }

  void _resetForm({bool callOnReset = true}) {
    _selectedLessonId = null;
    _selectedLesson = null;
    _selectedQuizId = null;
    _title.clear();
    _prompt.clear();
    _selectedFiles = [];
    _isVisible = true;
    _isMembersOnly = false;
    _isGrammaticaLesson = false;
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    _quizKey.currentState?.resetForm();
    if (callOnReset && widget.onReset != null) widget.onReset!();
  }

  Future<void> _saveIntegratedLesson() async {
    setState(() => _creatingLesson = true);
    try {
      String? finalQuizId = _selectedQuizId;

      if (_quizKey.currentState != null) {
        final savedQuizId = await _quizKey.currentState!.saveForLesson();
        if (savedQuizId != null) {
          finalQuizId = savedQuizId;
        }
      }

      final lessonData = Lesson(
        id: _selectedLessonId ?? '',
        title: _title.text.trim(),
        prompt: _prompt.text.trim(),
        answer: '',
        createdByUid: AuthService.instance.currentUser?.uid ?? '',
        isVisible: _isVisible,
        visibleTo: _visibleTo,
        isMembersOnly: _isMembersOnly,
        isGrammaticaLesson: _isGrammaticaLesson,
        quizId: finalQuizId, 
        createdAt: _selectedLesson?.createdAt ?? Timestamp.now(),
      );

      if (_selectedLessonId == null) {
        await DatabaseService.instance.createLesson(
          title: lessonData.title,
          prompt: lessonData.prompt,
          answer: lessonData.answer,
          isVisible: lessonData.isVisible,
          visibleTo: lessonData.visibleTo,
          isMembersOnly: lessonData.isMembersOnly,
          isGrammaticaLesson: lessonData.isGrammaticaLesson,
          quizId: lessonData.quizId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson & Quiz created successfully!')),
          );
        }
      } else {
        await DatabaseService.instance.updateLesson(
          id: _selectedLessonId!,
          title: lessonData.title,
          prompt: lessonData.prompt,
          answer: lessonData.answer,
          isVisible: lessonData.isVisible,
          visibleTo: lessonData.visibleTo,
          isMembersOnly: lessonData.isMembersOnly,
          isGrammaticaLesson: lessonData.isGrammaticaLesson,
          quizId: lessonData.quizId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson & Quiz updated successfully!')),
          );
        }
      }
      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving lesson: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingLesson = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }
}
