import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sidebar.dart';
import 'admin_sidebar.dart';
import 'modern_bottom_nav.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';

class UniversalDrawer extends StatelessWidget {
  final User user;
  final Map<String, dynamic> userData;
  final int? currentIndex;
  final ValueChanged<int>? onTap;
  final List<ModernNavItem>? navItems;

  const UniversalDrawer({
    super.key,
    required this.user,
    required this.userData,
    this.currentIndex,
    this.onTap,
    this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    final role = roleFromString(userData['role'] as String?);
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin || role == UserRole.validator;
    final isEducator = role == UserRole.educator;
    final username = (userData['username'] as String?)?.split(' ').first ?? 'User';

    if (isAdmin || isEducator) {
      final List<ModernNavItem> items = navItems ?? [];
      if (items.isEmpty) {
        final isSuperAdmin = role == UserRole.superadmin;
        final isAdminOrSuperAdmin = role == UserRole.admin || role == UserRole.superadmin;

        if (role == UserRole.validator) {
          items.add(const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'));
          items.add(const ModernNavItem(icon: Icons.verified_user, label: 'Applications'));
        } else {
          if (isEducator) {
            items.add(const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'));
          }

          if (isAdminOrSuperAdmin) {
            items.add(const ModernNavItem(icon: Icons.people, label: 'User Management'));
          }

          if (isSuperAdmin) {
            items.add(const ModernNavItem(icon: Icons.verified_user, label: 'Applications'));
          }

          items.add(const ModernNavItem(icon: Icons.book, label: 'Lessons'));

          if (isAdminOrSuperAdmin || isEducator) {
            items.add(const ModernNavItem(icon: Icons.event, label: 'Mentorship'));
          }

          if (isAdminOrSuperAdmin || isEducator) {
            items.add(const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'));
          }

          if (isAdminOrSuperAdmin) {
            items.add(const ModernNavItem(icon: Icons.web_rounded, label: 'Site Settings'));
          }

          // AI Notebooks — Educator & Admin
          if (isAdminOrSuperAdmin || isEducator) {
            items.add(const ModernNavItem(icon: Icons.auto_stories_rounded, label: 'AI Notebooks'));
          }

          if (isAdminOrSuperAdmin) {
            items.add(const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'));
          }
        }
        items.add(ModernNavItem(icon: Icons.person, label: username));
      }

      return AdminSidebar(
        selectedIndex: currentIndex ?? -1,
        onItemSelected: (i) {
          if (onTap != null) {
            onTap!(i);
          } else {
            Navigator.pop(context);
          }
        },
        userName: username,
        items: items,
        onSignOut: () => AuthService.instance.signOut(),
      );
    } else {
      // Logic from HomePage
      final items = navItems ?? [
        const ModernNavItem(icon: Icons.book, label: 'Lessons'),
        const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'),
        if (role != UserRole.learner) const ModernNavItem(icon: Icons.help_outline, label: 'Quizzes'),
        const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
        ModernNavItem(icon: Icons.person, label: username),
      ];

      return Sidebar(
        currentIndex: currentIndex ?? -1,
        onTap: (i) {
          if (onTap != null) {
            onTap!(i);
          } else {
            Navigator.pop(context);
          }
        },
        items: items,
        isDrawer: true,
      );
    }
  }
}
