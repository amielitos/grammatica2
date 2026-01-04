import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/role_service.dart';
import '../services/database_service.dart';
import '../services/app_repository.dart';
import 'profile_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AdminDashboard extends StatefulWidget {
  final User user;
  const AdminDashboard({super.key, required this.user});

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
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.uid)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final username = (data?['username'] ?? widget.user.email ?? 'Admin')
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
              ProfilePage(user: widget.user),
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
                  final createdAt = ts is Timestamp
                      ? ts.toDate().toIso8601String()
                      : 'N/A';
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
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                                  await DatabaseService.instance.createLesson(
                                    title: _title.text.trim(),
                                    prompt: _prompt.text.trim(),
                                    answer: _answer.text.trim(),
                                  );
                                  _title.clear();
                                  _prompt.clear();
                                  _answer.clear();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Lesson created'),
                                      ),
                                    );
                                    setState(() {});
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Create failed: $e'),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _creatingLesson = false);
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
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.custom,
                                        allowMultiple: true,
                                        allowedExtensions: [
                                          'jpg',
                                          'jpeg',
                                          'png',
                                          'pdf',
                                        ],
                                      );
                                  if (!context.mounted) return;
                                  if (result != null) {
                                    final names = result.files
                                        .map((f) => f.name)
                                        .join(', ');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          names.isEmpty
                                              ? 'Files selected'
                                              : 'Selected: $names',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Upload Documents'),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
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
                    _preview
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await FilePicker.platform
                                      .pickFiles(
                                        type: FileType.custom,
                                        allowMultiple: true,
                                        allowedExtensions: [
                                          'jpg',
                                          'jpeg',
                                          'png',
                                          'pdf',
                                        ],
                                      );
                                  if (!context.mounted) return;
                                  if (result != null) {
                                    final names = result.files
                                        .map((f) => f.name)
                                        .join(', ');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          names.isEmpty
                                              ? 'Files selected'
                                              : 'Selected: $names',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Upload Documents'),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Supported: JPG, PNG, PDF. Selecting files does not upload them.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
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
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: AppRepository.instance.watchLessons(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
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
                      }),
                    )
                    .toList();
                if (lessons.isEmpty) {
                  return const Center(child: Text('No lessons yet'));
                }
                return ListView.separated(
                  itemCount: lessons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final lMap = lessonItems[index];
                    final l = Lesson(
                      id: lMap['id']!,
                      title: lMap['title']!,
                      prompt: lMap['prompt']!,
                      answer: lMap['answer']!,
                    );
                    return ListTile(
                      leading: Radio<String>(
                        value: l.id,
                        groupValue: _selectedLessonId,
                        onChanged: (val) {
                          setState(() {
                            _selectedLessonId = val;
                            _selectedLesson = l;
                            _title.text = l.title;
                            _prompt.text = l.prompt;
                            _answer.text = l.answer;
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
        final display = (username != null && username.isNotEmpty)
            ? username
            : (fallbackEmail ?? 'Unknown');
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
                    allowMultiple: true,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                  );
                  if (!context.mounted) return;
                  if (result != null) {
                    final names = result.files.map((f) => f.name).join(', ');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          names.isEmpty ? 'Files selected' : 'Selected: $names',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Documents'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Supported: JPG, PNG, PDF. Selecting files does not upload them.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                        _answer.text.trim() == _origAnswer))
                ? null
                : () async {
                    setState(() => _creatingOrUpdating = true);
                    try {
                      if (_title.text.trim().isEmpty) return;
                      if (_selectedQuizId == null) {
                        await DatabaseService.instance.createQuiz(
                          title: _title.text.trim(),
                          question: _question.text.trim(),
                          answer: _answer.text.trim(),
                        );
                        _title.clear();
                        _question.clear();
                        _answer.clear();
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
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quiz updated')),
                          );
                        }
                      }
                      if (mounted) setState(() {});
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
                        'createdAt': m['createdAt'],
                        'createdByUid': m['createdByUid'],
                        'createdByEmail': m['createdByEmail'],
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
                    return ListTile(
                      leading: Radio<String>(
                        value: (q['id'] as String),
                        groupValue: _selectedQuizId,
                        onChanged: (val) {
                          setState(() {
                            _selectedQuizId = val;
                            _title.text = (q['title'] ?? '').toString();
                            _question.text = (q['question'] ?? '').toString();
                            _answer.text = (q['answer'] ?? '').toString();
                            _origTitle = (q['title'] ?? '').toString();
                            _origQuestion = (q['question'] ?? '').toString();
                            _origAnswer = (q['answer'] ?? '').toString();
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
                      trailing: IconButton(
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
                                  onPressed: () => Navigator.pop(context, true),
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
}

Future<String?> _editTextDialog(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
