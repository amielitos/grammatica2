import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../services/database_service.dart';
import '../../services/ai_logic_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/interactive_markdown.dart';
import '../../widgets/user_visibility_selector.dart';
import '../../models/content_visibility.dart';
import '../../models/ai_models.dart';

import 'admin_quizzes_tab.dart'; 
import 'admin_assessments_tab.dart';

class EditableContentBlock {
  final String id;
  String type; // 'text', 'list', 'table', 'image'
  final TextEditingController textCtrl;
  String? imageUrl;
  String? imageDescription;
  Uint8List? pendingImageBytes;
  String? pendingImageFileName;

  EditableContentBlock({
    required this.id,
    required this.type,
    required this.textCtrl,
    this.imageUrl,
    this.imageDescription,
    this.pendingImageBytes,
    this.pendingImageFileName,
  });

  EditableContentBlock copy() {
    return EditableContentBlock(
      id: id,
      type: type,
      textCtrl: TextEditingController(text: textCtrl.text),
      imageUrl: imageUrl,
      imageDescription: imageDescription,
      pendingImageBytes: pendingImageBytes,
      pendingImageFileName: pendingImageFileName,
    );
  }
}

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
  bool _isGeneratingFromPrompt = false;

  final AILogicService _aiLogicService = AILogicService();
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  bool _isVisible = true;
  bool _isMembersOnly = false;
  bool _isGrammaticaLesson = false;
  List<String> _visibleTo = [];
  final _quizKey = GlobalKey<AdminQuizzesTabState>();
  String? _selectedQuizId;

  // AI-generated & manual content blocks
  List<EditableContentBlock> _contentBlocks = [];
  List<EditableContentBlock> _cachedOriginalBlocks = [];

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
        final isEducator = roleSnap.data == UserRole.educator;
        if (isEducator && _tabIndex > 1) {
          _tabIndex = 0;
        }

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
                'Create or edit your lessons and quizzes.',
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
                  width: isEducator ? 340 : 500,
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
                      if (!isEducator) _buildTabBtn('Assessments', 2),
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
                  index: _tabIndex.clamp(0, isEducator ? 1 : 2),
                  children: [
                    _buildLessonForm(roleSnap.data, isDark),
                    AdminQuizzesTab(
                      key: _quizKey,
                      initialQuizId: _selectedQuizId,
                    ),
                    if (!isEducator)
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
                    Expanded(flex: 2, child: _buildContentBlocks(isDark)),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLessonLeftCol(role, isDark),
                    const SizedBox(height: 32),
                    _buildContentBlocks(isDark),
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
          _buildVisibilitySettings(role, isDark),
          const SizedBox(height: 32),
          
          // AI Generation Config
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Generation Config',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2A2A2A),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Generate from Prompt or PDF Source', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF2A2A2A))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: (_isGeneratingFromPrompt || _isGeneratingFromPdf || _prompt.text.trim().isEmpty) ? null : _generateFromTextPrompt,
                      icon: _isGeneratingFromPrompt 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(_isGeneratingFromPrompt ? 'Generating...' : 'Generate from Prompt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF88B342),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_isGeneratingFromPrompt || _isGeneratingFromPdf) ? null : _generateFromPdf,
                      icon: _isGeneratingFromPdf 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(_isGeneratingFromPdf ? 'Generating...' : 'Select PDF & Generate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : const Color(0xFF2A2A2A),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _prompt,
            label: 'Put Your Prompt Here',
            hint: 'Put Your Prompt Here',
            icon: Icons.lightbulb_rounded,
            maxLines: 2,
            isDark: isDark,
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

  Widget _buildContentBlocks(bool isDark) {
    if (_contentBlocks.isEmpty) {
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
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'AI Content Blocks',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the AI Generation Config to generate content blocks, or add blocks manually.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PopupMenuButton<String>(
              onSelected: (type) => _addContentBlock(type),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'text', child: Text('Text Block')),
                const PopupMenuItem(value: 'list', child: Text('List Block')),
                const PopupMenuItem(value: 'table', child: Text('Table Block')),
                const PopupMenuItem(value: 'image', child: Text('Image Block')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text('Add Manual Block', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              'Content Blocks (${_contentBlocks.length})',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (_cachedOriginalBlocks.isNotEmpty)
                  TextButton.icon(
                    onPressed: _revertToOriginalBlocks,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Revert Layout'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
                  ),
                TextButton.icon(
                  onPressed: _showPreviewDialog,
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('Preview'),
                ),
                PopupMenuButton<String>(
                  onSelected: (type) => _addContentBlock(type),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'text', child: Text('Text Block')),
                    const PopupMenuItem(value: 'list', child: Text('List Block')),
                    const PopupMenuItem(value: 'table', child: Text('Table Block')),
                    const PopupMenuItem(value: 'image', child: Text('Image Block')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('Add Block', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_contentBlocks.length, (index) {
          final block = _contentBlocks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333333) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Block Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Block ${index + 1} (${block.type.toUpperCase()})',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          onPressed: index > 0 ? () => _moveBlock(index, index - 1) : null,
                          tooltip: 'Move Up',
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                          onPressed: index < _contentBlocks.length - 1 ? () => _moveBlock(index, index + 1) : null,
                          tooltip: 'Move Down',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                          onPressed: () => _removeBlock(index),
                          tooltip: 'Delete Block',
                        ),
                      ],
                    ),
                  ),
                  
                  // Block Content Area
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: block.type == 'image'
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (block.imageDescription != null && block.imageDescription!.trim().isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'AI Recommendation: ${block.imageDescription}',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              InkWell(
                                onTap: () => _uploadImageForBlock(block),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(minHeight: 160, maxHeight: 280),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: block.imageUrl != null ? AppColors.primary : (isDark ? Colors.white24 : Colors.grey.shade400),
                                      width: 2,
                                    ),
                                  ),
                                  child: (block.pendingImageBytes != null || (block.imageUrl != null && block.imageUrl!.isNotEmpty))
                                      ? Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: block.pendingImageBytes != null
                                                      ? Image.memory(
                                                          block.pendingImageBytes!,
                                                          fit: BoxFit.contain,
                                                          height: 220,
                                                        )
                                                      : Image.network(
                                                          block.imageUrl!,
                                                          fit: BoxFit.contain,
                                                          height: 220,
                                                        ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.7),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                                                    const SizedBox(width: 4),
                                                    Text('Change', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.cloud_upload_outlined, size: 32, color: AppColors.primary),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Drop your image here',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : const Color(0xFF2A2A2A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'or click to browse from device',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          )
                        : TextField(
                            controller: block.textCtrl,
                            maxLines: 8,
                            minLines: 3,
                            style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Edit block content...',
                              hintStyle: GoogleFonts.inter(color: isDark ? Colors.white30 : Colors.grey.shade400),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _addContentBlock(String type) {
    setState(() {
      _contentBlocks.add(EditableContentBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        textCtrl: TextEditingController(),
        imageDescription: type == 'image' ? 'Upload an image relevant to this section.' : null,
      ));
    });
  }

  void _removeBlock(int index) {
    setState(() {
      _contentBlocks[index].textCtrl.dispose();
      _contentBlocks.removeAt(index);
    });
  }

  void _moveBlock(int oldIndex, int newIndex) {
    setState(() {
      final item = _contentBlocks.removeAt(oldIndex);
      _contentBlocks.insert(newIndex, item);
    });
  }

  void _revertToOriginalBlocks() {
    setState(() {
      for (final b in _contentBlocks) {
        b.textCtrl.dispose();
      }
      _contentBlocks = _cachedOriginalBlocks.map((b) => b.copy()).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reverted to original AI block layout!')),
    );
  }

  Future<void> _uploadImageForBlock(EditableContentBlock block) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;
      List<int> bytes;
      if (platformFile.bytes != null) {
        bytes = platformFile.bytes!;
      } else if (platformFile.path != null) {
        bytes = await File(platformFile.path!).readAsBytes();
      } else {
        throw Exception('Could not read image file data');
      }

      setState(() {
        block.pendingImageBytes = Uint8List.fromList(bytes);
        block.pendingImageFileName = platformFile.name;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image cached locally! It will be uploaded when you save the lesson.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _showPreviewDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.backgroundBase,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Interactive Lesson Card Preview',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title.text.isEmpty ? 'Untitled Lesson' : _title.text,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_contentBlocks.isEmpty)
                    const Text('No content blocks available.')
                  else
                    ..._contentBlocks.map((b) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (b.type == 'image') ...[
                              if (b.pendingImageBytes != null)
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(b.pendingImageBytes!, fit: BoxFit.contain, height: 260),
                                  ),
                                )
                              else if (b.imageUrl != null && b.imageUrl!.isNotEmpty)
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(b.imageUrl!, fit: BoxFit.contain, height: 260),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                            ] else ...[
                              InteractiveMarkdown(data: b.textCtrl.text.trim()),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
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
            child: Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                title: Text('Upload as Grammatica Lesson', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF2A2A2A))),
                subtitle: Text('Shows in the global learning section for all users', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                value: _isGrammaticaLesson,
                activeColor: const Color(0xFF88B342),
                onChanged: (value) => setState(() => _isGrammaticaLesson = value ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _processGeneratedLesson(AILessonResponse lessonResponse) async {
    for (final b in _contentBlocks) {
      b.textCtrl.dispose();
    }

    final newBlocks = <EditableContentBlock>[];
    if (_title.text.trim().isEmpty) {
      _title.text = lessonResponse.title;
    }

    int idx = 0;
    for (final block in lessonResponse.content) {
      idx++;
      String blockText = '';
      String blockType = 'text';
      String? imgDesc;

      switch (block.type) {
        case ContentBlockType.text:
          blockType = 'text';
          blockText = block.data.toString();
          break;
        case ContentBlockType.list:
          blockType = 'list';
          blockText = (block.data as List).map((item) => '• $item').join('\n');
          break;
        case ContentBlockType.table:
          blockType = 'table';
          final rows = block.data as List;
          if (rows.isNotEmpty) {
            final headers = (rows.first as Map<String, dynamic>).keys.toList();
            final buffer = StringBuffer('| ${headers.join(' | ')} |\n');
            buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');
            for (final row in rows) {
              final r = row as Map<String, dynamic>;
              buffer.writeln('| ${headers.map((h) => r[h]?.toString() ?? '').join(' | ')} |');
            }
            blockText = buffer.toString();
          } else {
            blockText = '';
          }
          break;
        case ContentBlockType.image:
          blockType = 'image';
          imgDesc = block.data.toString();
          blockText = '[Image Placeholder: $imgDesc]';
          break;
      }

      newBlocks.add(EditableContentBlock(
        id: '${DateTime.now().millisecondsSinceEpoch}_$idx',
        type: blockType,
        textCtrl: TextEditingController(text: blockText),
        imageDescription: imgDesc,
      ));
    }

    setState(() {
      _contentBlocks = newBlocks;
      _cachedOriginalBlocks = newBlocks.map((b) => b.copy()).toList();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated ${newBlocks.length} content blocks! Placeholders created for images.')),
      );
    }
  }

  Future<void> _generateFromTextPrompt() async {
    final promptText = _prompt.text.trim();
    if (promptText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a lesson topic or prompt first in the "Put Your Prompt Here" field.')),
      );
      return;
    }

    setState(() => _isGeneratingFromPrompt = true);

    try {
      final lessonResponse = await _aiLogicService.generateLesson(promptText);
      await _processGeneratedLesson(lessonResponse);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating lesson from prompt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingFromPrompt = false);
    }
  }

  Future<void> _generateFromPdf() async {
    setState(() => _isGeneratingFromPdf = true);

    try {
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

      final lessonResponse = await _aiLogicService.generateLessonFromPdf(bytes);
      await _processGeneratedLesson(lessonResponse);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating from source: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingFromPdf = false);
    }
  }

  void _resetForm({bool callOnReset = true}) {
    _selectedLessonId = null;
    _selectedLesson = null;
    _selectedQuizId = null;
    _title.clear();
    _prompt.clear();
    for (final block in _contentBlocks) {
      block.textCtrl.dispose();
    }
    _contentBlocks = [];
    _cachedOriginalBlocks = [];
    _isVisible = true;
    _isMembersOnly = false;
    _isGrammaticaLesson = false;
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    _quizKey.currentState?.resetForm();
    if (callOnReset && widget.onReset != null) widget.onReset!();
  }

  Future<void> _saveIntegratedLesson() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson title is required')));
      return;
    }
    // Early validation: check content isn't empty before starting uploads
    final preUploadPrompt = _contentBlocks.isNotEmpty
        ? _contentBlocks.map((c) => c.textCtrl.text).join('\n\n')
        : _prompt.text.trim();

    if (preUploadPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson content cannot be empty')));
      return;
    }

    setState(() => _creatingLesson = true);
    try {
      String? finalQuizId = _selectedQuizId;

      if (_quizKey.currentState != null) {
        final savedQuizId = await _quizKey.currentState!.saveForLesson();
        if (savedQuizId != null) {
          finalQuizId = savedQuizId;
        }
      }

      // Upload any cached pending images before saving
      for (final block in _contentBlocks) {
        if (block.type == 'image' && block.pendingImageBytes != null) {
          try {
            final fileName = block.pendingImageFileName ?? 'lesson_img_${DateTime.now().millisecondsSinceEpoch}.png';
            final folder = 'lesson_images/lesson_${_selectedLessonId ?? DateTime.now().millisecondsSinceEpoch}';
            final url = await DatabaseService.instance.uploadGeneratedImage(
              block.pendingImageBytes!,
              fileName,
              folder: folder,
            );
            block.imageUrl = url;
            block.textCtrl.text = '![Image]($url)';
            block.pendingImageBytes = null;
            block.pendingImageFileName = null;
          } catch (e) {
            debugPrint('Image upload error (non-fatal): $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Warning: Storage upload issue ($e). Saving lesson content.')),
              );
            }
          }
        }
      }

      // Compute lessonPrompt AFTER image uploads so image URLs are included
      final lessonPrompt = _contentBlocks.isNotEmpty
          ? _contentBlocks.map((c) => c.textCtrl.text).join('\n\n')
          : _prompt.text.trim();

      final lessonData = Lesson(
        id: _selectedLessonId ?? '',
        title: _title.text.trim(),
        prompt: lessonPrompt,
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
    for (final block in _contentBlocks) {
      block.textCtrl.dispose();
    }
    super.dispose();
  }
}

