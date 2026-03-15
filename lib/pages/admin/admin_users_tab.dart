import 'package:flutter/material.dart';
import '../../services/role_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_search_bar.dart';
import '../../services/database_service.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});
  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  String _searchQuery = '';
  String _selectedFilter = 'Create Date'; // Default

  final List<String> _filterOptions = ['Name', 'Role', 'Status', 'Create Date'];

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
            var users = snapshot.data!;
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              users = users.where((u) {
                final username = (u['username'] ?? '').toString().toLowerCase();
                final email = (u['email'] ?? '').toString().toLowerCase();
                return username.contains(query) || email.contains(query);
              }).toList();
            }

            // Apply sorting based on filter
            users.sort((a, b) {
              int cmp = 0;
              if (_selectedFilter == 'Name') {
                cmp = (a['username'] ?? '').toString().toLowerCase().compareTo(
                  (b['username'] ?? '').toString().toLowerCase(),
                );
              } else if (_selectedFilter == 'Role') {
                cmp = (a['role'] ?? '').toString().compareTo(
                  (b['role'] ?? '').toString(),
                );
              } else if (_selectedFilter == 'Status') {
                cmp = (a['status'] ?? '').toString().compareTo(
                  (b['status'] ?? '').toString(),
                );
              } else if (_selectedFilter == 'Create Date') {
                final tsA = a['createdAt'] as Timestamp?;
                final tsB = b['createdAt'] as Timestamp?;
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
                return (a['username'] ?? '').toString().toLowerCase().compareTo(
                  (b['username'] ?? '').toString().toLowerCase(),
                );
              }
              return cmp;
            });

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  AppSearchBar(
                    hintText: 'Search users by name or email...',
                    onSearch: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    onFilterPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Filter Users By',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              ..._filterOptions.map((option) {
                                return ListTile(
                                  leading: Icon(
                                    _selectedFilter == option
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                  ),
                                  title: Text(option),
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = option;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (users.isEmpty) {
                          return const Center(child: Text('No users found'));
                        }

                        if (!isWide) {
                          return ListView.separated(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: users.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final u = users[index];
                              final email = (u['email'] ?? 'N/A') as String;
                              final role = (u['role'] ?? 'N/A') as String;
                              final uid = (u['uid'] ?? 'N/A') as String;
                              final username =
                                  (u['username'] ?? 'N/A') as String;
                              final status = (u['status'] ?? 'N/A') as String;
                              final subscription =
                                  (u['subscription_status'] ?? 'N/A') as String;
                              final ts = u['createdAt'];

                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: u['photoUrl'] != null
                                              ? NetworkImage(u['photoUrl'])
                                              : null,
                                          child: u['photoUrl'] == null
                                              ? Icon(
                                                  role == 'ADMIN'
                                                      ? Icons
                                                            .admin_panel_settings
                                                      : (role == 'EDUCATOR'
                                                            ? Icons.school
                                                            : Icons.person),
                                                )
                                              : null,
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(),
                                          ),
                                          child: Text(
                                            role,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
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
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                    Row(
                                      children: [
                                        const Text(
                                          'Change Role:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<UserRole>(
                                              value: roleFromString(role),
                                              isExpanded: true,
                                              items: UserRole.values
                                                  .where(
                                                    (r) =>
                                                        r !=
                                                        UserRole.superadmin,
                                                  )
                                                  .map((r) {
                                                    final rStr = roleToString(
                                                      r,
                                                    );
                                                    return DropdownMenuItem<
                                                      UserRole
                                                    >(
                                                      value: r,
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            r == UserRole.admin
                                                                ? Icons
                                                                      .admin_panel_settings
                                                                : (r ==
                                                                          UserRole
                                                                              .educator
                                                                      ? Icons
                                                                            .school
                                                                      : Icons
                                                                            .person),
                                                            size: 16,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            rStr,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  })
                                                  .toList(),
                                              onChanged: (newRole) async {
                                                if (newRole != null &&
                                                    roleToString(newRole) !=
                                                        role) {
                                                  await RoleService.instance
                                                      .setUserRole(
                                                        uid: uid,
                                                        role: newRole,
                                                      );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Role updated to ${roleToString(newRole)}',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              _showDeleteConfirmation(
                                                uid,
                                                username,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        // Wide screens: Custom Flex Table
                        return _buildTable(
                          context,
                          users,
                          constraints.maxWidth - 32,
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

  void _showDeleteConfirmation(String uid, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete $username\'s account? This will also delete all their lessons, quizzes, and files. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DatabaseService.instance.deleteUserAccount(uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account deleted successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting account: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<Map<String, dynamic>> users,
    double targetWidth,
  ) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildHeaderCell('Username', context)),
                Expanded(flex: 4, child: _buildHeaderCell('Email', context)),
                Expanded(flex: 2, child: _buildHeaderCell('Role', context)),
                Expanded(flex: 2, child: _buildHeaderCell('Status', context)),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Subscription', context),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('Created At', context),
                ),
                Expanded(
                  flex: 3,
                  child: _buildHeaderCell('Role Action', context),
                ),
                SizedBox(
                  width: 80,
                  child: _buildHeaderCell(
                    'Delete',
                    context,
                    alignment: Alignment.center,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              itemBuilder: (context, index) {
                final u = users[index];
                final email = (u['email'] ?? 'N/A') as String;
                final role = (u['role'] ?? 'N/A') as String;
                final uid = (u['uid'] ?? 'N/A') as String;
                final username = (u['username'] ?? 'N/A') as String;
                final status = (u['status'] ?? 'N/A') as String;
                final subscription =
                    (u['subscription_status'] ?? 'N/A') as String;
                final createdAt = _formatTs(u['createdAt']);

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: u['photoUrl'] != null
                                    ? NetworkImage(u['photoUrl'])
                                    : null,
                                child: u['photoUrl'] == null
                                    ? const Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  username,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(email, overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildRoleChip(role, context),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildStatusBubble(status),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            subscription,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            createdAt,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _buildRoleDropdown(uid, email, role, context),
                        ),
                        SizedBox(
                          width: 80,
                          child: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                _showDeleteConfirmation(uid, username),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String title,
    BuildContext context, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Align(
      alignment: alignment,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRoleChip(String role, BuildContext context) {
    return Text(
      role.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  Widget _buildStatusBubble(String status) {
    return Text(
      status.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRoleDropdown(
    String uid,
    String email,
    String currentRole,
    BuildContext context,
  ) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<UserRole>(
        isExpanded: true,
        value: roleFromString(currentRole),
        icon: const Icon(Icons.expand_more, size: 16),
        items: UserRole.values.where((r) => r != UserRole.superadmin).map((r) {
          return DropdownMenuItem(
            value: r,
            child: Text(
              roleToString(r).toUpperCase(),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (newRole) async {
          if (newRole != null && roleToString(newRole) != currentRole) {
            await RoleService.instance.setUserRole(uid: uid, role: newRole);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Role updated to ${roleToString(newRole)} for $email',
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
