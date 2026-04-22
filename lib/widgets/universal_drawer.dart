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
      if (role == UserRole.validator) {
        navItems.add(const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'));
        navItems.add(const ModernNavItem(icon: Icons.verified_user, label: 'Validation'));
      } else {
        if (role == UserRole.educator) {
          navItems.insert(0, const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'));
        }

        if (role == UserRole.superadmin) {
           navItems.add(const ModernNavItem(icon: Icons.verified_user, label: 'Validation'));
        }
        navItems.add(const ModernNavItem(icon: Icons.edit_document, label: 'Contents'));
        navItems.add(const ModernNavItem(icon: Icons.book, label: 'Lessons'));
        navItems.add(const ModernNavItem(icon: Icons.group, label: 'Premium Group'));
        
        if (role == UserRole.admin) {
          navItems.add(const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'));
        } else if (role == UserRole.educator) {
           navItems.add(const ModernNavItem(icon: Icons.assignment, label: 'English Assessment'));
        }

        if (role != UserRole.educator) {
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
