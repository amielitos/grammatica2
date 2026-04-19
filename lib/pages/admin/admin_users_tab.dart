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
            var allUsers = snapshot.data!;
            var users = List<Map<String, dynamic>>.from(allUsers);

            // Calculate Counts
            final adminCount = allUsers
                .where((u) => u['role'] == 'ADMIN')
                .length;
            final validatorCount = allUsers
                .where((u) => u['role'] == 'VALIDATOR')
                .length;
            final educatorCount = allUsers
                .where((u) => u['role'] == 'EDUCATOR')
                .length;
            final learnerCount = allUsers
                .where((u) => u['role'] == 'LEARNER')
                .length;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              users = users.where((u) {
                final username = (u['username'] ?? '').toString().toLowerCase();
                final email = (u['email'] ?? '').toString().toLowerCase();
                return username.contains(query) || email.contains(query);
              }).toList();
            }

            // Apply sorting
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
                if (tsA == null && tsB == null)
                  cmp = 0;
                else if (tsA == null)
                  cmp = 1;
                else if (tsB == null)
                  cmp = -1;
                else
                  cmp = tsB.compareTo(tsA);
              }
              if (cmp == 0) {
                return (a['username'] ?? '').toString().toLowerCase().compareTo(
                  (b['username'] ?? '').toString().toLowerCase(),
                );
              }
              return cmp;
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // 1. Stats Row
                  Row(
                    children: [
                      _buildStatCard('ADMIN', adminCount),
                      const SizedBox(width: 16),
                      _buildStatCard('VALIDATORS', validatorCount),
                      const SizedBox(width: 16),
                      _buildStatCard('EDUCATORS', educatorCount),
                      const SizedBox(width: 16),
                      _buildStatCard('LEARNERS', learnerCount),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Search & Filter
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: _showFilterDialog,
                        ),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: const InputDecoration(
                              hintText: 'Search users by name or email..',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.black26),
                            ),
                          ),
                        ),
                        const Icon(Icons.search_rounded, color: Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. User Table Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              _tableH('Username', 3),
                              _tableH('Email', 4),
                              _tableH('Role', 2),
                              _tableH('Status', 2),
                              _tableH('Subscription', 2),
                              _tableH('Created At', 2),
                              _tableH('Role Action', 3),
                              _tableH('Action', 2, center: true),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        // List
                        if (users.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(48.0),
                            child: Text(
                              'No users found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: users.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFEEEEEE),
                              indent: 24,
                              endIndent: 24,
                            ),
                            itemBuilder: (context, index) {
                              final u = users[index];
                              return _buildUserRow(u);
                            },
                          ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildStatCard(String label, int count) {
    return Expanded(
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Filter Users By',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                  setState(() => _selectedFilter = option);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _tableH(String label, int flex, {bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> u) {
    final email = (u['email'] ?? 'N/A') as String;
    final role = (u['role'] ?? 'N/A') as String;
    final uid = (u['uid'] ?? 'N/A') as String;
    final username = (u['username'] ?? 'N/A') as String;
    final status = (u['status'] ?? 'N/A') as String;
    final subscription = (u['subscription_status'] ?? 'NONE') as String;
    final createdAt = _formatTs(u['createdAt']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Username + Image
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE0E0E0),
                  backgroundImage: u['photoUrl'] != null
                      ? NetworkImage(u['photoUrl'])
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    username,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Email
          Expanded(
            flex: 4,
            child: Text(
              email,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Role
          Expanded(
            flex: 2,
            child: Text(
              role,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          // Sub
          Expanded(
            flex: 2,
            child: Text(
              subscription.toUpperCase(),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          // Created At
          Expanded(
            flex: 2,
            child: Text(
              createdAt,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          // Role Action
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<UserRole>(
                  isExpanded: true,
                  value: roleFromString(role),
                  icon: const Icon(Icons.expand_more, size: 16),
                  items: UserRole.values
                      .where((r) => r != UserRole.superadmin)
                      .map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(
                            roleToString(r).toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      })
                      .toList(),
                  onChanged: (newRole) async {
                    if (newRole != null && roleToString(newRole) != role) {
                      await RoleService.instance.setUserRole(
                        uid: uid,
                        role: newRole,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          // Status Action
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton(
                onPressed: () =>
                    _showStatusToggleConfirmation(uid, username, status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: status.toLowerCase() == 'active'
                      ? Colors.orange.shade400
                      : Colors.green.shade400,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                child: Text(
                  status.toLowerCase() == 'active' ? 'DEACTIVATE' : 'ACTIVATE',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusToggleConfirmation(
    String uid,
    String username,
    String currentStatus,
  ) {
    final isDeactivating = currentStatus.toLowerCase() == 'active';
    final newStatus = isDeactivating ? 'DEACTIVATED' : 'ACTIVE';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isDeactivating ? 'Deactivate' : 'Activate'} Account'),
        content: Text(
          'Are you sure you want to ${isDeactivating ? 'deactivate' : 'activate'} $username\'s account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseService.instance.updateUserField(
                uid,
                'status',
                newStatus,
              );
            },
            child: Text(
              isDeactivating ? 'Deactivate' : 'Activate',
              style: TextStyle(
                color: isDeactivating ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
