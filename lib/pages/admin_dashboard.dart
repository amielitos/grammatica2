import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/role_service.dart';
import '../services/database_service.dart';
import '../services/app_repository.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _switching = false;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AuthService.instance.currentUser != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(AuthService.instance.currentUser!.uid)
                    .snapshots()
              : null,
          builder: (context, snap) {
            final data = snap.data?.data();
            final user = AuthService.instance.currentUser;
            final username = (data?['username'] ?? user?.email ?? 'Admin')
                .toString();
            return Text('Grammatica - Admin Dashboard — $username');
          },
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              _AdminUsersTab(),
              const _AdminLessonsTab(),
              const _AdminQuizzesTab(),
              ProfilePage(user: AuthService.instance.currentUser!),
            ],
          ),
          if (_switching) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          setState(() => _switching = true);
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          setState(() {
            _index = i;
            _switching = false;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Lessons'),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            label: 'Quizzes',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _AdminUsersTab extends StatefulWidget {
  const _AdminUsersTab();
  @override
  State<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<_AdminUsersTab> {
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;

  String _formatTs(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final yyyy = d.year.toString();
      return '$mm-$dd-$yyyy';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: RoleService.instance.allUsersStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!;
            if (users.isEmpty) {
              return const Center(child: Text('No users found'));
            }

            if (!isWide) {
              // Small screens: keep ListTiles
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final u = users[index];
                  final email = (u['email'] ?? 'N/A') as String;
                  final role = (u['role'] ?? 'N/A') as String;
                  final uid = (u['uid'] ?? 'N/A') as String;
                  final username = (u['username'] ?? 'N/A') as String;
                  final status = (u['status'] ?? 'N/A') as String;
                  final subscription =
                      (u['subscription_status'] ?? 'N/A') as String;
                  final ts = u['createdAt'];
                  return ListTile(
                    leading: Icon(
                      role == 'ADMIN' ? Icons.verified_user : Icons.person,
                    ),
                    title: Text(username),
                    subtitle: Text(
                      'Email: $email\nUID: $uid\nStatus: $status | Sub: $subscription\nRole: $role\nCreated: ${_formatTs(ts)}',
                    ),
                    isThreeLine: true,
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final newRole = role == 'ADMIN'
                            ? UserRole.learner
                            : UserRole.admin;
                        await RoleService.instance.setUserRole(
                          uid: uid,
                          role: newRole,
                        );
                      },
                      child: Text(role == 'ADMIN' ? 'Demote' : 'Promote'),
                    ),
                  );
                },
              );
            }

            // Wide screens: PaginatedDataTable
            // Fix: Constrain width so PaginatedDataTable doesn't see "infinity"
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: PaginatedDataTable(
                  header: const Text('Users'),
                  rowsPerPage: _rowsPerPage,
                  onRowsPerPageChanged: (v) =>
                      setState(() => _rowsPerPage = v ?? _rowsPerPage),
                  columns: const [
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('UID')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Subscription')),
                    DataColumn(label: Text('Created At')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: _UsersDataSource(
                    context: context,
                    users: users,
                    onToggleRole: (uid, role) async {
                      final newRole = role == 'ADMIN'
                          ? UserRole.learner
                          : UserRole.admin;
                      await RoleService.instance.setUserRole(
                        uid: uid,
                        role: newRole,
                      );
                    },
                    formatTs: _formatTs,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminLessonsTab extends StatefulWidget {
  const _AdminLessonsTab();
  @override
  State<_AdminLessonsTab> createState() => _AdminLessonsTabState();
}

class _AdminLessonsTabState extends State<_AdminLessonsTab> {
  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da $hh:$mm';
  }

  String? _selectedLessonId;
  Lesson? _selectedLesson;
  final _deletingLessonIds = <String>{};
  bool _creatingLesson = false;
  final _title = TextEditingController();
  final _prompt = TextEditingController(); // Markdown content
  final _answer = TextEditingController(); // optional
  bool _preview = true;
  List<PlatformFile> _selectedFiles = []; // Store selected files

  Future<void> _openLessonEditor({Lesson? existing}) async {
    final result = await _lessonEditorDialog(context, existing: existing);
    if (result == null) return;
    try {
      if (existing == null) {
        await DatabaseService.instance.createLesson(
          title: result['title']!,
          prompt: result['prompt']!,
          answer: result['answer']!,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lesson created')));
        }
      } else {
        await DatabaseService.instance.updateLesson(
          id: existing.id,
          title: result['title'],
          prompt: result['prompt'],
          answer: result['answer'],
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lesson updated')));
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Operation failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Create area: consistent with Quizzes tab UX
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 900;
                    final editor = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Lessons',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed:
                                  (_creatingLesson ||
                                      (_selectedLessonId != null &&
                                          _selectedLesson != null &&
                                          _title.text.trim() ==
                                              _selectedLesson!.title &&
                                          _prompt.text.trim() ==
                                              _selectedLesson!.prompt &&
                                          _answer.text.trim() ==
                                              _selectedLesson!.answer) ||
                                      _title.text.trim().isEmpty ||
                                      _prompt.text.trim().isEmpty)
                                  ? null
                                  : () async {
                                      setState(() => _creatingLesson = true);
                                      try {
                                        if (_title.text.trim().isEmpty) return;

                                        String? attachmentUrl;
                                        String? attachmentName;

                                        // Upload file if selected
                                        if (_selectedFiles.isNotEmpty) {
                                          // Validate size (2MB) - doing it here or relying on file picker (not supported directly in file picker)
                                          final file = _selectedFiles.first;
                                          if (file.size > 2 * 1024 * 1024) {
                                            throw Exception(
                                              'File size must be less than 2MB',
                                            );
                                          }
                                          if (file.bytes != null) {
                                            attachmentUrl =
                                                await DatabaseService.instance
                                                    .uploadDocument(
                                                      fileBytes: file.bytes!,
                                                      fileName: file.name,
                                                      folder: 'lessons',
                                                    );
                                            attachmentName = file.name;
                                          }
                                        } else if (_selectedLesson != null) {
                                          // Keep existing if not changing
                                          attachmentUrl =
                                              _selectedLesson!.attachmentUrl;
                                          attachmentName =
                                              _selectedLesson!.attachmentName;
                                        }

                                        if (_selectedLessonId == null) {
                                          await DatabaseService.instance
                                              .createLesson(
                                                title: _title.text.trim(),
                                                prompt: _prompt.text.trim(),
                                                answer: _answer.text.trim(),
                                                attachmentUrl: attachmentUrl,
                                                attachmentName: attachmentName,
                                              );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Lesson created'),
                                              ),
                                            );
                                          }
                                        } else {
                                          await DatabaseService.instance
                                              .updateLesson(
                                                id: _selectedLessonId!,
                                                title: _title.text.trim(),
                                                prompt: _prompt.text.trim(),
                                                answer: _answer.text.trim(),
                                                attachmentUrl: attachmentUrl,
                                                attachmentName: attachmentName,
                                              );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Lesson updated'),
                                              ),
                                            );
                                          }
                                        }

                                        // Reset fields
                                        _title.clear();
                                        _prompt.clear();
                                        _answer.clear();
                                        _selectedFiles = [];
                                        _selectedLessonId = null;
                                        _selectedLesson = null;
                                        setState(() {});
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Operation failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(
                                            () => _creatingLesson = false,
                                          );
                                        }
                                      }
                                    },
                              icon: _creatingLesson
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add),
                              label: const Text('Create/Edit Lesson'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Small screens: toggle; Large screens: split
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _title,
                                      decoration: const InputDecoration(
                                        labelText: 'Title',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _prompt,
                                      minLines: 6,
                                      maxLines: 10,
                                      decoration: const InputDecoration(
                                        labelText: 'Content (Markdown)',
                                        alignLabelWithHint: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _answer,
                                      decoration: const InputDecoration(
                                        labelText: 'Optional Answer',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildUploadUI(context),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: MarkdownBody(
                                        data: _prompt.text.isEmpty
                                            ? '_Nothing to preview_'
                                            : _prompt.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          Row(
                            children: [
                              FilterChip(
                                label: const Text('Edit'),
                                selected: !_preview,
                                onSelected: (_) =>
                                    setState(() => _preview = false),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Preview'),
                                selected: _preview,
                                onSelected: (_) =>
                                    setState(() => _preview = true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _preview
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildUploadUI(context),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: MarkdownBody(
                                        data: _prompt.text.isEmpty
                                            ? '_Nothing to preview_'
                                            : _prompt.text,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _title,
                                      decoration: const InputDecoration(
                                        labelText: 'Title',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _prompt,
                                      minLines: 6,
                                      maxLines: 10,
                                      decoration: const InputDecoration(
                                        labelText: 'Content (Markdown)',
                                        alignLabelWithHint: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _answer,
                                      decoration: const InputDecoration(
                                        labelText: 'Optional Answer',
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ],
                    );
                    return editor;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: AppRepository.instance.watchLessons(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final lessons = snapshot.data!;
              // map to lightweight objects for UI
              final lessonItems = lessons
                  .map(
                    (m) => ({
                      'id': m['id'] as String,
                      'title': (m['title'] ?? '').toString(),
                      'prompt': (m['prompt'] ?? '').toString(),
                      'answer': (m['answer'] ?? '').toString(),
                      'createdAt': m['createdAt'],
                      'createdByUid': m['createdByUid'],
                      'createdByEmail': m['createdByEmail'],
                      'attachmentUrl': (m['attachmentUrl'] ?? '').toString(),
                      'attachmentName': (m['attachmentName'] ?? '').toString(),
                    }),
                  )
                  .toList();
              if (lessons.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('No lessons yet')),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final lMap = lessonItems[index];
                  final l = Lesson(
                    id: lMap['id']!,
                    title: lMap['title']!,
                    prompt: lMap['prompt']!,
                    answer: lMap['answer']!,
                    attachmentUrl: lMap['attachmentUrl'],
                    attachmentName: lMap['attachmentName'],
                  );
                  return Column(
                    children: [
                      ListTile(
                        leading: Checkbox(
                          value: _selectedLessonId == l.id,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedLessonId = l.id;
                                _selectedLesson = l;
                                _title.text = l.title;
                                _prompt.text = l.prompt;
                                _answer.text = l.answer;
                                // Handle existing attachments if any (update UI to show them if needed)
                                // For now, we don't have a way to 'edit' the attachment easily in UI
                                // other than uploading a new one or clearing.
                                // We'll add that logic when we wire up the upload.
                              } else {
                                _selectedLessonId = null;
                                _selectedLesson = null;
                                _title.clear();
                                _prompt.clear();
                                _answer.clear();
                                _selectedFiles = [];
                              }
                            });
                          },
                        ),
                        title: Text(l.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (l.attachmentName != null &&
                                l.attachmentName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.attachment,
                                      size: 14,
                                      color: Colors.grey[600],
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
                              ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final ts = lMap['createdAt'];
                                final createdAtStr = ts is Timestamp
                                    ? _fmt(ts)
                                    : 'N/A';
                                return Row(
                                  children: [
                                    _AuthorName(
                                      uid: lMap['createdByUid'] as String?,
                                      fallbackEmail:
                                          lMap['createdByEmail'] as String?,
                                      small: true,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• Created: $createdAtStr',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Lesson'),
                                    content: Text(
                                      'Are you sure you want to delete "${l.title}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                try {
                                  await DatabaseService.instance.deleteLesson(
                                    l.id,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Lesson deleted'),
                                      ),
                                    );
                                    setState(() {});
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Delete failed: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }, childCount: lessons.length),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowMultiple: false, // Only allow 1 file
              allowedExtensions: ['pdf'],
              withData: true, // Needed for bytes
            );
            if (!context.mounted) return;
            if (result != null) {
              setState(() {
                _selectedFiles = result.files;
              });
              final names = result.files.map((f) => f.name).join(', ');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    names.isEmpty ? 'File selected' : 'Selected: $names',
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Document'),
        ),
        const SizedBox(height: 4),
        Text(
          'Supported: PDF. Selecting files does not upload them.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_selectedFiles.isEmpty &&
            _selectedLesson?.attachmentName != null &&
            _selectedLesson!.attachmentName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.attach_file, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Current: ${_selectedLesson!.attachmentName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // Display selected files
        if (_selectedFiles.isNotEmpty)
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                return _buildFileItem(file, index);
              },
            ),
          ),
      ],
    );
  }

  // Widget to display individual file item
  Widget _buildFileItem(PlatformFile file, int index) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 32),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    file.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedFiles.removeAt(index);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorName extends StatelessWidget {
  final String? uid;
  final String? fallbackEmail;
  final bool small;
  const _AuthorName({
    required this.uid,
    required this.fallbackEmail,
    this.small = false,
  });
  @override
  Widget build(BuildContext context) {
    final style = small ? Theme.of(context).textTheme.bodySmall : null;
    if (uid == null || uid!.isEmpty) {
      return Text('By: ${fallbackEmail ?? 'Unknown'}', style: style);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final username = (data?['username'] as String?)?.trim();
        final email = (data?['email'] as String?)?.trim() ?? fallbackEmail;
        final display = (username != null && username.isNotEmpty)
            ? username
            : (email ?? 'Unknown');
        return Text('By: $display', style: style);
      },
    );
  }
}

class _UsersDataSource extends DataTableSource {
  final List<Map<String, dynamic>> users;
  final Future<void> Function(String uid, String currentRole) onToggleRole;
  final String Function(dynamic ts) formatTs;
  final BuildContext context;
  _UsersDataSource({
    required this.context,
    required this.users,
    required this.onToggleRole,
    required this.formatTs,
  });
  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final u = users[index];
    final email = (u['email'] ?? 'N/A') as String;
    final role = (u['role'] ?? 'N/A') as String;
    final uid = (u['uid'] ?? 'N/A') as String;
    final username = (u['username'] ?? 'N/A') as String;
    final status = (u['status'] ?? 'N/A') as String;
    final subscription = (u['subscription_status'] ?? 'N/A') as String;
    final ts = u['createdAt'];
    final createdAt = formatTs(ts);
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Icon(role == 'ADMIN' ? Icons.verified_user : Icons.person),
              const SizedBox(width: 6),
              Text(username),
            ],
          ),
        ),
        DataCell(Text(email)),
        DataCell(Text(uid)),
        DataCell(Text(role)),
        DataCell(Text(status)),
        DataCell(Text(subscription)),
        DataCell(Text(createdAt)),
        DataCell(
          OutlinedButton(
            onPressed: () async {
              await onToggleRole(uid, role);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Role updated for $email')),
              );
            },
            child: Text(role == 'ADMIN' ? 'Demote' : 'Promote'),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => users.length;
  @override
  int get selectedRowCount => 0;
}

class _AdminQuizzesTab extends StatefulWidget {
  const _AdminQuizzesTab();
  @override
  State<_AdminQuizzesTab> createState() => _AdminQuizzesTabState();
}

class _AdminQuizzesTabState extends State<_AdminQuizzesTab> {
  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da $hh:$mm';
  }

  String? _selectedQuizId;
  bool _creatingOrUpdating = false;
  final _title = TextEditingController();
  final _question = TextEditingController();
  final _answer = TextEditingController();
  bool _preview = true;
  String _origTitle = '';
  String _origQuestion = '';
  String _origAnswer = '';
  int _origMaxAttempts = 1;

  final _maxAttemptsCtrl = TextEditingController(text: '1');
  List<PlatformFile> _selectedFiles = []; // Store selected files
  String? _currentAttachmentName;
  String? _currentAttachmentUrl;

  // Widget to show results
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
                      leading: Icon(
                        passed ? Icons.check_circle : Icons.cancel,
                        color: passed ? Colors.green : Colors.red,
                      ),
                      title: Text(r['username']),
                      subtitle: Text(
                        '${passed ? "Passed" : "Failed"} • Attempts: ${r['attemptsUsed']}',
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Quiz', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowMultiple: false, // Only allow 1 file
                    allowedExtensions: ['pdf'],
                  );
                  if (!context.mounted) return;
                  if (result != null) {
                    setState(() {
                      _selectedFiles = result.files;
                    });
                    final names = result.files.map((f) => f.name).join(', ');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          names.isEmpty ? 'File selected' : 'Selected: $names',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Document'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Supported: PDF. Selecting files does not upload them.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (_selectedFiles.isEmpty &&
              _currentAttachmentName != null &&
              _currentAttachmentName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Current: $_currentAttachmentName',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Display selected files in the quizzes tab
          if (_selectedFiles.isNotEmpty)
            Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  return _buildFileItem(file, index);
                },
              ),
            ),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final editor = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _question,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Question (Markdown)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _answer,
                    decoration: const InputDecoration(labelText: 'Answer'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _maxAttemptsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max Attempts',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              );
              final preview = Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownBody(
                  data: _question.text.isEmpty
                      ? '_Nothing to preview_'
                      : _question.text,
                ),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: editor),
                    const SizedBox(width: 16),
                    Expanded(child: preview),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Edit'),
                        selected: !_preview,
                        onSelected: (_) => setState(() => _preview = false),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Preview'),
                        selected: _preview,
                        onSelected: (_) => setState(() => _preview = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _preview ? preview : editor,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                (_creatingOrUpdating ||
                    _title.text.trim().isEmpty ||
                    _question.text.trim().isEmpty ||
                    _answer.text.trim().isEmpty ||
                    (_selectedQuizId != null &&
                        _title.text.trim() == _origTitle &&
                        _question.text.trim() == _origQuestion &&
                        _answer.text.trim() == _origAnswer &&
                        (int.tryParse(_maxAttemptsCtrl.text) ?? 1) ==
                            _origMaxAttempts))
                ? null
                : () async {
                    setState(() => _creatingOrUpdating = true);
                    try {
                      if (_title.text.trim().isEmpty) return;
                      // Create or Update

                      String? attachmentUrl;
                      String? attachmentName;

                      // Upload file if selected
                      if (_selectedFiles.isNotEmpty) {
                        final file = _selectedFiles.first;
                        if (file.size > 2 * 1024 * 1024) {
                          throw Exception('File size must be less than 2MB');
                        }
                        if (file.bytes != null) {
                          attachmentUrl = await DatabaseService.instance
                              .uploadDocument(
                                fileBytes: file.bytes!,
                                fileName: file.name,
                                folder: 'quizzes',
                              );
                          attachmentName = file.name;
                        }
                      } else if (_selectedQuizId != null) {
                        // Keep existing (null update for specific fields means no change in updateQuiz)
                        // If we wanted to remove it, we'd need explicit null handling in updateQuiz which we checked.
                      }

                      if (_selectedQuizId == null) {
                        await DatabaseService.instance.createQuiz(
                          title: _title.text.trim(),
                          question: _question.text.trim(),
                          answer: _answer.text.trim(),
                          maxAttempts: int.tryParse(_maxAttemptsCtrl.text) ?? 1,
                          attachmentUrl: attachmentUrl,
                          attachmentName: attachmentName,
                        );

                        _title.clear();
                        _question.clear();
                        _answer.clear();
                        _maxAttemptsCtrl.text = '1';
                        _selectedFiles = [];

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quiz created')),
                          );
                        }
                      } else {
                        await DatabaseService.instance.updateQuiz(
                          id: _selectedQuizId!,
                          title: _title.text.trim(),
                          question: _question.text.trim(),
                          answer: _answer.text.trim(),
                          maxAttempts: int.tryParse(_maxAttemptsCtrl.text),
                          attachmentUrl: attachmentUrl,
                          attachmentName: attachmentName,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quiz updated')),
                          );
                        }
                      }

                      // Reset fields
                      _title.clear();
                      _question.clear();
                      _answer.clear();
                      _maxAttemptsCtrl.text = '1';
                      _selectedFiles = [];
                      _selectedQuizId = null;
                      if (mounted) setState(() {});
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _creatingOrUpdating = false);
                    }
                  },
            child: _creatingOrUpdating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_selectedQuizId == null ? 'Add Quiz' : 'Update Quiz'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: AppRepository.instance.watchQuizzes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final itemsRaw = snapshot.data!;
                final items = itemsRaw
                    .map(
                      (m) => ({
                        'id': m['id'] as String,
                        'title': (m['title'] ?? '').toString(),
                        'question': (m['question'] ?? '').toString(),
                        'answer': (m['answer'] ?? '').toString(),
                        'maxAttempts': (m['maxAttempts'] is String)
                            ? (int.tryParse(m['maxAttempts'] as String) ?? 1)
                            : (m['maxAttempts'] as num?)?.toInt() ?? 1,
                        'createdAt': m['createdAt'],
                        'createdByUid': m['createdByUid'],
                        'createdByEmail': m['createdByEmail'],
                        'attachmentUrl': (m['attachmentUrl'] ?? '').toString(),
                        'attachmentName': (m['attachmentName'] ?? '')
                            .toString(),
                      }),
                    )
                    .toList();
                if (items.isEmpty) {
                  return const Center(child: Text('No quizzes yet'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final q = items[index];
                    final isSelected = _selectedQuizId == (q['id'] as String);
                    return ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedQuizId = (q['id'] as String);
                              _title.text = (q['title'] as String? ?? '');
                              _question.text = (q['question'] as String? ?? '');
                              _answer.text = (q['answer'] as String? ?? '');
                              _maxAttemptsCtrl.text =
                                  (q['maxAttempts'] as num?)
                                      ?.toInt()
                                      .toString() ??
                                  '1';

                              _currentAttachmentName =
                                  (q['attachmentName'] as String?);
                              _currentAttachmentUrl =
                                  (q['attachmentUrl'] as String?);

                              _origTitle = _title.text;
                              _origQuestion = _question.text;
                              _origAnswer = _answer.text;
                              _origMaxAttempts =
                                  int.tryParse(_maxAttemptsCtrl.text) ?? 1;
                            } else {
                              // Deselect
                              _selectedQuizId = null;
                              _title.clear();
                              _question.clear();
                              _answer.clear();
                              _maxAttemptsCtrl.text = '1';
                              _origTitle = '';
                              _origQuestion = '';
                              _origAnswer = '';
                              _origMaxAttempts = 1;
                              _selectedFiles = [];
                              _currentAttachmentName = null;
                              _currentAttachmentUrl = null;
                            }
                          });
                        },
                      ),
                      title: Text((q['title'] as String? ?? '')),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (q['question'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (q['attachmentName'] != null &&
                              (q['attachmentName'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.attachment,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    q['attachmentName'] as String,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final ts = q['createdAt'];
                              final createdAtStr = ts is Timestamp
                                  ? _fmt(ts)
                                  : 'N/A';
                              return Row(
                                children: [
                                  _AuthorName(
                                    uid: q['createdByUid'] as String?,
                                    fallbackEmail:
                                        q['createdByEmail'] as String?,
                                    small: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• Created: $createdAtStr • Max Attempts: ${q['maxAttempts']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.bar_chart),
                            tooltip: 'View Results',
                            onPressed: () => _showResults(
                              q['id'] as String,
                              (q['title'] ?? 'Quiz').toString(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Quiz'),
                                  content: Text(
                                    'Are you sure you want to delete "${(q['title'] ?? '').toString()}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              await DatabaseService.instance.deleteQuiz(
                                (q['id'] as String),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Quiz deleted')),
                                );
                              }
                              setState(() {
                                if (_selectedQuizId == (q['id'] as String)) {
                                  _selectedQuizId = null;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display individual file item (same as in Lessons tab)
  Widget _buildFileItem(PlatformFile file, int index) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 32),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    file.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedFiles.removeAt(index);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, String>?> _lessonEditorDialog(
  BuildContext context, {
  Lesson? existing,
}) async {
  final title = TextEditingController(text: existing?.title ?? '');
  final prompt = TextEditingController(text: existing?.prompt ?? '');
  final answer = TextEditingController(text: existing?.answer ?? '');
  bool preview = true;
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) {
        final wide = MediaQuery.of(context).size.width >= 900;
        final editor = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: prompt,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Content (Markdown)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setStateDialog(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: answer,
              decoration: const InputDecoration(labelText: 'Optional Answer'),
            ),
          ],
        );
        final previewPane = Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: MarkdownBody(
            data: prompt.text.isEmpty ? '_Nothing to preview_' : prompt.text,
          ),
        );
        return AlertDialog(
          title: Text(existing == null ? 'New Lesson' : 'Edit Lesson'),
          content: SizedBox(
            width: wide ? 900 : 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: editor),
                        const SizedBox(width: 16),
                        Expanded(child: previewPane),
                      ],
                    )
                  else ...[
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Edit'),
                          selected: !preview,
                          onSelected: (_) =>
                              setStateDialog(() => preview = false),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Preview'),
                          selected: preview,
                          onSelected: (_) =>
                              setStateDialog(() => preview = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    preview ? previewPane : editor,
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'title': title.text.trim(),
                  'prompt': prompt.text.trim(),
                  'answer': answer.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}
