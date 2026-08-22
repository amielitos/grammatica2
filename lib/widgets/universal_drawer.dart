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

  const UniversalDrawer({
    super.key,
    required this.user,
    required this.userData,
    this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final role = roleFromString(userData['role'] as String?);
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin || role == UserRole.validator;
    final isEducator = role == UserRole.educator;
    final username = (userData['username'] as String?)?.split(' ').first ?? 'User';

    if (isAdmin || isEducator) {
      // Logic from AdminDashboard
      final List<ModernNavItem> navItems = [];
      final isSuperAdmin = role == UserRole.superadmin;
      final isAdminOrSuperAdmin = role == UserRole.admin || role == UserRole.superadmin;
      
      if (role == UserRole.validator) {
        navItems.add(const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'));
        navItems.add(const ModernNavItem(icon: Icons.verified_user, label: 'Validation'));
      } else {
        if (isEducator) {
          navItems.add(const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'));
        }

        if (isAdminOrSuperAdmin) {
          navItems.add(const ModernNavItem(icon: Icons.people, label: 'User Management'));
        }

        if (isSuperAdmin) {
           navItems.add(const ModernNavItem(icon: Icons.verified_user, label: 'Validation'));
        }

        if (isAdminOrSuperAdmin || isEducator) {
          navItems.add(const ModernNavItem(icon: Icons.edit_document, label: 'Contents'));
        }

        navItems.add(const ModernNavItem(icon: Icons.book, label: 'Lessons'));
        
        if (isAdminOrSuperAdmin || isEducator) {
          navItems.add(const ModernNavItem(icon: Icons.group, label: 'Premium Group'));
        }
        
        if (isAdminOrSuperAdmin || isEducator) {
          navItems.add(const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'));
        }

        // Site Settings — Admin only (must match AdminDashboard tab order)
        if (isAdminOrSuperAdmin) {
          navItems.add(const ModernNavItem(icon: Icons.web_rounded, label: 'Site Settings'));
        }

        if (!isEducator) {
          navItems.add(const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'));
        }
      }
      navItems.add(ModernNavItem(icon: Icons.person, label: username));

      return AdminSidebar(
        selectedIndex: currentIndex ?? -1,
        onItemSelected: (i) {
          if (onTap != null) {
            onTap!(i);
          } else {
            // Default behavior for pages not strictly in the dash
            Navigator.pop(context);
            // Maybe navigate to dashboard?
          }
        },
        userName: username,
        items: navItems,
        onSignOut: () => AuthService.instance.signOut(),
      );
    } else {
      // Logic from HomePage
      final navItems = [
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
        items: navItems,
        isDrawer: true,
      );
    }
  }
}
