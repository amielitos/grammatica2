import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../widgets/admin_sidebar.dart';
import '../widgets/responsive_wrapper.dart';
import '../services/auth_service.dart';

class AdminDashboard extends StatefulWidget {
  final User user;
  final UserRole role;
  final Map<String, dynamic> userData;
  final bool showProfileWarning;
  const AdminDashboard({
    super.key,
    required this.user,
    required this.role,
    required this.userData,
    this.showProfileWarning = false,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == UserRole.admin;
    final isEducator = widget.role == UserRole.educator;
    final username =
        (widget.userData['username'] as String?)?.split(' ').first ?? 'Profile';

    final List<Widget> tabs = [];
    final List<ModernNavItem> navItems = [];

    // Define tabs and nav items based on roles
    // 0: Users (Admin only)
    if (isAdmin) {
      tabs.add(const AdminUsersTab());
      navItems.add(
        const ModernNavItem(icon: CupertinoIcons.person_2, label: 'Users'),
      );
    }

    // Validation (Admin only)
    if (isAdmin) {
      tabs.add(const AdminValidationTab());
      navItems.add(
        const ModernNavItem(
          icon: CupertinoIcons.checkmark_shield,
          label: 'Validation',
        ),
      );
    }

    // Lessons
    tabs.add(const AdminLessonsTab());
    navItems.add(
      const ModernNavItem(icon: CupertinoIcons.book, label: 'Lessons'),
    );

    // Quizzes
    tabs.add(const AdminQuizzesTab());
    navItems.add(
      const ModernNavItem(
        icon: CupertinoIcons.question_circle,
        label: 'Quizzes',
      ),
    );

    // Groups (Educator only)
    if (isEducator) {
      tabs.add(EducatorGroupsTab(user: widget.user));
      navItems.add(
        const ModernNavItem(icon: CupertinoIcons.person_3, label: 'Groups'),
      );
    }

    // Practice
    tabs.add(const PracticeTab());
    navItems.add(
      ModernNavItem(
        icon: CupertinoIcons.sparkles,
        label: 'Practice',
        selectedColor: Colors.teal.shade400,
      ),
    );

    // Subscription
    tabs.add(BrowseEducatorsTab(user: widget.user));
    navItems.add(
      const ModernNavItem(
        icon: CupertinoIcons.creditcard,
        label: 'Subscription',
      ),
    );

    // Profile
    tabs.add(ProfilePage(user: widget.user));
    navItems.add(ModernNavItem(icon: CupertinoIcons.person, label: username));

    if (_index >= tabs.length) {
      _index = 0;
    }

    final sidebar = AdminSidebar(
      selectedIndex: _index,
      userName: username,
      items: navItems,
      onItemSelected: (i) => setState(() => _index = i),
      onSignOut: () => AuthService.instance.signOut(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: AppColors.getMainGradient(context),
              ),
              child: Row(
                children: [
                  sidebar,
                  Expanded(
                    child: Column(
                      children: [
                        AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          surfaceTintColor: Colors.transparent,
                          actions: [
                            NotificationIconButton(
                              userId: widget.user.uid,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => NotificationsDialog(
                                    userId: widget.user.uid,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_index),
                              child: ResponsiveWrapper(child: tabs[_index]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Mobile View
        return Container(
          decoration: BoxDecoration(
            gradient: AppColors.getMainGradient(context),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                },
              ),
              actions: [
                NotificationIconButton(
                  userId: widget.user.uid,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          NotificationsDialog(userId: widget.user.uid),
                    );
                  },
                ),
              ],
            ),
            drawer: Drawer(child: sidebar),
            body: ResponsiveWrapper(child: tabs[_index]),
          ),
        );
      },
    );
  }
}

