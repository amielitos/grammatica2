import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/role_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/email_sender_service.dart';
import '../../services/email_validator_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification.dart';
import '../../widgets/application_preview_widgets.dart';
import '../../widgets/content_denial_dialog.dart';
import '../../services/badge_service.dart';
import '../../models/badge_model.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AdminUsersTab extends StatefulWidget {
  final UserRole role;
  final User? currentUser;

  const AdminUsersTab({
    super.key,
    this.role = UserRole.admin,
    this.currentUser,
  });

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  String _searchQuery = '';
  String _selectedFilter = 'Create Date';
  String _selectedRoleFilter = 'ALL';
  int _currentPage = 1;
  static const int _pageSize = 10;

  final List<String> _filterOptions = ['Name', 'Role', 'Status', 'Create Date'];

  bool _isPendingValidator(Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString().toUpperCase();
    if (role != 'VALIDATOR') return false;
    final isVerified = u['isVerified'] == true;
    final status = (u['status'] ?? '').toString().toLowerCase();
    return !isVerified || status.contains('in review') || status == 'pending';
  }

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
            final adminCount = allUsers.where((u) => (u['role'] ?? '').toString().toUpperCase() == 'ADMIN').length;
            final validatorCount = allUsers.where((u) => (u['role'] ?? '').toString().toUpperCase() == 'VALIDATOR').length;
            final educatorCount = allUsers.where((u) => (u['role'] ?? '').toString().toUpperCase() == 'EDUCATOR').length;
            final learnerCount = allUsers.where((u) => (u['role'] ?? '').toString().toUpperCase() == 'LEARNER').length;

            // Filter by role if selected
            if (_selectedRoleFilter != 'ALL') {
              users = users.where((u) => (u['role'] ?? '').toString().toUpperCase() == _selectedRoleFilter).toList();
            }

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

            final totalUsers = users.length;
            final totalPages = (totalUsers / _pageSize).ceil();
            if (_currentPage > totalPages && totalPages > 0) {
              _currentPage = totalPages;
            }
            if (_currentPage < 1) {
              _currentPage = 1;
            }
            final startIndex = totalUsers == 0 ? 0 : (_currentPage - 1) * _pageSize;
            final endIndex = (startIndex + _pageSize > totalUsers) ? totalUsers : (startIndex + _pageSize);
            final paginatedUsers = users.skip(startIndex).take(_pageSize).toList();

            final isMobile = constraints.maxWidth < 600;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Management',
                              style: GoogleFonts.outfit(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Manage roles and account status for all users',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.role == UserRole.superadmin || widget.role == UserRole.admin) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await BadgeService.instance.seedBadgesIfEmpty(force: true);
                            if (context.mounted) {
                              _showSeedBadgesListDialog();
                            }
                          },
                          icon: const Icon(Icons.military_tech_rounded, size: 18),
                          label: Text(
                            'Seed Badges',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                      if (widget.role == UserRole.superadmin) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showAddAdminDialog,
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: Text(
                            'Add Admin',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Stat Cards ─────────────────────────────────────────
                  if (isMobile)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        _buildStatCard(label: 'Admins', count: adminCount, icon: Icons.shield_rounded, color: const Color(0xFF8B5CF6), roleKey: 'ADMIN', expanded: false),
                        _buildStatCard(label: 'Validators', count: validatorCount, icon: Icons.verified_rounded, color: const Color(0xFF3B82F6), roleKey: 'VALIDATOR', expanded: false),
                        _buildStatCard(label: 'Educators', count: educatorCount, icon: Icons.school_rounded, color: const Color(0xFF81B655), roleKey: 'EDUCATOR', expanded: false),
                        _buildStatCard(label: 'Learners', count: learnerCount, icon: Icons.person_rounded, color: const Color(0xFFF59E0B), roleKey: 'LEARNER', expanded: false),
                      ],
                    )
                  else
                    Row(
                      children: [
                        _buildStatCard(label: 'Admins', count: adminCount, icon: Icons.shield_rounded, color: const Color(0xFF8B5CF6), roleKey: 'ADMIN'),
                        const SizedBox(width: 16),
                        _buildStatCard(label: 'Validators', count: validatorCount, icon: Icons.verified_rounded, color: const Color(0xFF3B82F6), roleKey: 'VALIDATOR'),
                        const SizedBox(width: 16),
                        _buildStatCard(label: 'Educators', count: educatorCount, icon: Icons.school_rounded, color: const Color(0xFF81B655), roleKey: 'EDUCATOR'),
                        const SizedBox(width: 16),
                        _buildStatCard(label: 'Learners', count: learnerCount, icon: Icons.person_rounded, color: const Color(0xFFF59E0B), roleKey: 'LEARNER'),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // ── Segmented Role Filter Tabs ────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRoleChip('ALL', 'All Users', allUsers.length, const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        _buildRoleChip('ADMIN', 'Admins', adminCount, const Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        _buildRoleChip('VALIDATOR', 'Validators', validatorCount, const Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        _buildRoleChip('EDUCATOR', 'Educators', educatorCount, const Color(0xFF81B655)),
                        const SizedBox(width: 8),
                        _buildRoleChip('LEARNER', 'Learners', learnerCount, const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                                  onChanged: (v) => setState(() {
                                    _searchQuery = v;
                                    _currentPage = 1;
                                  }),
                                  style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: 'Search users by name or email…',
                                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Sorted by: $_selectedFilter',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── User List ─────────────────────────────────────────
                  if (users.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.person_search_rounded, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No users found', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  else if (isMobile)
                    // ── Mobile: Card list ──────────────────────────────
                    Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paginatedUsers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildUserCard(paginatedUsers[index]),
                        ),
                        _buildPaginationBar(
                          totalUsers: totalUsers,
                          totalPages: totalPages,
                          startIndex: startIndex,
                          endIndex: endIndex,
                          isMobile: true,
                        ),
                      ],
                    )
                  else
                    // ── Desktop: Table ────────────────────────────────
                    Column(
                      children: [
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                                    _tableH('Educ. Dates', 2),
                                    _tableH('Action', 4, center: true),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: paginatedUsers.length,
                                separatorBuilder: (context, index) => const Divider(
                                  height: 1, color: Color(0xFFF1F5F9), indent: 24, endIndent: 24,
                                ),
                                itemBuilder: (context, index) => _buildUserRow(paginatedUsers[index]),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        _buildPaginationBar(
                          totalUsers: totalUsers,
                          totalPages: totalPages,
                          startIndex: startIndex,
                          endIndex: endIndex,
                          isMobile: false,
                        ),
                      ],
                    ),
                ],
              ),
            );

          },
        );
      },
    );
  }

  Widget _buildRoleChip(String roleKey, String label, int count, Color color) {
    final isSelected = _selectedRoleFilter == roleKey;
    return InkWell(
      onTap: () => setState(() {
        _selectedRoleFilter = roleKey;
        _currentPage = 1;
      }),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required String roleKey,
    bool expanded = true,
  }) {
    final isSelected = _selectedRoleFilter == roleKey;
    final cardWidget = InkWell(
      onTap: () => setState(() {
        _selectedRoleFilter = isSelected ? 'ALL' : roleKey;
        _currentPage = 1;
      }),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.18),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isSelected ? 0.16 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'FILTERED',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
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

    return expanded ? Expanded(child: cardWidget) : cardWidget;
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
                  setState(() {
                    _selectedFilter = option;
                    _currentPage = 1;
                  });
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

  Widget _buildPaginationBar({
    required int totalUsers,
    required int totalPages,
    required int startIndex,
    required int endIndex,
    required bool isMobile,
  }) {
    if (totalUsers == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 22, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81B655).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '10 per page',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF81B655),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Showing ${startIndex + 1}–$endIndex of $totalUsers',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pageNavBtn(
                      icon: Icons.chevron_left_rounded,
                      label: 'Prev',
                      enabled: _currentPage > 1,
                      onTap: () => setState(() => _currentPage--),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81B655).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Page $_currentPage of $totalPages',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF81B655),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _pageNavBtn(
                      icon: Icons.chevron_right_rounded,
                      label: 'Next',
                      enabled: _currentPage < totalPages,
                      onTap: () => setState(() => _currentPage++),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81B655).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '10 per page',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF81B655),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Showing ${startIndex + 1}–$endIndex of $totalUsers users',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _pageNavBtn(
                      icon: Icons.chevron_left_rounded,
                      label: 'Previous',
                      enabled: _currentPage > 1,
                      onTap: () => setState(() => _currentPage--),
                    ),
                    const SizedBox(width: 6),
                    ..._buildPageNumbers(totalPages),
                    const SizedBox(width: 6),
                    _pageNavBtn(
                      icon: Icons.chevron_right_rounded,
                      label: 'Next',
                      enabled: _currentPage < totalPages,
                      onTap: () => setState(() => _currentPage++),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _pageNavBtn({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? Colors.grey.shade100 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? const Color(0xFFCBD5E1) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label == 'Previous' || label == 'Prev') ...[
                Icon(icon, size: 16, color: enabled ? Colors.black87 : Colors.grey.shade300),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.black87 : Colors.grey.shade300,
                ),
              ),
              if (label == 'Next') ...[
                const SizedBox(width: 4),
                Icon(icon, size: 16, color: enabled ? Colors.black87 : Colors.grey.shade300),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    if (totalPages <= 1) return [];

    final List<Widget> pages = [];
    final int start = (_currentPage - 2).clamp(1, totalPages);
    final int end = (_currentPage + 2).clamp(1, totalPages);

    if (start > 1) {
      pages.add(_pageNumberBtn(1));
      if (start > 2) {
        pages.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('…', style: GoogleFonts.inter(color: Colors.grey)),
        ));
      }
    }

    for (int p = start; p <= end; p++) {
      pages.add(_pageNumberBtn(p));
    }

    if (end < totalPages) {
      if (end < totalPages - 1) {
        pages.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('…', style: GoogleFonts.inter(color: Colors.grey)),
        ));
      }
      pages.add(_pageNumberBtn(totalPages));
    }

    return pages;
  }

  Widget _pageNumberBtn(int page) {
    final isSelected = page == _currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => setState(() => _currentPage = page),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF81B655) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF81B655) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF81B655).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$page',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
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

    final educStart = u['educatorStartDate'] != null ? _formatTs(u['educatorStartDate']) : 'N/A';
    final educEnd = u['educatorEndDate'] != null ? _formatTs(u['educatorEndDate']) : 'Present';
    final educDates = role == 'EDUCATOR' ? '$educStart\n$educEnd' : '—';

    final lockedUntilTs = u['locked_until'] as Timestamp?;
    final isLocked = lockedUntilTs != null && lockedUntilTs.toDate().isAfter(DateTime.now());

    final isActive = status.toLowerCase() == 'active';
    final isDefaultAdmin = RoleService.isDefaultAdmin(u, uid);
    final roleColor = _roleColor(isDefaultAdmin ? 'SUPERADMIN' : role);

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDefaultAdmin ? const Color(0xFFEF4444) : roleColor).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDefaultAdmin ? 'SUPERADMIN' : role,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDefaultAdmin ? const Color(0xFFEF4444) : roleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isDefaultAdmin) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DEFAULT ADMIN',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEF4444),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Status Chip ───────────────────────────────────────────
          Expanded(
            flex: 2,
            child: isLocked
                ? Tooltip(
                    message: 'Account locked due to 3 failed attempts (until ${_formatTs(lockedUntilTs)})',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 11, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'LOCKED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : status.toLowerCase().contains('in review')
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.amber.shade800),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
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

          // ── Educ Dates ────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Text(
              educDates,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, height: 1.5),
            ),
          ),

          // ── Action Buttons ─────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Builder(
              builder: (context) {
                final isSuperAdmin = widget.role == UserRole.superadmin;
                if (!isSuperAdmin) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'VIEW ONLY',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final currentUid = widget.currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
                final isSelf = currentUid == uid;
                final canModifyThisUser = isSuperAdmin && !isDefaultAdmin;
                final canRemoveThisUser = isSuperAdmin && !isDefaultAdmin && !isSelf;
                final isDeactivated = status.toUpperCase() == 'DEACTIVATED';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Change Role Button
                    Tooltip(
                      message: isDefaultAdmin
                          ? 'Default Super Admin cannot be modified'
                          : 'Change Role',
                      child: IconButton(
                        icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                        color: canModifyThisUser ? const Color(0xFF4B49AC) : Colors.grey.shade400,
                        style: IconButton.styleFrom(
                          backgroundColor: canModifyThisUser
                              ? const Color(0xFF4B49AC).withValues(alpha: 0.10)
                              : Colors.grey.shade100,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(32, 32),
                        ),
                        onPressed: canModifyThisUser ? () => _showChangeRoleDialog(uid, username, role) : null,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Deactivate / Activate Button
                    if (isDeactivated)
                      Tooltip(
                        message: 'Activate User',
                        child: IconButton(
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          color: const Color(0xFF81B655),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF81B655).withValues(alpha: 0.10),
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(32, 32),
                          ),
                          onPressed: () => _showActivateConfirmation(uid, username, email),
                        ),
                      )
                    else
                      Tooltip(
                        message: isDefaultAdmin
                            ? 'Default Super Admin cannot be deactivated'
                            : (isSelf
                                ? 'You cannot deactivate your own account'
                                : 'Deactivate User'),
                        child: IconButton(
                          icon: const Icon(Icons.block_rounded, size: 18),
                          color: canRemoveThisUser ? Colors.orange.shade700 : Colors.grey.shade400,
                          style: IconButton.styleFrom(
                            backgroundColor: canRemoveThisUser
                                ? Colors.orange.shade50
                                : Colors.grey.shade100,
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(32, 32),
                          ),
                          onPressed: canRemoveThisUser
                              ? () => _showDeactivateConfirmation(uid, username, email)
                              : null,
                        ),
                      ),
                    const SizedBox(width: 6),

                    // Remove User Button
                    Tooltip(
                      message: isDefaultAdmin
                          ? 'Default Super Admin cannot be removed'
                          : (isSelf
                              ? 'You cannot remove your own account'
                              : 'Remove User'),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: canRemoveThisUser ? const Color(0xFFEF4444) : Colors.grey.shade400,
                        style: IconButton.styleFrom(
                          backgroundColor: canRemoveThisUser
                              ? const Color(0xFFEF4444).withValues(alpha: 0.10)
                              : Colors.grey.shade100,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(32, 32),
                        ),
                        onPressed: canRemoveThisUser
                            ? () => _showRemoveUserConfirmation(uid, username, email, role)
                            : null,
                      ),
                    ),

                    if (isLocked) ...[
                      const SizedBox(width: 6),
                      // Unlock Button
                      Tooltip(
                        message: isDefaultAdmin
                            ? 'Default Super Admin'
                            : 'Unlock Account (Clear Lockout)',
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.lock_open_rounded, size: 14),
                          label: Text(
                            'UNLOCK',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canModifyThisUser ? Colors.red.shade50 : Colors.grey.shade100,
                            foregroundColor: canModifyThisUser ? Colors.red.shade700 : Colors.grey.shade400,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            side: BorderSide(
                              color: canModifyThisUser ? Colors.red.shade300 : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: canModifyThisUser ? () => _showUnlockConfirmation(uid, username, email) : null,
                        ),
                      ),
                    ],

                    Builder(
                      builder: (context) {
                        final isTargetValidator = role.toUpperCase() == 'VALIDATOR';
                        final isVerified = u['isVerified'] == true;
                        final isPendingValidator = _isPendingValidator(u);
                        final isAlreadyValidated = isTargetValidator && isVerified && (status.toLowerCase() == 'active');
                        final canValidate = isSuperAdmin && !isDefaultAdmin && isPendingValidator;

                        String validateTooltip;
                        if (isDefaultAdmin) {
                          validateTooltip = 'Default Super Admin cannot be modified';
                        } else if (isAlreadyValidated) {
                          validateTooltip = 'Validator is already validated & active';
                        } else if (!isPendingValidator) {
                          validateTooltip = 'Validation is only available for pending validators';
                        } else {
                          validateTooltip = 'Validate Validator Application';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Tooltip(
                            message: validateTooltip,
                            child: ElevatedButton.icon(
                              icon: Icon(
                                isAlreadyValidated
                                    ? Icons.verified_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 13,
                              ),
                              label: Text(isAlreadyValidated ? 'VALIDATED' : 'VALIDATE'),
                              onPressed: canValidate
                                  ? () => _showValidateValidatorDialog(u)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canValidate
                                    ? const Color(0xFF81B655)
                                    : (isAlreadyValidated
                                        ? const Color(0xFF81B655).withValues(alpha: 0.08)
                                        : Colors.grey.shade100),
                                foregroundColor: canValidate
                                    ? Colors.white
                                    : (isAlreadyValidated
                                        ? const Color(0xFF81B655).withValues(alpha: 0.7)
                                        : Colors.grey.shade400),
                                elevation: canValidate ? 1 : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                side: BorderSide(
                                  color: canValidate
                                      ? const Color(0xFF81B655)
                                      : (isAlreadyValidated
                                          ? const Color(0xFF81B655).withValues(alpha: 0.25)
                                          : Colors.grey.shade300),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                textStyle: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile card view of a single user ─────────────────────────────────────
  Widget _buildUserCard(Map<String, dynamic> u) {
    final email = (u['email'] ?? 'N/A') as String;
    final role = (u['role'] ?? 'N/A') as String;
    final uid = (u['uid'] ?? 'N/A') as String;
    final username = (u['username'] ?? 'N/A') as String;
    final status = (u['status'] ?? 'N/A') as String;

    final lockedUntilTs = u['locked_until'] as Timestamp?;
    final isLocked = lockedUntilTs != null && lockedUntilTs.toDate().isAfter(DateTime.now());
    final isActive = status.toLowerCase() == 'active';
    final isDefaultAdmin = RoleService.isDefaultAdmin(u, uid);
    final roleColor = _roleColor(isDefaultAdmin ? 'SUPERADMIN' : role);

    final educStart = u['educatorStartDate'] != null ? _formatTs(u['educatorStartDate']) : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name/email + role badge
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  backgroundImage: u['photoUrl'] != null
                      ? NetworkImage(u['photoUrl'] as String)
                      : null,
                  child: u['photoUrl'] == null
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 14),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        email,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Role badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDefaultAdmin ? const Color(0xFFEF4444) : roleColor).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isDefaultAdmin ? 'SUPERADMIN' : role,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: isDefaultAdmin ? const Color(0xFFEF4444) : roleColor),
                      ),
                    ),
                    if (isDefaultAdmin) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DEFAULT ADMIN',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFEF4444),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status row
            Row(
              children: [
                if (isLocked) ...[
                  Icon(Icons.lock_rounded, size: 13, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text('LOCKED', style: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                ] else if (status.toLowerCase().contains('in review')) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.amber.shade800),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF81B655) : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 12, color: isActive ? const Color(0xFF81B655) : Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ],
                if (educStart != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.school_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('Since $educStart', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),

            const Divider(height: 20),

            // Action buttons
            Builder(
              builder: (context) {
                final isSuperAdmin = widget.role == UserRole.superadmin;
                if (!isSuperAdmin) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'VIEW ONLY (ADMIN)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final currentUid = widget.currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
                final isSelf = currentUid == uid;
                final canModifyThisUser = isSuperAdmin && !isDefaultAdmin;
                final canRemoveThisUser = isSuperAdmin && !isDefaultAdmin && !isSelf;
                final isDeactivated = status.toUpperCase() == 'DEACTIVATED';

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Change Role
                    Tooltip(
                      message: isDefaultAdmin
                          ? 'Default Super Admin cannot be modified'
                          : 'Change Role',
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.manage_accounts_rounded, size: 15),
                        label: const Text('Change Role'),
                        onPressed: canModifyThisUser ? () => _showChangeRoleDialog(uid, username, role) : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: canModifyThisUser ? const Color(0xFF4B49AC) : Colors.grey.shade400,
                          side: BorderSide(color: canModifyThisUser ? const Color(0xFF4B49AC) : Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    // Deactivate / Activate (Super Admin only)
                    if (isDeactivated)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                        label: const Text('Activate'),
                        onPressed: () => _showActivateConfirmation(uid, username, email),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF81B655),
                          side: const BorderSide(color: Color(0xFF81B655)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    else
                      Tooltip(
                        message: isDefaultAdmin
                            ? 'Default Super Admin cannot be deactivated'
                            : (isSelf ? 'You cannot deactivate your own account' : 'Deactivate User'),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.block_rounded, size: 15),
                          label: const Text('Deactivate'),
                          onPressed: canRemoveThisUser
                              ? () => _showDeactivateConfirmation(uid, username, email)
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: canRemoveThisUser ? Colors.orange.shade700 : Colors.grey.shade400,
                            side: BorderSide(color: canRemoveThisUser ? Colors.orange.shade300 : Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    // Remove User (Super Admin only)
                    Tooltip(
                      message: isDefaultAdmin
                          ? 'Default Super Admin cannot be removed'
                          : (isSelf ? 'You cannot remove your own account' : 'Remove User'),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 15),
                        label: const Text('Remove User'),
                        onPressed: canRemoveThisUser
                            ? () => _showRemoveUserConfirmation(uid, username, email, role)
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: canRemoveThisUser ? const Color(0xFFEF4444) : Colors.grey.shade400,
                          side: BorderSide(color: canRemoveThisUser ? const Color(0xFFEF4444) : Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    // Unlock (if locked)
                    if (isLocked)
                      Tooltip(
                        message: isDefaultAdmin
                            ? 'Default Super Admin'
                            : 'Unlock Account',
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.lock_open_rounded, size: 15),
                          label: const Text('Unlock'),
                          onPressed: canModifyThisUser ? () => _showUnlockConfirmation(uid, username, email) : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: canModifyThisUser ? Colors.red.shade700 : Colors.grey.shade400,
                            side: BorderSide(color: canModifyThisUser ? Colors.red.shade300 : Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    // Validate Validator Button
                    Builder(
                      builder: (context) {
                        final isTargetValidator = role.toUpperCase() == 'VALIDATOR';
                        final isVerified = u['isVerified'] == true;
                        final isPendingValidator = _isPendingValidator(u);
                        final isAlreadyValidated = isTargetValidator && isVerified && (status.toLowerCase() == 'active');
                        final canValidate = isSuperAdmin && !isDefaultAdmin && isPendingValidator;

                        String validateTooltip;
                        if (isDefaultAdmin) {
                          validateTooltip = 'Default Super Admin cannot be modified';
                        } else if (isAlreadyValidated) {
                          validateTooltip = 'Validator is already validated & active';
                        } else if (!isPendingValidator) {
                          validateTooltip = 'Validation is only available for pending validators';
                        } else {
                          validateTooltip = 'Validate Validator Application';
                        }

                        return Tooltip(
                          message: validateTooltip,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              isAlreadyValidated
                                  ? Icons.verified_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 14,
                            ),
                            label: Text(isAlreadyValidated ? 'VALIDATED' : 'VALIDATE'),
                            onPressed: canValidate ? () => _showValidateValidatorDialog(u) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canValidate
                                  ? const Color(0xFF81B655)
                                  : (isAlreadyValidated
                                      ? const Color(0xFF81B655).withValues(alpha: 0.08)
                                      : Colors.grey.shade100),
                              foregroundColor: canValidate
                                  ? Colors.white
                                  : (isAlreadyValidated
                                      ? const Color(0xFF81B655).withValues(alpha: 0.7)
                                      : Colors.grey.shade400),
                              elevation: canValidate ? 1 : 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: BorderSide(
                                color: canValidate
                                    ? const Color(0xFF81B655)
                                    : (isAlreadyValidated
                                        ? const Color(0xFF81B655).withValues(alpha: 0.25)
                                        : Colors.grey.shade300),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'SUPERADMIN':
        return const Color(0xFFEF4444);
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

  void _showChangeRoleDialog(String uid, String username, String currentRoleStr) {
    if (widget.role != UserRole.superadmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Super Admin can change user roles.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (RoleService.isDefaultAdmin(null, uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot modify the role of the default Super Admin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    String selectedRole = currentRoleStr.toUpperCase();
    final roles = [
      {
        'key': 'LEARNER',
        'label': 'Learner',
        'desc': 'Standard student learning account',
        'icon': Icons.person_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'EDUCATOR',
        'label': 'Educator',
        'desc': 'Can host mentorships & create contents',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF81B655),
      },
      {
        'key': 'VALIDATOR',
        'label': 'Validator',
        'desc': 'Can review & validate quiz questions',
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF3B82F6),
      },
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 420,
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
                        color: const Color(0xFF4B49AC).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF4B49AC), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change User Role',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87),
                          ),
                          Text(
                            'Select new role for $username',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...roles.map((r) {
                  final key = r['key'] as String;
                  final isSelected = selectedRole == key;
                  final color = r['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setDialogState(() => selectedRole = key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(r['icon'] as IconData, color: color, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['label'] as String,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                                  ),
                                  Text(
                                    r['desc'] as String,
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? color : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? color : Colors.grey.shade400,
                                  width: isSelected ? 6 : 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black54,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (selectedRole == currentRoleStr.toUpperCase()) {
                            Navigator.pop(context);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('$username already has the $selectedRole role.'),
                                backgroundColor: Colors.grey.shade700,
                              ),
                            );
                            return;
                          }

                          // Confirmation dialog before changing role
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (confirmCtx) => Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: Container(
                                width: 420,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4B49AC).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF4B49AC), size: 22),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            'Confirm Role Change',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Are you sure you want to change $username\'s role from $currentRoleStr to $selectedRole?\n\nThis user will receive an in-app notification and their platform permissions will update immediately.',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey.shade700,
                                        fontSize: 13.5,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => Navigator.pop(confirmCtx, false),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.black54,
                                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.pop(confirmCtx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4B49AC),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: Text('Confirm', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          if (confirmed != true) return;

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          try {
                            final newRole = roleFromString(selectedRole);
                            await RoleService.instance.setUserRole(uid: uid, role: newRole);

                            // Send notification to the user
                            await NotificationService.instance.sendNotification(
                              uid: uid,
                              title: 'Role Updated',
                              message: 'Your account role has been updated from $currentRoleStr to $selectedRole by an administrator.',
                              type: NotificationType.general,
                            );

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('$username\'s role updated to $selectedRole ✓'),
                                backgroundColor: const Color(0xFF81B655),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error updating role: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B49AC),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Save Role', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showValidateValidatorDialog(Map<String, dynamic> u) async {
    if (widget.role != UserRole.superadmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Super Admin can validate validator applications.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final uid = (u['uid'] ?? '').toString();
    final username = (u['username'] ?? u['full_name'] ?? 'Applicant').toString();
    final email = (u['email'] ?? 'N/A').toString();

    // Look for PRC file in user doc or in educatorApplications collection
    String prcUrl = (u['prc_url'] ?? u['prcUrl'] ?? '').toString();
    String prcFileName = (u['prc_file_name'] ?? u['prcFileName'] ?? '').toString();
    EducatorApplication? app;

    try {
      final appsSnap = await FirebaseFirestore.instance
          .collection('educatorApplications')
          .where('applicantUid', isEqualTo: uid)
          .get();
      for (final doc in appsSnap.docs) {
        final a = EducatorApplication.fromDoc(doc);
        if (a.applicationType == 'validator' || a.status == 'pending') {
          app = a;
          if (prcUrl.isEmpty && a.prcUrl.isNotEmpty) {
            prcUrl = a.prcUrl;
          }
          if (prcFileName.isEmpty && (a.prcFileName ?? '').isNotEmpty) {
            prcFileName = a.prcFileName!;
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('Error finding application: $e');
    }

    if (prcFileName.isEmpty && prcUrl.isNotEmpty) {
      prcFileName = 'PRC_License_Document.pdf';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF81B655).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF81B655),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Validate Validator',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Accreditation Verification',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Applicant Info Box ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            username,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            'IN REVIEW',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── PRC Document Review ───────────────────────────
              Text(
                'Accreditation Document',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              if (prcUrl.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B49AC).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.file_present_rounded, color: Color(0xFF4B49AC), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prcFileName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'PRC / ID Document',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => showFilePreviewModal(context, prcUrl, prcFileName),
                        icon: const Icon(Icons.visibility_rounded, size: 14),
                        label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4B49AC).withValues(alpha: 0.12),
                          foregroundColor: const Color(0xFF4B49AC),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No PRC document file found on this profile.',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              Text(
                'Validating this application will officially verify the applicant as a certified Validator, grant access to the Validator Panel, and update their account status to Active.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // ── Actions ───────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (app != null) ...[
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        final result = await showContentDenialDialog(
                          context,
                          contentTitle: 'Validator Application - $username',
                          authorName: username,
                          isPermanentDeletion: false,
                        );
                        if (result != null) {
                          try {
                            await DatabaseService.instance.rejectValidatorApplication(
                              uid: uid,
                              reason: result.category,
                              description: result.explanation,
                              reviewerEmail: widget.currentUser?.email,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Validator application rejected and applicant notified.'),
                                  backgroundColor: Color(0xFFE05050),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error rejecting application: $e')),
                              );
                            }
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      child: Text('Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text('VALIDATE', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        try {
                          await DatabaseService.instance.validateValidatorApplication(
                            uid: uid,
                            reviewerEmail: widget.currentUser?.email,
                          );
                          if (email.isNotEmpty && email != 'N/A') {
                            try {
                              await EmailSenderService.sendEmail(
                                toEmail: email,
                                subject: 'Your Grammatica Validator Application Has Been Approved!',
                                body: 'Hello $username,\n\nYour application to become an official Grammatica Validator has been verified and approved by the Super Admin.\n\nYou now have full access to validate lessons and educational content on Grammatica.\n\nBest regards,\nThe Grammatica Team',
                              );
                            } catch (_) {}
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Validator application for $username validated successfully!'),
                                backgroundColor: const Color(0xFF81B655),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to validate validator: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  void _showUnlockConfirmation(
      String uid, String username, String email) {
    if (RoleService.isDefaultAdmin(null, uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default Super Admin account is never locked.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
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
                      color: const Color(0xFF81B655).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Color(0xFF81B655),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Unlock Account',
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
                'Are you sure you want to unlock $username\'s account? This will immediately clear the temporary lockout and reset failed login attempts.',
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
                        await AuthService.instance.unlockAccount(email, uid: uid);
                        if (mounted) {
                          AuthService.showSnackBar(
                            'Account for $username has been unlocked.',
                            isError: false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Unlock',
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

  void _showLoadingModal(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 20),
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeactivateConfirmation(
    String uid,
    String username,
    String email,
  ) async {
    if (RoleService.isDefaultAdmin(null, uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot deactivate the default Super Admin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final currentUid = widget.currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot deactivate your own account from here.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (widget.role != UserRole.superadmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Super Admin can deactivate users.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deactivate User',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Account Suspension',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The user will be immediately signed out and blocked from logging in until reactivated by a Super Admin.',
                        style: GoogleFonts.inter(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to deactivate $username ($email)?',
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Deactivate', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    _showLoadingModal('Deactivating user...');
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'status': 'DEACTIVATED',
        'is_active': false,
        'deactivated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('User $username has been deactivated.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deactivating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _showActivateConfirmation(
    String uid,
    String username,
    String email,
  ) async {
    if (widget.role != UserRole.superadmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Super Admin can activate users.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF81B655).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF81B655),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activate User',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Restore Account Access',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF81B655),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to activate $username ($email)? The user will be able to log in and use their account immediately.',
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Activate', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    _showLoadingModal('Activating user account...');
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'status': 'ACTIVE',
        'is_active': true,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'deactivated_at': FieldValue.delete(),
        'locked_until': FieldValue.delete(),
        'failed_login_attempts': 0,
      }).catchError((_) {});

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('User account activated successfully.'),
            backgroundColor: Color(0xFF81B655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error activating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _showRemoveUserConfirmation(
    String uid,
    String username,
    String email,
    String role,
  ) async {
    if (RoleService.isDefaultAdmin(null, uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the default Super Admin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final currentUid = widget.currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot remove your own account from here.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_remove_rounded,
                      color: Color(0xFFEF4444),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remove User',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Permanent Account Deletion',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Warning: This action is permanent and cannot be undone. All user data, lessons, quizzes, progress, and subscriptions will be deleted.',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to remove $username ($email) [Role: $role]?',
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Remove User', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    _showLoadingModal('Deleting user account...');
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DatabaseService.instance.deleteUserAccount(uid, asSuperAdmin: true);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('User $username has been removed permanently.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error removing user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showAddAdminDialog() {
    if (widget.role != UserRole.superadmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Super Admin can add administrators.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(28),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Color(0xFF8B5CF6), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Admin',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Create an administrator account with limited permissions',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF8B5CF6), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A password reset confirmation link will be sent immediately to the admin\'s email address so they can set their password and sign in. (Only @yahoo.com, @gmail.com, and @hotmail.com domains are accepted).',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.black87, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text.rich(
                    TextSpan(
                      text: 'ADMIN EMAIL ADDRESS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                      children: const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'admin@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (val) {
                      final email = val?.trim() ?? '';
                      if (email.isEmpty) return 'Please enter an email address';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                        return 'Please enter a valid email address';
                      }
                      if (!EmailValidatorService.isAllowedSuperAdminEmail(email)) {
                        return 'Only @yahoo.com, @gmail.com, and @hotmail.com are allowed';
                      }
                      return null;
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() {
                                    isSubmitting = true;
                                    errorMessage = null;
                                  });

                                  final email = emailCtrl.text.trim();
                                  try {
                                    final rand = Random.secure();
                                    final tempPassword = 'Gramm_${100000 + rand.nextInt(900000)}!';

                                    // Create user via secondary FirebaseApp to preserve current superadmin session
                                    final tempAppName = 'tempAdminReg_${DateTime.now().millisecondsSinceEpoch}';
                                    final tempApp = await Firebase.initializeApp(
                                      name: tempAppName,
                                      options: Firebase.app().options,
                                    );
                                    final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
                                    final cred = await tempAuth.createUserWithEmailAndPassword(
                                      email: email,
                                      password: tempPassword,
                                    );
                                    final newUid = cred.user!.uid;
                                    await tempApp.delete();

                                    // Save admin user record
                                    await FirebaseFirestore.instance.collection('users').doc(newUid).set({
                                      'uid': newUid,
                                      'email': email.toLowerCase(),
                                      'username': email.split('@').first,
                                      'role': 'ADMIN',
                                      'status': 'ACTIVE',
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    // Immediately send password reset confirmation email
                                    try {
                                      await AuthService.instance.sendPasswordResetEmail(email);
                                    } catch (e) {
                                      debugPrint('⚠️ sendPasswordResetEmail error: $e');
                                    }

                                    // Send invitation email with credentials and notification
                                    try {
                                      await EmailSenderService.sendAdminInvitationEmail(
                                        recipientEmail: email,
                                        temporaryPassword: tempPassword,
                                      );
                                    } catch (e) {
                                      debugPrint('⚠️ sendAdminInvitationEmail error: $e');
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Admin account created! Password reset confirmation sent immediately to $email.'),
                                          backgroundColor: const Color(0xFF81B655),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                      errorMessage = e.toString().replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Create & Email', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSeedBadgesListDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          width: 640,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seeded Badges & Achievement Criteria',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All badges are active in Firestore. Learners automatically unlock each badge by completing its criteria:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Success Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Badges seeded into Firestore database successfully!',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Badges list
              Expanded(
                child: StreamBuilder<List<BadgeModel>>(
                  stream: BadgeService.instance.streamBadges(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final badges = snapshot.data ?? [];
                    if (badges.isEmpty) {
                      return Center(
                        child: Text(
                          'No badges found. Try clicking Seed Badges again.',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: badges.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final b = badges[idx];
                        final tierColor = _getBadgeTierColor(b.tier);
                        final instructions = _getBadgeAchievementInstructions(b);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Badge Icon
                              Container(
                                width: 56,
                                height: 56,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tierColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: tierColor.withValues(alpha: 0.4), width: 1.5),
                                ),
                                child: b.iconAsset.endsWith('.svg')
                                    ? SvgPicture.asset(
                                        b.iconAsset,
                                        placeholderBuilder: (_) => Icon(Icons.military_tech_rounded, color: tierColor),
                                      )
                                    : Icon(Icons.military_tech_rounded, color: tierColor, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          b.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: tierColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            b.tier.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: tierColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            b.category.replaceAll('_', ' ').toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      b.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // How to achieve box
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF81B655).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF81B655).withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.emoji_events_rounded, color: Color(0xFF81B655), size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                                                children: [
                                                  const TextSpan(
                                                    text: 'How to achieve: ',
                                                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF81B655)),
                                                  ),
                                                  TextSpan(text: instructions),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Footer
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF81B655),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBadgeTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'silver':
        return const Color(0xFFA0AEC0);
      case 'gold':
        return const Color(0xFFF59E0B);
      case 'diamond':
        return const Color(0xFF38BDF8);
      default:
        return const Color(0xFF81B655);
    }
  }

  String _getBadgeAchievementInstructions(BadgeModel badge) {
    switch (badge.criteriaType) {
      case 'lessons_completed':
        return 'Complete and finish at least ${badge.threshold} lesson module${badge.threshold == 1 ? '' : 's'}.';
      case 'perfect_quizzes':
        return 'Take a quiz and obtain a 100% score (requires ${badge.threshold} perfect quiz${badge.threshold == 1 ? '' : 'zes'}).';
      case 'flashcards_reviewed':
        return 'Review at least ${badge.threshold} flashcards in the flashcard study session.';
      case 'spelling_correct':
        return 'Spell ${badge.threshold} words correctly in the Spelling Bee challenge.';
      case 'current_streak':
        return 'Practice on consecutive days to reach a ${badge.threshold}-day study streak.';
      default:
        return '${badge.description} (Target: ${badge.threshold} on criteria "${badge.criteriaType}").';
    }
  }
}

