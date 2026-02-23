import 'package:flutter/material.dart';
import '../../services/role_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
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
                      showCupertinoModalPopup(
                        context: context,
                        builder: (context) => CupertinoActionSheet(
                          title: const Text('Filter Users By'),
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
                            separatorBuilder: (_, __) =>
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
                                                        : (role == 'EDUCATOR'
                                                              ? Colors.blue
                                                              : Colors.grey))
                                                    .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            role == 'ADMIN'
                                                ? CupertinoIcons
                                                      .checkmark_shield_fill
                                                : (role == 'EDUCATOR'
                                                      ? CupertinoIcons.book_fill
                                                      : CupertinoIcons
                                                            .person_fill),
                                            color: role == 'ADMIN'
                                                ? AppColors.primaryGreen
                                                : (role == 'EDUCATOR'
                                                      ? Colors.blue
                                                      : AppColors.textPrimary),
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
                                                ? AppColors.primaryGreen
                                                      .withOpacity(0.2)
                                                : Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: role == 'ADMIN'
                                                  ? AppColors.primaryGreen
                                                        .withOpacity(0.5)
                                                  : Colors.grey.withOpacity(
                                                      0.3,
                                                    ),
                                            ),
                                          ),
                                          child: Text(
                                            role,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: role == 'ADMIN'
                                                  ? (Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.green[200]
                                                        : Colors.green[800])
                                                  : (Theme.of(
                                                              context,
                                                            ).brightness ==
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
                                              items: UserRole.values.where((r) => r != UserRole.superadmin).map((
                                                r,
                                              ) {
                                                final rStr = roleToString(r);
                                                return DropdownMenuItem<
                                                  UserRole
                                                >(
                                                  value: r,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        r == UserRole.admin
                                                            ? CupertinoIcons
                                                                  .checkmark_shield_fill
                                                            : (r ==
                                                                      UserRole
                                                                          .educator
                                                                  ? CupertinoIcons
                                                                        .book_fill
                                                                  : CupertinoIcons
                                                                        .person_fill),
                                                        size: 16,
                                                        color:
                                                            r == UserRole.admin
                                                            ? Colors.green
                                                            : (r ==
                                                                      UserRole
                                                                          .educator
                                                                  ? Colors.blue
                                                                  : Colors
                                                                        .grey),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        rStr,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
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
                                          icon: const Icon(
                                            CupertinoIcons.trash,
                                            color: Colors.red,
                                            size: 20,
                                          ),
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete $username\'s account? This will also delete all their lessons, quizzes, and files. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DatabaseService.instance.deleteUserAccount(uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account deleted successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting account: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
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
      width: targetWidth,
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.getTextColor(context).withValues(alpha: 0.1),
                ),
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
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: AppColors.getTextColor(context).withValues(alpha: 0.05),
              ),
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

                return Padding(
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
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
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
                        child: Text(createdAt, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildRoleDropdown(uid, email, role, context),
                      ),
                      SizedBox(
                        width: 80,
                        child: IconButton(
                          icon: const Icon(
                            CupertinoIcons.trash,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showDeleteConfirmation(uid, username),
                        ),
                      ),
                    ],
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
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.getTextColor(context).withValues(alpha: 0.6),
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRoleChip(String role, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: role == 'ADMIN'
            ? AppColors.primaryGreen.withValues(alpha: 0.2)
            : (role == 'EDUCATOR'
                  ? Colors.blue.withValues(alpha: 0.2)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade100)),
        borderRadius: BorderRadius.circular(8),
        border: role == 'ADMIN'
            ? Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5))
            : (role == 'EDUCATOR'
                  ? Border.all(color: Colors.blue.withValues(alpha: 0.5))
                  : null),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: role == 'ADMIN'
              ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.green[200]
                    : Colors.green[800])
              : (role == 'EDUCATOR'
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue[200]
                          : Colors.blue[800])
                    : AppColors.getTextColor(context)),
        ),
      ),
    );
  }

  Widget _buildStatusBubble(String status) {
    final isActive =
        status.toUpperCase() == 'ACTIVE' || status.toUpperCase() == 'COMPLETED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.red.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isActive ? Colors.green[700] : Colors.red[700],
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(
    String uid,
    String email,
    String currentRole,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          isExpanded: true,
          value: roleFromString(currentRole),
          dropdownColor: AppColors.getCardColor(context),
          icon: const Icon(CupertinoIcons.chevron_down, size: 16),
          items: UserRole.values.where((r) => r != UserRole.superadmin).map((
            r,
          ) {
            return DropdownMenuItem(
              value: r,
              child: Text(
                roleToString(r).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextColor(context),
                  fontWeight: FontWeight.w500,
                ),
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
      ),
    );
  }
}
