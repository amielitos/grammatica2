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
import '../../widgets/user_visibility_selector.dart';
import '../../models/content_visibility.dart';
import '../../models/ai_models.dart';

import 'admin_quizzes_tab.dart'; 
import '../../pages/lesson_page.dart';

class AdminContentBlockState {
  String type; // 'text' or 'image'
  final TextEditingController textCtrl;
  String? imageUrl;
  bool isUploading = false;

  AdminContentBlockState({
    required this.type,
    String text = '',
    this.imageUrl,
  }) : textCtrl = TextEditingController(text: text);

  void dispose() {
    textCtrl.dispose();
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
  final _aiPromptCtrl = TextEditingController();
  bool _isVisible = true;
  bool _isMembersOnly = false;
  bool _isGrammaticaLesson = false;
  List<String> _visibleTo = [];
  final _quizKey = GlobalKey<AdminQuizzesTabState>();
  String? _selectedQuizId;

  // Structured content blocks (Text and Image)
  List<AdminContentBlockState> _contentBlocks = [];

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

    for (final block in _contentBlocks) {
      block.dispose();
    }
    _contentBlocks = [];

    if (l.hasContentBlocks) {
      _contentBlocks = l.contentBlocks.map((b) {
        final type = (b['type'] ?? 'text').toString();
        return AdminContentBlockState(
          type: type,
          text: type == 'image' ? (b['caption'] ?? '').toString() : (b['data'] ?? '').toString(),
          imageUrl: type == 'image' ? (b['data'] as String?) : null,
        );
      }).toList();
    } else if (l.prompt.isNotEmpty) {
      _contentBlocks = [
        AdminContentBlockState(type: 'text', text: l.prompt),
      ];
    }

    if (l.isMembersOnly) {
      _visibility = ContentVisibility.membersOnly;
    } else if (!l.isVisible && l.visibleTo.isNotEmpty) {
      _visibility = ContentVisibility.certainUsers;
    } else {
      _visibility = ContentVisibility.public;
    }
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
              OutlinedButton.icon(
                onPressed: _title.text.trim().isEmpty && _contentBlocks.isEmpty
                    ? null
                    : _previewLesson,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 20),
                label: Text('Preview', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: (_creatingLesson || _title.text.trim().isEmpty) ? null : _saveLesson,
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
                Text('Generate from Prompt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF2A2A2A))),
                const SizedBox(height: 8),
                _buildStyledTextField(
                  controller: _aiPromptCtrl,
                  label: 'Lesson Topic / Prompt',
                  hint: 'e.g. Write a lesson about English past perfect tense with examples and a summary table',
                  icon: Icons.psychology_rounded,
                  maxLines: 3,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isGeneratingFromPrompt ? null : _generateFromPrompt,
                    icon: _isGeneratingFromPrompt
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_isGeneratingFromPrompt ? 'Generating Lesson...' : 'Generate via Prompt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF88B342),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text('Generate from Source Document', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF2A2A2A))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingFromPdf ? null : _generateFromPdf,
                    icon: _isGeneratingFromPdf 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(_isGeneratingFromPdf ? 'Generating...' : 'Select PDF & Generate Lesson'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
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

  Future<void> _pickAndUploadImageForBlock(AdminContentBlockState block) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => block.isUploading = true);

      final platformFile = result.files.single;
      List<int> bytes;
      if (platformFile.bytes != null) {
        bytes = platformFile.bytes!;
      } else if (platformFile.path != null) {
        bytes = await File(platformFile.path!).readAsBytes();
      } else {
        throw Exception('Could not read image file bytes');
      }

      final fileName = 'lesson_img_${DateTime.now().millisecondsSinceEpoch}_${platformFile.name}';

      final url = await DatabaseService.instance.uploadGeneratedImage(
        Uint8List.fromList(bytes),
        fileName,
      );

      setState(() {
        block.imageUrl = url;
        block.isUploading = false;
      });
    } catch (e) {
      setState(() => block.isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  Widget _buildContentBlocks(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Content Blocks (${_contentBlocks.length})',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _contentBlocks.add(AdminContentBlockState(type: 'text'));
                    });
                  },
                  icon: const Icon(Icons.title_rounded, size: 16),
                  label: const Text('Add Text'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _contentBlocks.add(AdminContentBlockState(type: 'image'));
                    });
                  },
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('Add Image'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_contentBlocks.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Content Blocks Yet',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Click "Add Text" or "Add Image" above, or use the "AI Generation" section to generate structured content blocks.',
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...List.generate(_contentBlocks.length, (index) {
            final block = _contentBlocks[index];
            final isImage = block.type == 'image';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF333333) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isImage
                        ? Colors.blueAccent.withValues(alpha: 0.4)
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isImage
                            ? Colors.blueAccent.withValues(alpha: 0.08)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isImage ? Icons.image_rounded : Icons.text_snippet_rounded,
                            size: 16,
                            color: isImage ? Colors.blueAccent : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Block ${index + 1} • ${isImage ? "IMAGE BLOCK" : "TEXT BLOCK"}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isImage ? Colors.blueAccent : AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setState(() {
                                _contentBlocks[index].dispose();
                                _contentBlocks.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: isImage
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Dedicated Image Widget Container
                                if (block.imageUrl != null && block.imageUrl!.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      block.imageUrl!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 120,
                                        color: Colors.grey.shade200,
                                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: block.isUploading ? null : () => _pickAndUploadImageForBlock(block),
                                        icon: const Icon(Icons.upload_file, size: 16),
                                        label: const Text('Change Image'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => setState(() => block.imageUrl = null),
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        label: const Text('Remove Image', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, style: BorderStyle.solid),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.blueAccent.withValues(alpha: 0.7)),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No Image Uploaded',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 12),
                                        block.isUploading
                                            ? const CircularProgressIndicator()
                                            : FilledButton.icon(
                                                onPressed: () => _pickAndUploadImageForBlock(block),
                                                icon: const Icon(Icons.upload_file_rounded, size: 18),
                                                label: const Text('Upload Image File'),
                                                style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
                                              ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextField(
                                  controller: block.textCtrl,
                                  style: GoogleFonts.inter(fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Image Caption (optional)',
                                    hintText: 'e.g. Diagram explaining English syntax',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            )
                          : TextField(
                              controller: block.textCtrl,
                              maxLines: 6,
                              minLines: 3,
                              style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Enter text block paragraph...',
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

  Future<void> _generateFromPdf() async {
    setState(() => _isGeneratingFromPdf = true);

    try {
      late final dynamic lessonResponse;

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

      lessonResponse = await _aiLogicService.generateLessonFromPdf(bytes);

      // Populate blocks from AI response
      for (final b in _contentBlocks) {
        b.dispose();
      }

      final blocks = <AdminContentBlockState>[];
      if (_title.text.trim().isEmpty) {
        _title.text = lessonResponse.title;
      }

      for (final block in lessonResponse.content) {
        switch (block.type) {
          case ContentBlockType.text:
            final text = block.data.toString();
            if (text.isNotEmpty) {
              blocks.add(AdminContentBlockState(type: 'text', text: text));
            }
            break;
          case ContentBlockType.list:
            final text = (block.data as List).map((item) => '• $item').join('\n');
            if (text.isNotEmpty) {
              blocks.add(AdminContentBlockState(type: 'text', text: text));
            }
            break;
          case ContentBlockType.table:
            final rows = block.data as List;
            if (rows.isNotEmpty) {
              final headers = (rows.first as Map<String, dynamic>).keys.toList();
              final buffer = StringBuffer('| ${headers.join(' | ')} |\n');
              buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');
              for (final row in rows) {
                final r = row as Map<String, dynamic>;
                buffer.writeln('| ${headers.map((h) => r[h]?.toString() ?? '').join(' | ')} |');
              }
              blocks.add(AdminContentBlockState(type: 'text', text: buffer.toString()));
            }
            break;
          case ContentBlockType.image:
            try {
              final prompt = block.data.toString();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating AI image for lesson...'), duration: Duration(seconds: 2)),
                );
              }
              final imageBytes = await _aiLogicService.generateImageFromPrompt(prompt);
              final fileName = 'ai_lesson_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final url = await DatabaseService.instance.uploadGeneratedImage(imageBytes, fileName);
              blocks.add(AdminContentBlockState(type: 'image', imageUrl: url, text: ''));
            } catch (e) {
              debugPrint('Error generating image block: $e');
              blocks.add(AdminContentBlockState(type: 'image', imageUrl: null, text: block.data.toString()));
            }
            break;
        }
      }

      _prompt.text = blocks.where((b) => b.type == 'text').map((c) => c.textCtrl.text).join('\n\n');

      setState(() {
        _contentBlocks = blocks;
        _isGeneratingFromPdf = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${blocks.length} content blocks!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingFromPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating from source: $e')),
        );
      }
    }
  }

  Future<void> _generateFromPrompt() async {
    final promptText = _aiPromptCtrl.text.trim();
    if (promptText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt first.')),
      );
      return;
    }

    setState(() => _isGeneratingFromPrompt = true);

    try {
      final lessonResponse = await _aiLogicService.generateLesson(promptText);

      for (final b in _contentBlocks) {
        b.dispose();
      }

      final blocks = <AdminContentBlockState>[];
      if (_title.text.trim().isEmpty) {
        _title.text = lessonResponse.title;
      }

      for (final block in lessonResponse.content) {
        switch (block.type) {
          case ContentBlockType.text:
            final text = block.data.toString();
            if (text.isNotEmpty) {
              blocks.add(AdminContentBlockState(type: 'text', text: text));
            }
            break;
          case ContentBlockType.list:
            final text = (block.data as List).map((item) => '• $item').join('\n');
            if (text.isNotEmpty) {
              blocks.add(AdminContentBlockState(type: 'text', text: text));
            }
            break;
          case ContentBlockType.table:
            final rows = block.data as List;
            if (rows.isNotEmpty) {
              final headers = (rows.first as Map<String, dynamic>).keys.toList();
              final buffer = StringBuffer('| ${headers.join(' | ')} |\n');
              buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');
              for (final row in rows) {
                final r = row as Map<String, dynamic>;
                buffer.writeln('| ${headers.map((h) => r[h]?.toString() ?? '').join(' | ')} |');
              }
              blocks.add(AdminContentBlockState(type: 'text', text: buffer.toString()));
            }
            break;
          case ContentBlockType.image:
            try {
              final prompt = block.data.toString();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating AI image for lesson...'), duration: Duration(seconds: 2)),
                );
              }
              final imageBytes = await _aiLogicService.generateImageFromPrompt(prompt);
              final fileName = 'ai_lesson_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final url = await DatabaseService.instance.uploadGeneratedImage(imageBytes, fileName);
              blocks.add(AdminContentBlockState(type: 'image', imageUrl: url, text: ''));
            } catch (e) {
              debugPrint('Error generating image block: $e');
              blocks.add(AdminContentBlockState(type: 'image', imageUrl: null, text: block.data.toString()));
            }
            break;
        }
      }

      _prompt.text = blocks.where((b) => b.type == 'text').map((c) => c.textCtrl.text).join('\n\n');

      setState(() {
        _contentBlocks = blocks;
        _isGeneratingFromPrompt = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${blocks.length} content blocks from prompt!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingFromPrompt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating from prompt: $e')),
        );
      }
    }
  }

  void _resetForm({bool callOnReset = true}) {
    _selectedLessonId = null;
    _selectedLesson = null;
    _selectedQuizId = null;
    _title.clear();
    _prompt.clear();
    for (final block in _contentBlocks) {
      block.dispose();
    }
    _contentBlocks = [];
    _isVisible = true;
    _isMembersOnly = false;
    _isGrammaticaLesson = false;
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    _quizKey.currentState?.resetForm();
    if (callOnReset && widget.onReset != null) widget.onReset!();
  }

  Future<void> _saveLesson() async {
    setState(() => _creatingLesson = true);
    try {
      final contentBlocksData = _contentBlocks.map((b) {
        if (b.type == 'image') {
          return {
            'type': 'image',
            'data': b.imageUrl ?? '',
            'caption': b.textCtrl.text.trim(),
          };
        } else {
          return {
            'type': 'text',
            'data': b.textCtrl.text.trim(),
          };
        }
      }).where((b) => (b['data'] ?? '').toString().isNotEmpty || (b['caption'] ?? '').toString().isNotEmpty).toList();

      final textSummary = _contentBlocks
          .where((b) => b.type == 'text')
          .map((b) => b.textCtrl.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n\n');

      final lessonData = Lesson(
        id: _selectedLessonId ?? '',
        title: _title.text.trim(),
        prompt: textSummary.isNotEmpty ? textSummary : _prompt.text.trim(),
        answer: '',
        createdByUid: AuthService.instance.currentUser?.uid ?? '',
        isVisible: _isVisible,
        visibleTo: _visibleTo,
        isMembersOnly: _isMembersOnly,
        isGrammaticaLesson: _isGrammaticaLesson,
        quizId: _selectedQuizId, 
        createdAt: _selectedLesson?.createdAt ?? Timestamp.now(),
        contentBlocks: contentBlocksData,
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
          validationStatus: 'approved',
          contentBlocks: contentBlocksData,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson saved successfully!')),
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
          validationStatus: 'approved',
          contentBlocks: contentBlocksData,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson updated successfully!')),
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
    _aiPromptCtrl.dispose();
    for (final block in _contentBlocks) {
      block.dispose();
    }
    super.dispose();
  }

  void _previewLesson() {
    // Build content blocks data for preview
    final contentBlocksData = _contentBlocks.map((b) {
      if (b.type == 'image') {
        return {
          'type': 'image',
          'data': b.imageUrl ?? '',
          'caption': b.textCtrl.text.trim(),
        };
      } else {
        return {
          'type': 'text',
          'data': b.textCtrl.text.trim(),
        };
      }
    }).toList();

    final textSummary = _contentBlocks
        .where((b) => b.type == 'text')
        .map((b) => b.textCtrl.text.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');

    final previewLesson = Lesson(
      id: 'preview',
      title: _title.text.trim().isNotEmpty ? _title.text.trim() : 'Untitled Lesson',
      prompt: textSummary,
      answer: '',
      createdByUid: AuthService.instance.currentUser?.uid ?? '',
      isVisible: _isVisible,
      visibleTo: _visibleTo,
      isMembersOnly: _isMembersOnly,
      isGrammaticaLesson: _isGrammaticaLesson,
      createdAt: Timestamp.now(),
      contentBlocks: contentBlocksData,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonPage(
          user: AuthService.instance.currentUser!,
          lesson: previewLesson,
          previewMode: true,
        ),
      ),
    );
  }
}
