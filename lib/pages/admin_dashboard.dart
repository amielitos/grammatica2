import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';
import '../../theme/app_colors.dart';
import 'admin/admin_users_tab.dart';
import 'admin/admin_lessons_tab.dart';
import 'admin/admin_quizzes_tab.dart';

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
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AuthService.instance.currentUser != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(AuthService.instance.currentUser!.uid)
                    .snapshots()
              : null,
          builder: (context, snap) {
            return Text(
              'Grammatica',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
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
      bottomNavigationBar:
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                items: [
                  const ModernNavItem(
                    icon: CupertinoIcons.person_2,
                    label: 'Users',
                  ),
                  const ModernNavItem(
                    icon: CupertinoIcons.book,
                    label: 'Lessons',
                  ),
                  const ModernNavItem(
                    icon: CupertinoIcons.question_circle,
                    label: 'Quizzes',
                  ),
                  ModernNavItem(icon: CupertinoIcons.person, label: username),
                ],
              );
            },
          ),
    );
  }
}
