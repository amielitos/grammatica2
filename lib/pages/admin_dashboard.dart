import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_page.dart';
import 'admin/admin_users_tab.dart';
import 'admin/admin_lessons_tab.dart';
import 'admin/lessons_list_tab.dart';
import 'admin/admin_validation_tab.dart';
import '../../services/role_service.dart';
import '../widgets/modern_bottom_nav.dart';
import 'browse_educators_tab.dart';
import 'admin/educator_groups_tab.dart';
import 'practice_tab.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/responsive_wrapper.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/design_ornaments.dart';
import '../widgets/custom_app_bar.dart';
import '../main.dart';
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
  static int _persistedIndex = 0;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _persistedIndex;

    // Trigger daily lesson reminders for educators
    if (widget.role == UserRole.educator) {
      NotificationService.instance.sendDailyLessonReminders(widget.user.uid);
    }
  }

  Lesson? _editingLesson;

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        widget.role == UserRole.admin || widget.role == UserRole.superadmin;
    final isEducator = widget.role == UserRole.educator;
    final isValidator = widget.role == UserRole.validator;
    final username =
        (widget.userData['username'] as String?)?.split(' ').first ?? 'Profile';

    final List<Widget> tabs = [];
    final List<ModernNavItem> navItems = [];

    // Define tabs and nav items based on roles
    if (isValidator) {
      // Validators: Lessons, Validation, Profile
      tabs.add(
        LessonsListTab(
          onEdit: (l) {
            // Validators can't edit in Manage Lessons tab as they don't have it
          },
        ),
      );
      navItems.add(const ModernNavItem(icon: Icons.book, label: 'Lessons'));

      tabs.add(AdminValidationTab(role: widget.role));
      navItems.add(
        const ModernNavItem(icon: Icons.verified_user, label: 'Validation'),
      );

      // Practice & Subscription
      tabs.add(const PracticeTab());
      navItems.add(
        const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'),
      );

      tabs.add(BrowseEducatorsTab(user: widget.user));
      navItems.add(
        const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
      );
    } else {
      // 0: Users (Admin only)
      if (isAdmin) {
        tabs.add(const AdminUsersTab());
        navItems.add(const ModernNavItem(icon: Icons.people, label: 'Users'));
      }

      // Validation (Super Admin only - Validators handled above)
      if (widget.role == UserRole.superadmin) {
        tabs.add(AdminValidationTab(role: widget.role));
        navItems.add(
          const ModernNavItem(icon: Icons.verified_user, label: 'Validation'),
        );
      }

      // Manage Lessons (Admin / Educator only)
      int? manageLessonsIndex;
      if (isAdmin || isEducator) {
        manageLessonsIndex = tabs.length;
        tabs.add(
          AdminLessonsTab(
            initialLesson: _editingLesson,
            onReset: () => setState(() => _editingLesson = null),
          ),
        );
        navItems.add(
          const ModernNavItem(
            icon: Icons.edit_document,
            label: 'Contents',
          ),
        );
      }

      // Lessons List / Content (Admin / Educator)
      tabs.add(
        LessonsListTab(
          onEdit: (l) {
            if (manageLessonsIndex != null) {
              setState(() {
                _editingLesson = l;
                _index = manageLessonsIndex!;
              });
            }
          },
        ),
      );
      navItems.add(const ModernNavItem(icon: Icons.book, label: 'Lessons'));

      // Premium Group (Educator & Admin)
      if (isEducator || isAdmin) {
        tabs.add(EducatorGroupsTab(user: widget.user));
        navItems.add(
          const ModernNavItem(icon: Icons.group, label: 'Premium Group'),
        );
      }

      // Practice & Subscription
      tabs.add(const PracticeTab());
      navItems.add(
        const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'),
      );

      tabs.add(BrowseEducatorsTab(user: widget.user));
      navItems.add(
        const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
      );
    }

    // Profile (All)
    tabs.add(ProfilePage(user: widget.user));
    navItems.add(ModernNavItem(icon: Icons.person, label: username));

    if (_index >= tabs.length) {
      _index = 0;
    }

    final sidebar = AdminSidebar(
      selectedIndex: _index,
      userName: username,
      items: navItems,
      onItemSelected: (i) {
        setState(() {
          _index = i;
          _persistedIndex = i;
          // If switching away from Manage Lessons, maybe we don't clear?
          // Actually, let's keep it until they explicitly cancel or save.
        });
      },
      onSignOut: () => AuthService.instance.signOut(),
    );

    final currentIcon = navItems[_index].icon;
    String bgPath = 'assets/dashboardbg.png';
    if (currentIcon == Icons.auto_awesome) {
      bgPath = 'assets/practicebg.png';
    } else if (currentIcon == Icons.person) {
      bgPath = 'assets/profilebg.png';
    } else if (currentIcon == Icons.credit_card) {
      bgPath = 'assets/subscriptionbg.png';
    } else if (currentIcon == Icons.book || currentIcon == Icons.edit_document) {
      bgPath = 'assets/dashboardbg.png';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        user: widget.user,
        userData: widget.userData,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
        onLogoTap: () {
          setState(() {
            _index = 0;
          });
        },
        onProfileTap: () {
          final profileTabIndex = navItems.indexWhere((item) => item.icon == Icons.person);
          if (profileTabIndex != -1) {
            setState(() {
              _index = profileTabIndex;
            });
          }
        },
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF222222) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        width: 250,
        child: sidebar,
      ),
      body: BackgroundWrapper(
        imageAssetPath: bgPath,
        child: ResponsiveWrapper(
          child: IndexedStack(index: _index, children: tabs),
        ),
      ),
    );
  }
}
