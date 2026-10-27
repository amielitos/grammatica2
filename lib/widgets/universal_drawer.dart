import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sidebar.dart';
import 'admin_sidebar.dart';
import 'modern_bottom_nav.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';
import '../pages/home_page.dart';
import '../pages/admin_dashboard.dart';

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
    if (userData.isEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          return _buildDrawerContent(context, data);
        },
      );
    }
    return _buildDrawerContent(context, userData);
  }

  Widget _buildDrawerContent(BuildContext context, Map<String, dynamic> effectiveUserData) {
    final role = roleFromString(effectiveUserData['role'] as String?);
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin || role == UserRole.validator;
    final isEducator = role == UserRole.educator;
    final username = (effectiveUserData['username'] as String?)?.split(' ').first ?? 'User';

    if (isAdmin || isEducator) {
      final List<ModernNavItem> items =
          navItems != null ? List<ModernNavItem>.from(navItems!) : [];
      if (items.isEmpty) {
        final isSuperAdmin = role == UserRole.superadmin;
        final isAdminOrSuperAdmin = role == UserRole.admin || role == UserRole.superadmin;

        if (role == UserRole.validator) {
          final isVerified = effectiveUserData['isVerified'] == true;
          final statusStr = ((effectiveUserData['status'] as String?) ?? '').toLowerCase();
          final isApprovedValidator = isVerified && statusStr == 'active';

          items.add(const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'));
          if (isApprovedValidator) {
            items.add(const ModernNavItem(icon: Icons.rate_review_rounded, label: 'Lesson Review'));
          }
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

          if (isEducator) {
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
            items.add(const ModernNavItem(icon: Icons.credit_card, label: 'Enrollment'));
          }
        }
        items.add(const ModernNavItem(icon: Icons.person, label: 'My Profile'));
      }

      return AdminSidebar(
        selectedIndex: currentIndex ?? -1,
        onItemSelected: (i) {
          if (onTap != null) {
            onTap!(i);
          } else {
            AdminDashboard.navigateToTab(context, i);
          }
        },
        userName: username,
        items: items,
        onSignOut: () => AuthService.instance.confirmAndSignOut(context),
      );
    } else {
      // Logic from HomePage
      final items = navItems ?? [
        ModernNavItem(
          icon: role == UserRole.learner ? Icons.dashboard_rounded : Icons.book,
          label: role == UserRole.learner ? 'Dashboard' : 'Lessons',
        ),
        const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'),
        if (role != UserRole.learner) const ModernNavItem(icon: Icons.help_outline, label: 'Quizzes'),
        const ModernNavItem(icon: Icons.credit_card, label: 'Enrollment'),
        const ModernNavItem(icon: Icons.person, label: 'My Profile'),
      ];

      return Sidebar(
        currentIndex: currentIndex ?? -1,
        onTap: (i) {
          if (onTap != null) {
            onTap!(i);
          } else {
            HomePage.navigateToTab(context, i);
          }
        },
        items: items,
        isDrawer: true,
        onSignOut: () => AuthService.instance.confirmAndSignOut(context),
      );
    }
  }
}
