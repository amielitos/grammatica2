import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';
import '../../widgets/rainbow_background.dart';
import '../../theme/app_colors.dart';
import 'admin/admin_users_tab.dart';
import 'admin/admin_lessons_tab.dart';
import 'admin/admin_quizzes_tab.dart';

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
    return RainbowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService.instance.currentUser != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(AuthService.instance.currentUser!.uid)
                      .snapshots()
                : null,
            builder: (context, snap) {
              final data = snap.data?.data();
              final user = AuthService.instance.currentUser;
              final username = (data?['username'] ?? user?.email ?? 'Admin')
                  .toString();
              return Text(
                'Admin Dashboard — $username',
                style: const TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: [
                const AdminUsersTab(),
                const AdminLessonsTab(),
                const AdminQuizzesTab(),
                ProfilePage(user: AuthService.instance.currentUser!),
              ],
            ),
            if (_switching) ...[
              const ModalBarrier(dismissible: false, color: Colors.black12),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.glassWhite,
            indicatorColor: AppColors.rainbow.violet,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService.instance.currentUser != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(AuthService.instance.currentUser!.uid)
                      .snapshots()
                : null,
            builder: (context, snap) {
              final data = snap.data?.data();
              final username =
                  (data?['username'] as String?)?.split(' ').first ?? 'Profile';
              return NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) async {
                  setState(() => _switching = true);
                  await Future.delayed(const Duration(milliseconds: 250));
                  if (!mounted) return;
                  setState(() {
                    _index = i;
                    _switching = false;
                  });
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(CupertinoIcons.person_2),
                    selectedIcon: Icon(CupertinoIcons.person_2_fill),
                    label: 'Users',
                  ),
                  const NavigationDestination(
                    icon: Icon(CupertinoIcons.book),
                    selectedIcon: Icon(CupertinoIcons.book_fill),
                    label: 'Lessons',
                  ),
                  const NavigationDestination(
                    icon: Icon(CupertinoIcons.question_circle),
                    selectedIcon: Icon(CupertinoIcons.question_circle_fill),
                    label: 'Quizzes',
                  ),
                  NavigationDestination(
                    icon: const Icon(CupertinoIcons.person),
                    selectedIcon: const Icon(CupertinoIcons.person_fill),
                    label: username,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
