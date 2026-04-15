import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/markdown_guide_button.dart';
import '../../widgets/interactive_markdown.dart';
import '../../services/ai_logic_service.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../widgets/user_visibility_selector.dart';
import '../../models/content_visibility.dart';

import 'admin_quizzes_tab.dart'; // Import to use as a sub-tab

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
  String? _tempPdfText; // Store extracted text temporarily
  final AILogicService _aiLogicService = AILogicService();
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  List<PlatformFile> _selectedFiles = [];
  bool _isVisible = true;
  bool _isMembersOnly = false;
  bool _isGrammaticaLesson = false;
  List<String> _visibleTo = [];
  final _quizKey = GlobalKey<AdminQuizzesTabState>();
  String? _selectedQuizId; // Link Quiz

  ContentVisibility _visibility = ContentVisibility.public;

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

    // Load quiz into integrated quiz tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (l.quizId != null) {
        _quizKey.currentState?.loadQuiz(l.quizId!);
      }
    });
  }

  int _tabIndex = 0; // 0 for Lessons, 1 for Quizzes

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return StreamBuilder<UserRole>(
      stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
      builder: (context, roleSnap) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Manage Content',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 16),
              // Segmented Toggle
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 36,
                  width: 240,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabIndex = 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _tabIndex == 0 ? const Color(0xFF88B342) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Lessons',
                              style: TextStyle(
                                color: _tabIndex == 0 ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabIndex = 1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _tabIndex == 1 ? const Color(0xFF88B342) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Quizzes',
                              style: TextStyle(
                                color: _tabIndex == 1 ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Main Card Content
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    _buildLessonForm(roleSnap.data),
                    AdminQuizzesTab(
                      key: _quizKey,
                      initialQuizId: _selectedQuizId,
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

  Widget _buildLessonForm(UserRole? role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildLessonLeftCol(role)),
                        const SizedBox(width: 32),
                        Expanded(flex: 1, child: _buildPdfAttachZone()),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLessonLeftCol(role),
                        const SizedBox(height: 24),
                        _buildPdfAttachZone(),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _resetForm(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: (_creatingLesson || _title.text.trim().isEmpty) ? null : _saveIntegratedLesson,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF88B342),
                ),
                icon: _creatingLesson
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Save Lesson'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLessonLeftCol(UserRole? role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        const Text('Content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _prompt,
          decoration: InputDecoration(
            hintText: 'Write your lesson content here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(16),
          ),
          maxLines: 10,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildVisibilitySettings(role)),
            const SizedBox(width: 16),
            const MarkdownGuideButton(),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isGeneratingFromPdf ? null : _generateFromPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF88B342),
                foregroundColor: Colors.white,
              ),
              icon: _isGeneratingFromPdf
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Generate from PDF'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPdfAttachZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Attach PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickFiles,
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
                  _selectedFiles.isNotEmpty ? _selectedFiles.first.name : 'No PDF uploaded yet',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFiles.isNotEmpty ? 'Click to change file' : 'Upload PDF to attach to this lesson.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title of Lesson:'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _prompt,
          decoration: const InputDecoration(
            labelText: 'Content (markdown):',
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const MarkdownGuideButton(),
            ElevatedButton.icon(
              onPressed: _isGeneratingFromPdf ? null : _generateFromPdf,
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
      ],
    );
  }

  Future<void> _generateFromPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Required for Web
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

        setState(() {
          _tempPdfText = extractedText;
        });

        // Use MarkItDown (via backend) to convert original PDF bytes to markdown
        final generatedMarkdown = await _aiLogicService.convertToMarkdown(
          bytes,
        );

        setState(() {
          _prompt.text = generatedMarkdown;
          _isGeneratingFromPdf = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully generated lesson from PDF!'),
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

  Widget _buildVisibilitySettings(UserRole? userRole) {
    final isEducator = userRole == UserRole.educator;
    final isAdminOrSuperAdmin =
        userRole == UserRole.admin || userRole == UserRole.superadmin;

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
              if (_visibility == ContentVisibility.public) {
                _isVisible = true;
                _isMembersOnly = false;
              } else if (_visibility == ContentVisibility.membersOnly) {
                _isVisible = true;
                _isMembersOnly = true;
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
        if (isAdminOrSuperAdmin) ...[
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Upload as Grammatica lesson'),
            subtitle: const Text(
                'This will make the lesson show up in the learning section for all users'),
            value: _isGrammaticaLesson,
            onChanged: (value) => setState(() => _isGrammaticaLesson = value),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preview:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _prompt.text.isEmpty
                  ? [const Text('*Preview will appear here*')]
                  : [_prompt.text].map((part) {
                      final trimmed = part.trim();
                      if (trimmed.isEmpty) return const SizedBox.shrink();
                      return InteractiveMarkdown(data: trimmed);
                    }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('Attach Files'),
            ),
            const SizedBox(width: 8),
            Text('${_selectedFiles.length} files selected'),
          ],
        ),
        if (_selectedFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _selectedFiles
                .map(
                  (f) => Chip(
                    label: Text(f.name),
                    onDeleted: () => setState(() => _selectedFiles.remove(f)),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRawTextButton() {
    return TextButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Raw Extracted Text'),
            content: SingleChildScrollView(
              child: SelectableText(_tempPdfText!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.description_outlined),
      label: const Text('View Raw Extracted Text'),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      if (mounted) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
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
    _tempPdfText = null; // Clear the temporary PDF text
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    _quizKey.currentState?.resetForm();
    if (callOnReset && widget.onReset != null) widget.onReset!();
  }

  Future<void> _saveIntegratedLesson() async {
    setState(() => _creatingLesson = true);
    try {
      String? finalQuizId = _selectedQuizId;

      // If we are on the Quizzes tab OR there's a quiz being edited, save it first
      if (_quizKey.currentState != null) {
        final savedQuizId = await _quizKey.currentState!.saveForLesson();
        if (savedQuizId != null) {
          finalQuizId = savedQuizId;
        }
      }

      // Create/Update the standalone lesson
      final lessonData = Lesson(
        id: _selectedLessonId ?? '',
        title: _title.text.trim(),
        prompt: _prompt.text.trim(),
        answer: '', // Lesson model requires an answer field
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
            const SnackBar(
              content: Text('Lesson & Quiz created successfully!'),
            ),
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
            const SnackBar(
              content: Text('Lesson & Quiz updated successfully!'),
            ),
          );
        }
      }
      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving lesson: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _creatingLesson = false);
      }
    }
  }

  Widget _buildDangerZone(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      tooltip: 'Danger Zone',
      onSelected: (val) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Wipeout'),
            content: Text(
              'Are you SURE you want to clear ALL $val? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Wipe Status'),
              ),
            ],
          ),
        );

        if (confirmed == true && mounted) {
          try {
            if (val == 'Lessons') {
              await DatabaseService.instance.clearAllLessons();
            } else {
              await DatabaseService.instance.clearAllQuizzes();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('All $val wiped successfully.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'Lessons',
          child: Text('Wipe All Lessons', style: TextStyle(color: Colors.red)),
        ),
        const PopupMenuItem(
          value: 'Quizzes',
          child: Text('Wipe All Quizzes', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }
}
