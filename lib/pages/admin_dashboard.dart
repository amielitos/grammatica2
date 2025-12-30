import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';
import '../services/database_service.dart';
import 'profile_page.dart';

class AdminDashboard extends StatefulWidget {
  final User user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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
      body: IndexedStack(
        index: _index,
        children: [
          _AdminUsersTab(),
          const _AdminLessonsTab(),
          ProfilePage(user: widget.user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Lessons'),
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
  final _titleCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Lesson', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
              ),
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _promptCtrl,
                  decoration: const InputDecoration(labelText: 'Prompt'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _answerCtrl,
                  decoration: const InputDecoration(labelText: 'Answer'),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  if (_titleCtrl.text.trim().isEmpty) return;
                  await DatabaseService.instance.createLesson(
                    title: _titleCtrl.text.trim(),
                    prompt: _promptCtrl.text.trim(),
                    answer: _answerCtrl.text.trim(),
                  );
                  _titleCtrl.clear();
                  _promptCtrl.clear();
                  _answerCtrl.clear();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lesson created')),
                    );
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Lesson>>(
              future: DatabaseService.instance.fetchLessons(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final lessons = snapshot.data!;
                if (lessons.isEmpty)
                  return const Center(child: Text('No lessons yet'));
                return ListView.separated(
                  itemCount: lessons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final l = lessons[index];
                    return ListTile(
                      title: Text(l.title),
                      subtitle: Text(
                        l.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final newTitle = await _editTextDialog(
                                context,
                                title: 'Edit Title',
                                initial: l.title,
                              );
                              if (newTitle != null &&
                                  newTitle.trim().isNotEmpty) {
                                await DatabaseService.instance.updateLesson(
                                  id: l.id,
                                  title: newTitle.trim(),
                                );
                                setState(() {});
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await DatabaseService.instance.deleteLesson(l.id);
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Lesson deleted'),
                                  ),
                                );
                              setState(() {});
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
