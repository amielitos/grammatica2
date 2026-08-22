import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/role_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/database_service.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});
  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  String _searchQuery = '';
  String _selectedFilter = 'Create Date';

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
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: RoleService.instance.allUsersStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var allUsers = snapshot.data!;
            var users = List<Map<String, dynamic>>.from(allUsers);

            // Calculate Counts
            final adminCount = allUsers.where((u) => u['role'] == 'ADMIN').length;
            final validatorCount = allUsers.where((u) => u['role'] == 'VALIDATOR').length;
            final educatorCount = allUsers.where((u) => u['role'] == 'EDUCATOR').length;
            final learnerCount = allUsers.where((u) => u['role'] == 'LEARNER').length;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              users = users.where((u) {
                final username = (u['username'] ?? '').toString().toLowerCase();
                final email = (u['email'] ?? '').toString().toLowerCase();
                return username.contains(query) || email.contains(query);
              }).toList();
            }

            // Sorting
            users.sort((a, b) {
              int cmp = 0;
              if (_selectedFilter == 'Name') {
                cmp = (a['username'] ?? '').toString().toLowerCase().compareTo(
                  (b['username'] ?? '').toString().toLowerCase(),
                );
              } else if (_selectedFilter == 'Role') {
                cmp = (a['role'] ?? '').toString().compareTo((b['role'] ?? '').toString());
              } else if (_selectedFilter == 'Status') {
                cmp = (a['status'] ?? '').toString().compareTo((b['status'] ?? '').toString());
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
                  cmp = tsB.compareTo(tsA);
                }
              }
              if (cmp == 0) {
                return (a['username'] ?? '').toString().toLowerCase().compareTo(
                  (b['username'] ?? '').toString().toLowerCase(),
                );
              }
              return cmp;
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section Header ───────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81B655).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people_rounded,
                            color: Color(0xFF81B655), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Management',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Manage roles and account status for all users',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Stat Cards ───────────────────────────────────────
                  Row(
                    children: [
                      _buildStatCard(
                        label: 'Admins',
                        count: adminCount,
                        icon: Icons.shield_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        label: 'Validators',
                        count: validatorCount,
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        label: 'Educators',
                        count: educatorCount,
                        icon: Icons.school_rounded,
                        color: const Color(0xFF81B655),
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        label: 'Learners',
                        count: learnerCount,
                        icon: Icons.person_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Search & Filter Bar ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: Color(0xFF81B655), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search users by name or email…',
                                    hintStyle: GoogleFonts.inter(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filter Button
                      MaterialButton(
                        onPressed: _showFilterDialog,
                        color: Colors.white,
                        elevation: 0,
                        height: 52,
                        minWidth: 52,
                        padding: const EdgeInsets.all(0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.tune_rounded, color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Active filter label
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Sorted by: $_selectedFilter',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Table ────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              _tableH('Username', 3),
                              _tableH('Email', 4),
                              _tableH('Role', 2),
                              _tableH('Status', 2),
                              _tableH('Subscription', 2),
                              _tableH('Educ. Dates', 3),
                              _tableH('Change Role', 2),
                              _tableH('Action', 2, center: true),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Table Rows
                        if (users.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(Icons.person_search_rounded,
                                    size: 40, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'No users found',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: users.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Color(0xFFF1F5F9),
                              indent: 24,
                              endIndent: 24,
                            ),
                            itemBuilder: (context, index) =>
                                _buildUserRow(users[index]),
                          ),
                        const SizedBox(height: 8),
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

  Widget _buildStatCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 14),
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Sort Users By',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            ..._filterOptions.map((option) {
              final isSelected = _selectedFilter == option;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF81B655).withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected ? const Color(0xFF81B655) : Colors.grey,
                    size: 18,
                  ),
                ),
                title: Text(
                  option,
                  style: GoogleFonts.outfit(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF81B655) : Colors.black87,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedFilter = option);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
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
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Colors.grey.shade500,
          letterSpacing: 0.4,
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

    final educStart = u['educatorStartDate'] != null ? _formatTs(u['educatorStartDate']) : 'N/A';
    final educEnd = u['educatorEndDate'] != null ? _formatTs(u['educatorEndDate']) : 'Present';
    final educDates = role == 'EDUCATOR' ? '$educStart\n$educEnd' : '—';

    final isActive = status.toLowerCase() == 'active';
    final roleColor = _roleColor(role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          // ── Username + Avatar ─────────────────────────────────────
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  backgroundImage: u['photoUrl'] != null
                      ? NetworkImage(u['photoUrl'] as String)
                      : null,
                  child: u['photoUrl'] == null
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    username,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Email ─────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Text(
              email,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Role Badge ────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: roleColor,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // ── Status Chip ───────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF81B655) : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isActive ? const Color(0xFF81B655) : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Subscription ──────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Text(
              subscription.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),

          // ── Educ Dates ────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Text(
              educDates,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, height: 1.5),
            ),
          ),

          // ── Role Dropdown ─────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<UserRole>(
                  isExpanded: true,
                  value: roleFromString(role),
                  icon: const Icon(Icons.expand_more, size: 16, color: Colors.grey),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  items: UserRole.values
                      .where((r) => r != UserRole.superadmin)
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              roleToString(r).toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (newRole) async {
                    if (newRole != null && roleToString(newRole) != role) {
                      await RoleService.instance.setUserRole(uid: uid, role: newRole);
                    }
                  },
                ),
              ),
            ),
          ),

          // ── Status Toggle Button ──────────────────────────────────
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () => _showStatusToggleConfirmation(uid, username, status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive
                      ? Colors.orange.shade50
                      : const Color(0xFF81B655).withValues(alpha: 0.10),
                  foregroundColor: isActive ? Colors.orange.shade700 : const Color(0xFF81B655),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(
                    color: isActive ? Colors.orange.shade200 : const Color(0xFF81B655).withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                child: Text(isActive ? 'DEACTIVATE' : 'ACTIVATE'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return const Color(0xFF8B5CF6);
      case 'VALIDATOR':
        return const Color(0xFF3B82F6);
      case 'EDUCATOR':
        return const Color(0xFF81B655);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  void _showStatusToggleConfirmation(
      String uid, String username, String currentStatus) {
    final isDeactivating = currentStatus.toLowerCase() == 'active';
    final newStatus = isDeactivating ? 'DEACTIVATED' : 'ACTIVE';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDeactivating
                          ? Colors.orange.withValues(alpha: 0.10)
                          : const Color(0xFF81B655).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDeactivating ? Icons.block_rounded : Icons.check_circle_rounded,
                      color: isDeactivating ? Colors.orange : const Color(0xFF81B655),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${isDeactivating ? 'Deactivate' : 'Activate'} Account',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to ${isDeactivating ? 'deactivate' : 'activate'} $username\'s account?',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await DatabaseService.instance
                            .updateUserField(uid, 'status', newStatus);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDeactivating
                            ? Colors.orange
                            : const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        isDeactivating ? 'Deactivate' : 'Activate',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
