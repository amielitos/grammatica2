import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';
import '../../theme/app_colors.dart';
import 'admin/admin_users_tab.dart';
import 'admin/admin_lessons_tab.dart';
import 'admin/admin_quizzes_tab.dart';
import 'admin/admin_validation_tab.dart';
import '../../services/role_service.dart';

import '../widgets/modern_bottom_nav.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.adminBackgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: StreamBuilder<UserRole>(
          stream: AuthService.instance.currentUser != null
              ? RoleService.instance.roleStream(
                  AuthService.instance.currentUser!.uid,
                )
              : null,
          builder: (context, roleSnap) {
            final role = roleSnap.data;
            String roleStr = role == UserRole.admin
                ? ' (Admin)'
                : (role == UserRole.educator ? ' (Educator)' : '');
            return Text(
              'Grammatica$roleStr',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            );
          },
        ),
      ),
      body: StreamBuilder<UserRole>(
        stream: AuthService.instance.currentUser != null
            ? RoleService.instance.roleStream(
                AuthService.instance.currentUser!.uid,
              )
            : null,
        builder: (context, roleSnap) {
          if (!roleSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final role = roleSnap.data!;
          final isAdmin = role == UserRole.admin;

          final List<Widget> tabs = [];
          if (isAdmin) tabs.add(const AdminUsersTab());
          tabs.add(const AdminLessonsTab());
          tabs.add(const AdminQuizzesTab());
          if (isAdmin) tabs.add(const AdminValidationTab());
          tabs.add(ProfilePage(user: AuthService.instance.currentUser!));

          return Stack(
            children: [
              IndexedStack(index: _index, children: tabs),
              if (_switching) ...[
                const ModalBarrier(dismissible: false, color: Colors.black12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<UserRole>(
        stream: AuthService.instance.currentUser != null
            ? RoleService.instance.roleStream(
                AuthService.instance.currentUser!.uid,
              )
            : null,
        builder: (context, roleSnap) {
          if (!roleSnap.hasData) return const SizedBox();
          final role = roleSnap.data!;
          final isAdmin = role == UserRole.admin;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService.instance.currentUser != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(AuthService.instance.currentUser!.uid)
                      .snapshots()
                : null,
            builder: (context, userSnap) {
              final userData = userSnap.data?.data();
              final username =
                  (userData?['username'] as String?)?.split(' ').first ??
                  'Profile';

              final List<ModernNavItem> navItems = [];
              if (isAdmin) {
                navItems.add(
                  const ModernNavItem(
                    icon: CupertinoIcons.person_2,
                    label: 'Users',
                  ),
                );
              }
              navItems.add(
                const ModernNavItem(
                  icon: CupertinoIcons.book,
                  label: 'Lessons',
                ),
              );
              navItems.add(
                const ModernNavItem(
                  icon: CupertinoIcons.question_circle,
                  label: 'Quizzes',
                ),
              );
              if (isAdmin) {
                navItems.add(
                  const ModernNavItem(
                    icon: CupertinoIcons.checkmark_shield,
                    label: 'Validation',
                  ),
                );
              }
              navItems.add(
                ModernNavItem(icon: CupertinoIcons.person, label: username),
              );

              // Ensure index is within bounds if role changes or during initial load
              if (_index >= navItems.length) {
                _index = navItems.length - 1;
              }

              return ModernBottomNav(
                currentIndex: _index,
                onTap: (i) async {
                  setState(() => _switching = true);
                  await Future.delayed(const Duration(milliseconds: 250));
                  if (!mounted) return;
                  setState(() {
                    _index = i;
                    _switching = false;
                  });
                },
                items: navItems,
              );
            },
          );
        },
      ),
    );
  }
}
