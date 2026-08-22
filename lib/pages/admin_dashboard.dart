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

import '../services/database_service.dart';

import '../services/notification_service.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
import 'admin/validator_dashboard_tab.dart';
import 'admin/educator_dashboard_tab.dart';
import 'admin/admin_landing_settings_tab.dart';

import 'dart:async';

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
  int _initialValidationTabIndex = 0;
  int? _initialPracticeSubTab;
  bool _initialPracticeShowEditor = false;
  Lesson? _editingLesson;
  int _editingLessonTabIndex = 0;
  StreamSubscription? _notifSubscription;
  final Set<String> _notifiedIds = {};

  @override
  void initState() {
    super.initState();
    _index = _persistedIndex;
    _setupNotificationListener();

    // Trigger daily lesson reminders for educators
    if (widget.role == UserRole.educator) {
      NotificationService.instance.sendDailyLessonReminders(widget.user.uid);
    }
  }

  void _setupNotificationListener() {
    _notifSubscription?.cancel();
    _notifSubscription = NotificationService.instance
        .streamNotifications(widget.user.uid)
        .listen((notifs) {
          if (!mounted) return;
          final unread = notifs.where((n) => !n.isRead).toList();
          for (var n in unread) {
            if (!_notifiedIds.contains(n.id)) {
              _notifiedIds.add(n.id);
              // SnackBars removed as per user preference (prefers relying on red dot icon)
            }
          }
        });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _showEditLessonModal(BuildContext context, Lesson lesson, int tabIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Edit Lesson: ${lesson.title}'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: AdminLessonsTab(
            initialLesson: lesson,
            initialTabIndex: tabIndex,
            onReset: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

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

    if (isValidator) {
      tabs.add(
        ValidatorDashboardTab(
          onReviewRequests: (subIndex) => setState(() {
            _index = 1;
            _initialValidationTabIndex = subIndex;
          }),
        ),
      );
      navItems.add(
        const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'),
      );

      tabs.add(
        AdminValidationTab(
          key: ValueKey('validation_$_initialValidationTabIndex'),
          role: widget.role,
          initialTabIndex: _initialValidationTabIndex,
        ),
      );
      navItems.add(
        const ModernNavItem(icon: Icons.verified_user, label: 'Validation'),
      );
    } else {
      // 0: Dashboard (Educator)
      if (isEducator) {
        tabs.add(
          EducatorDashboardTab(
            userData: widget.userData,
            onTabChange: (i) {
              setState(() {
                _initialPracticeSubTab = null;
                _initialPracticeShowEditor = false;
                _index = i;
              });
            },
          ),
        );
        navItems.add(
          const ModernNavItem(icon: Icons.dashboard, label: 'Dashboard'),
        );
      }

      // 0: Users (Admin only)
      if (isAdmin) {
        tabs.add(const AdminUsersTab());
        navItems.add(
          const ModernNavItem(icon: Icons.people, label: 'User Management'),
        );
      }

      // Validation (Super Admin only - Validators handled above)
      if (widget.role == UserRole.superadmin) {
        tabs.add(
          AdminValidationTab(
            key: ValueKey('validation_$_initialValidationTabIndex'),
            role: widget.role,
            initialTabIndex: _initialValidationTabIndex,
          ),
        );
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
            initialTabIndex: _editingLessonTabIndex,
            onReset: () => setState(() {
              _editingLesson = null;
              _editingLessonTabIndex = 0;
            }),
          ),
        );
        navItems.add(
          const ModernNavItem(icon: Icons.edit_document, label: 'Contents'),
        );
      }

      // Lessons List / Content (Admin / Educator)
      tabs.add(
        LessonsListTab(
          onEdit: (l) {
            if (isEducator) {
              _showEditLessonModal(context, l, 0);
            } else if (manageLessonsIndex != null) {
              setState(() {
                _editingLesson = l;
                _editingLessonTabIndex = 0;
                _index = manageLessonsIndex!;
              });
            }
          },
          onEditQuiz: (l) {
            if (isEducator) {
              _showEditLessonModal(context, l, 1);
            } else if (manageLessonsIndex != null) {
              setState(() {
                _editingLesson = l;
                _editingLessonTabIndex = 1; // Show Quizzes tab
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

      // Practice (Admin only) or English Assessment (Educator)
      if (isAdmin) {
        tabs.add(const PracticeTab());
        navItems.add(
          const ModernNavItem(icon: Icons.auto_awesome, label: 'Practice'),
        );

        // Landing Page Settings (Admin only)
        tabs.add(const AdminLandingSettingsTab());
        navItems.add(
          const ModernNavItem(icon: Icons.web_rounded, label: 'Site Settings'),
        );
      } else if (isEducator) {
        tabs.add(
          PracticeTab(
            key: ValueKey(
              'practice_${_initialPracticeSubTab}_$_initialPracticeShowEditor',
            ),
            initialSubTab: _initialPracticeSubTab,
            initialShowEditor: _initialPracticeShowEditor,
          ),
        );
        navItems.add(
          const ModernNavItem(
            icon: Icons.auto_awesome,
            label: 'Practice',
          ),
        );
      }

      // AI Studio has been migrated to Content and Practice tabs
      // AI Studio (Removed)

      if (!isEducator) {
        tabs.add(BrowseEducatorsTab(user: widget.user));
        navItems.add(
          const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
        );
      }
    }

    // Profile (All)
    tabs.add(ProfilePage(user: widget.user));
    navItems.add(ModernNavItem(icon: Icons.person, label: username));

    if (_index >= tabs.length) {
      _index = 0;
    }

    // We build the navigation items for the drawer and dashboard

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          final profileTabIndex = navItems.indexWhere(
            (item) => item.icon == Icons.person,
          );
          if (profileTabIndex != -1) {
            setState(() {
              _index = profileTabIndex;
            });
          }
        },
      ),
      drawer: UniversalDrawer(
        user: widget.user,
        userData: widget.userData,
        currentIndex: _index,
        onTap: (i) {
          setState(() {
            _initialPracticeSubTab = null;
            _initialPracticeShowEditor = false;
            _index = i;
            _persistedIndex = i;
          });
        },
      ),
      body: IndexedStack(index: _index, children: tabs),
    );
  }
}
