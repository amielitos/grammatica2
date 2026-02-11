import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_page.dart';
import '../../theme/app_colors.dart';
import 'admin/admin_users_tab.dart';
import 'admin/admin_lessons_tab.dart';
import 'admin/admin_quizzes_tab.dart';
import 'admin/admin_validation_tab.dart';
import '../../services/role_service.dart';

import '../widgets/modern_bottom_nav.dart';

import 'browse_educators_tab.dart';
import 'admin/educator_groups_tab.dart';
import 'practice_tab.dart';
import '../widgets/notification_widgets.dart';
import '../main.dart';

class AdminDashboard extends StatefulWidget {
  final User user;
  final bool showProfileWarning;
  const AdminDashboard({
    super.key,
    required this.user,
    this.showProfileWarning = false,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _switching = false;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(widget.user.uid),
      builder: (context, roleSnap) {
        if (!roleSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = roleSnap.data!;
        final isAdmin = role == UserRole.admin;
        final isEducator = role == UserRole.educator;
        final roleStr = isAdmin
            ? ' (Admin)'
            : (isEducator ? ' (Educator)' : '');

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.uid)
              .snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data();
            final username =
                (userData?['username'] as String?)?.split(' ').first ??
                'Profile';

            final List<Widget> tabs = [];
            final List<ModernNavItem> navItems = [];

            if (isAdmin) {
              tabs.add(const AdminUsersTab());
              navItems.add(
                const ModernNavItem(
                  icon: CupertinoIcons.person_2,
                  label: 'Users',
                ),
              );
            }

            tabs.add(const AdminLessonsTab());
            navItems.add(
              const ModernNavItem(icon: CupertinoIcons.book, label: 'Lessons'),
            );

            tabs.add(const AdminQuizzesTab());
            navItems.add(
              const ModernNavItem(
                icon: CupertinoIcons.question_circle,
                label: 'Quizzes',
              ),
            );

            if (isEducator) {
              tabs.add(EducatorGroupsTab(user: widget.user));
              navItems.add(
                const ModernNavItem(
                  icon: CupertinoIcons.person_3,
                  label: 'Groups',
                ),
              );
            }

            if (isAdmin) {
              tabs.add(const AdminValidationTab());
              navItems.add(
                const ModernNavItem(
                  icon: CupertinoIcons.checkmark_shield,
                  label: 'Validation',
                ),
              );
            }

            tabs.add(const PracticeTab());
            navItems.add(
              ModernNavItem(
                icon: CupertinoIcons.sparkles,
                label: 'Practice',
                selectedColor: Colors.orange.shade400,
              ),
            );

            tabs.add(BrowseEducatorsTab(user: widget.user));
            navItems.add(
              const ModernNavItem(
                icon: CupertinoIcons.creditcard,
                label: 'Subscription',
              ),
            );

            tabs.add(ProfilePage(user: widget.user));
            navItems.add(
              ModernNavItem(icon: CupertinoIcons.person, label: username),
            );

            if (_index >= navItems.length) {
              _index = navItems.length - 1;
            }

            return Scaffold(
              backgroundColor: isDark
                  ? AppColors.backgroundDark
                  : AppColors.adminBackgroundLight,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'Grammatica$roleStr',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                actions: [
                  NotificationIconButton(
                    userId: widget.user.uid,
                    onTap: () {
                      notificationVisibleNotifier.value =
                          !notificationVisibleNotifier.value;
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        IndexedStack(index: _index, children: tabs),
                        if (_switching) ...[
                          const ModalBarrier(
                            dismissible: false,
                            color: Colors.black12,
                          ),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: ModernBottomNav(
                currentIndex: _index,
                showProfileWarning: widget.showProfileWarning,
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
              ),
            );
          },
        );
      },
    );
  }
}
