import 'package:flutter/material.dart';
import '../../services/role_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});
  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
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
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
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

                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    (role == 'ADMIN'
                                            ? AppColors.primaryGreen
                                            : Colors.grey)
                                        .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                role == 'ADMIN'
                                    ? CupertinoIcons.checkmark_shield_fill
                                    : CupertinoIcons.person_fill,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: role == 'ADMIN'
                                    ? AppColors.primaryGreen.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: role == 'ADMIN'
                                      ? AppColors.primaryGreen.withOpacity(0.5)
                                      : Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: role == 'ADMIN'
                                      ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.green[200]
                                            : Colors.green[800])
                                      : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black54),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Email: $email',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Text(
                          'UID: $uid',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Status: $status | Sub: $subscription',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'Created: ${_formatTs(ts)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: role == 'ADMIN'
                                  ? Colors.grey[400]
                                  : AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final newRole = role == 'ADMIN'
                                  ? UserRole.learner
                                  : UserRole.admin;
                              await RoleService.instance.setUserRole(
                                uid: uid,
                                role: newRole,
                              );
                            },
                            child: Text(
                              role == 'ADMIN'
                                  ? 'Demote to Learner'
                                  : 'Promote to Admin',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            // Wide screens: PaginatedDataTable inside GlassCard
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - 32,
                ),
                child: GlassCard(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: Colors.transparent,
                      dividerColor: Colors.grey.withOpacity(0.2),
                      dataTableTheme: DataTableThemeData(
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                    child: PaginatedDataTable(
                      header: const Text('Users Management'),
                      rowsPerPage: _rowsPerPage,
                      onRowsPerPageChanged: (v) =>
                          setState(() => _rowsPerPage = v ?? _rowsPerPage),
                      headingRowHeight: 56,
                      columnSpacing: 24,
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
                ),
              ),
            );
          },
        );
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
              Icon(
                role == 'ADMIN'
                    ? CupertinoIcons.checkmark_shield_fill
                    : CupertinoIcons.person_fill,
                color: role == 'ADMIN' ? AppColors.primaryGreen : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(username),
            ],
          ),
        ),
        DataCell(Text(email)),
        DataCell(Text(uid)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: role == 'ADMIN'
                  ? AppColors.primaryGreen.withOpacity(0.2)
                  : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: role == 'ADMIN'
                  ? Border.all(color: AppColors.primaryGreen.withOpacity(0.5))
                  : null,
            ),
            child: Text(
              role,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: role == 'ADMIN'
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.green[200]
                          : Colors.green[800])
                    : null,
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  status.toUpperCase() == 'ACTIVE' ||
                      status.toUpperCase() == 'COMPLETED'
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    status.toUpperCase() == 'ACTIVE' ||
                        status.toUpperCase() == 'COMPLETED'
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
              ),
            ),
            child: Text(
              status,
              style: TextStyle(
                color:
                    status.toUpperCase() == 'ACTIVE' ||
                        status.toUpperCase() == 'COMPLETED'
                    ? Colors.green[800]
                    : Colors.red[800],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(Text(subscription)),
        DataCell(Text(createdAt)),
        DataCell(
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              await onToggleRole(uid, role);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Role updated for $email')),
                );
              }
            },
            child: Text(
              role == 'ADMIN' ? 'Demote' : 'Promote',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
