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
import '../lesson_page.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/user_visibility_selector.dart';
import '../../widgets/author_name_widget.dart';
import '../../models/content_visibility.dart';

class AdminLessonsTab extends StatefulWidget {
  const AdminLessonsTab({super.key});
  @override
  State<AdminLessonsTab> createState() => _AdminLessonsTabState();
}

class _AdminLessonsTabState extends State<AdminLessonsTab> {
  String _formatTs(dynamic ts) {
    if (ts == null) return 'N/A';
    DateTime d;
    if (ts is Timestamp) {
      d = ts.toDate().toLocal();
    } else if (ts is DateTime) {
      d = ts.toLocal();
    } else {
      return 'N/A';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String? _selectedLessonId;
  Lesson? _selectedLesson;
  bool _creatingLesson = false;
  final _title = TextEditingController();
  final _prompt = TextEditingController();
  List<PlatformFile> _selectedFiles = [];
  bool _isVisible = true;
  bool _isMembersOnly = false;
  bool _isGrammaticaLesson = false;
  List<String> _visibleTo = [];
  String _searchQuery = '';
  String _selectedFilter = 'Status'; // Default

  final List<String> _filterOptions = ['Name', 'Status', 'Create Date'];

  ContentVisibility _visibility = ContentVisibility.public;

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
              // Editor Section
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
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Manage Lessons',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed:
                                            (_creatingLesson ||
                                                _title.text.trim().isEmpty)
                                            ? null
                                            : _saveLesson,
                                        icon: _creatingLesson
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                CupertinoIcons.floppy_disk,
                                              ),
                                        label: Text(
                                          _selectedLessonId == null
                                              ? 'Create'
                                              : 'Update',
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                        ),
                                      ),
                                      if (_selectedLessonId != null)
                                        OutlinedButton(
                                          onPressed: () =>
                                              setState(() => _resetForm()),
                                          child: const Text('Cancel'),
                                        ),
                                    ],
                                  ),
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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

              // List of Lessons
              StreamBuilder<List<Lesson>>(
                stream: DatabaseService.instance.streamLessons(
                  approvedOnly: false,
                  userRole: role,
                  userId: user?.uid,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    );
                  }
                  var lessons = snapshot.data!.toList();
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    lessons = lessons.where((l) {
                      final title = l.title.toLowerCase();
                      final author = (l.createdByEmail ?? 'Unknown')
                          .toLowerCase();
                      return title.contains(query) || author.contains(query);
                    }).toList();
                  }

                  // Apply sorting based on filter
                  lessons.sort((a, b) {
                    int cmp = 0;
                    if (_selectedFilter == 'Name') {
                      cmp = a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      );
                    } else if (_selectedFilter == 'Status') {
                      // Prioritize awaiting_approval
                      if (a.validationStatus == 'awaiting_approval' &&
                          b.validationStatus != 'awaiting_approval') {
                        cmp = -1;
                      } else if (a.validationStatus != 'awaiting_approval' &&
                          b.validationStatus == 'awaiting_approval') {
                        cmp = 1;
                      } else {
                        cmp = 0;
                      }
                    } else if (_selectedFilter == 'Create Date') {
                      final tsA = a.createdAt;
                      final tsB = b.createdAt;
                      if (tsA == null && tsB == null) {
                        cmp = 0;
                      } else if (tsA == null) {
                        cmp = 1;
                      } else if (tsB == null) {
                        cmp = -1;
                      } else {
                        cmp = tsB.compareTo(tsA); // Newest first
                      }
                    }

                    if (cmp == 0) {
                      // Secondary sort by Name A-Z
                      return a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      );
                    }
                    return cmp;
                  });

                  return Column(
                    children: [
                      AppSearchBar(
                        hintText: 'Search lessons by title or author...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onFilterPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) => CupertinoActionSheet(
                              title: const Text('Filter Lessons By'),
                              actions: _filterOptions.map((option) {
                                return CupertinoActionSheetAction(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = option;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      color: _selectedFilter == option
                                          ? AppColors.primaryGreen
                                          : null,
                                      fontWeight: _selectedFilter == option
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                              cancelButton: CupertinoActionSheetAction(
                                onPressed: () => Navigator.pop(context),
                                isDestructiveAction: true,
                                child: const Text('Cancel'),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (lessons.isEmpty)
                        const Center(child: Text('No lessons found'))
                      else
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: lessons.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final l = lessons[index];
                            final currentUser =
                                AuthService.instance.currentUser;
                            final isSelected = _selectedLessonId == l.id;
                            final color = AppColors.primaryGreen;

                            final isOwner = l.createdByUid == currentUser?.uid;
                            final isPending =
                                l.validationStatus == 'awaiting_approval';

                            return FutureBuilder<bool>(
                              future: _checkEditPermission(
                                l,
                                currentUser?.uid,
                                role,
                              ),
                              initialData: isOwner,
                              builder: (context, editSnap) {
                                final canEdit = editSnap.data ?? false;

                                return GlassCard(
                                  onTap: () {
                                    if (!canEdit) {
                                      // Enable preview for non-editable content
                                      if (currentUser != null) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => LessonPage(
                                              user: currentUser,
                                              lesson: l,
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
                                        _selectedLessonId = l.id;
                                        _selectedLesson = l;
                                        _title.text = l.title;
                                        _prompt.text = l.prompt;
                                        _selectedFiles = [];
                                        _isVisible = l.isVisible;
                                        _isMembersOnly = l.isMembersOnly;
                                        _visibleTo = List<String>.from(
                                          l.visibleTo,
                                        );

                                        if (l.isMembersOnly) {
                                          _visibility =
                                              ContentVisibility.membersOnly;
                                        } else if (!l.isVisible) {
                                          _visibility =
                                              ContentVisibility.certainUsers;
                                        } else {
                                          _visibility =
                                              ContentVisibility.public;
                                        }
                                        _isGrammaticaLesson =
                                            l.isGrammaticaLesson;
                                      }
                                    });
                                  },
                                  backgroundColor: isSelected
                                      ? color
                                      : (!canEdit
                                            ? AppColors.getCardColor(
                                                context,
                                              ).withValues(alpha: 0.5)
                                            : AppColors.getCardColor(context)),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: isPending
                                              ? Colors.teal
                                              : color,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    l.title,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: !canEdit
                                                          ? AppColors.getTextColor(
                                                              context,
                                                            ).withValues(
                                                              alpha: 0.5,
                                                            )
                                                          : AppColors.getTextColor(
                                                              context,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              l.prompt,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: !canEdit
                                                    ? AppColors.getTextColor(
                                                        context,
                                                      ).withValues(alpha: 0.5)
                                                    : AppColors.getTextColor(
                                                        context,
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              children: [
                                                if (l.attachmentName != null &&
                                                    l
                                                        .attachmentName!
                                                        .isNotEmpty)
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        CupertinoIcons
                                                            .paperclip,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        l.attachmentName!,
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                Text(
                                                  'Created: ${_formatTs(l.createdAt ?? Timestamp.now())} • ',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (l.isMembersOnly
                                                                ? Colors.amber
                                                                : Colors.blue)
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          (l.isMembersOnly
                                                                  ? Colors.amber
                                                                  : Colors.blue)
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    l.isMembersOnly
                                                        ? 'Members Only'
                                                        : 'Public',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: l.isMembersOnly
                                                          ? Colors.amber
                                                          : Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                AuthorName(
                                                  uid: l.createdByUid,
                                                  fallbackEmail:
                                                      l.createdByEmail,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isPending) ...[
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.teal.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                            ),
                                            child: const Text(
                                              'Waiting for approval',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.teal,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (canEdit)
                                        IconButton(
                                          icon: const Icon(
                                            CupertinoIcons.trash,
                                          ),
                                          color: Colors.red[300],
                                          onPressed: () => _deleteLesson(l),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
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
          controller: _prompt,
          minLines: 6,
          maxLines: 15,
          decoration: const InputDecoration(
            labelText: 'Content (Markdown)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        const Text(
          'Who can see this content?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ContentVisibility>(
          segments: const [
            ButtonSegment(
              value: ContentVisibility.public,
              label: Text('Public'),
              icon: Icon(Icons.public),
            ),
            ButtonSegment(
              value: ContentVisibility.certainUsers,
              label: Text('Private'),
              icon: Icon(Icons.people_outline),
            ),
            ButtonSegment(
              value: ContentVisibility.membersOnly,
              label: Text('Members'),
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
              } else if (_visibility == ContentVisibility.certainUsers) {
                _isVisible = false;
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
            onChanged: (users) {
              setState(() => _visibleTo = users);
            },
          ),
        ],
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: MarkdownGuideButton(),
        ),
        const SizedBox(height: 16),
        StreamBuilder<UserRole>(
          stream: RoleService.instance.roleStream(
            AuthService.instance.currentUser?.uid ?? '',
          ),
          builder: (context, snapshot) {
            final role = snapshot.data;
            if (role == UserRole.admin || role == UserRole.superadmin) {
              return CheckboxListTile(
                title: const Text('Upload as Grammatica Lesson'),
                subtitle: const Text(
                  'This will appear in the official "Grammatica Lessons" folder',
                ),
                value: _isGrammaticaLesson,
                onChanged: (val) =>
                    setState(() => _isGrammaticaLesson = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              );
            }
            return const SizedBox.shrink();
          },
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
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          ),
          child: MarkdownBody(
            data: _prompt.text.isEmpty ? '_Nothing to preview_' : _prompt.text,
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected: ${result.files.first.name}')),
              );
            }
          },
          icon: const Icon(CupertinoIcons.arrow_up_doc),
          label: const Text('Upload PDF Attachment'),
        ),
        if (_selectedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Chip(
              label: Text(_selectedFiles.first.name),
              onDeleted: () => setState(() => _selectedFiles = []),
            ),
          )
        else if (_selectedLesson?.attachmentName != null &&
            _selectedLesson!.attachmentName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Chip(
              avatar: const Icon(CupertinoIcons.paperclip, size: 16),
              label: Text('Current: ${_selectedLesson!.attachmentName}'),
            ),
          ),
      ],
    );
  }

  void _resetForm() {
    _selectedLessonId = null;
    _selectedLesson = null;
    _title.clear();
    _prompt.clear();
    _selectedFiles = [];
    _isVisible = true;
    _isVisible = true;
    _isMembersOnly = false;
    _isGrammaticaLesson = false;
    _visibility = ContentVisibility.public;
    _visibleTo = [];
    setState(() {});
  }

  Future<void> _saveLesson() async {
    setState(() => _creatingLesson = true);
    try {
      String? attachmentUrl;
      String? attachmentName;

      if (_selectedFiles.isNotEmpty) {
        final file = _selectedFiles.first;
        if (file.size > 2 * 1024 * 1024) {
          throw Exception('File size must be less than 2MB');
        }
        if (file.bytes != null) {
          attachmentUrl = await DatabaseService.instance.uploadDocument(
            fileBytes: file.bytes!,
            fileName: file.name,
            folder: 'lessons',
          );
          attachmentName = file.name;
        }
      } else if (_selectedLesson != null) {
        attachmentUrl = _selectedLesson!.attachmentUrl;
        attachmentName = _selectedLesson!.attachmentName;
      }

      if (_selectedLessonId == null) {
        await DatabaseService.instance.createLesson(
          title: _title.text.trim(),
          prompt: _prompt.text.trim(),
          answer: '',
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          isVisible: _isVisible,
          visibleTo: _visibleTo,
          isMembersOnly: _isMembersOnly,
          isGrammaticaLesson: _isGrammaticaLesson,
        );
        if (mounted) {
          final role = await RoleService.instance.getRole(
            AuthService.instance.currentUser?.uid ?? '',
          );
          if (!mounted) return;
          final isEducator = role == UserRole.educator;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEducator ? 'Lesson submitted for approval' : 'Lesson created',
              ),
            ),
          );
        }
      } else {
        await DatabaseService.instance.updateLesson(
          id: _selectedLessonId!,
          title: _title.text.trim(),
          prompt: _prompt.text.trim(),
          answer: '',
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          isVisible: _isVisible,
          visibleTo: _visibleTo,
          isMembersOnly: _isMembersOnly,
          isGrammaticaLesson: _isGrammaticaLesson,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lesson updated')));
        }
      }
      if (mounted) _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _creatingLesson = false);
    }
  }

  Future<void> _deleteLesson(Lesson l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${l.title}"?'),
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
    try {
      await DatabaseService.instance.deleteLesson(l.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lesson deleted')));
        if (_selectedLessonId == l.id) _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<bool> _checkEditPermission(
    Lesson l,
    String? currentUid,
    UserRole currentRole,
  ) async {
    if (l.createdByUid == currentUid) return true;
    if (currentRole != UserRole.admin && currentRole != UserRole.superadmin) {
      return false;
    }
    if (l.createdByUid == null) return false;
    // Check creator role
    final r = await RoleService.instance.getRole(l.createdByUid!);
    return r == UserRole.admin || r == UserRole.superadmin;
  }
}

