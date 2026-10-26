import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'notification_widgets.dart';
import '../pages/settings_page.dart';
import '../pages/home_page.dart';
import '../pages/admin_dashboard.dart';
import '../services/auth_service.dart';
import 'universal_drawer.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User user;
  final Map<String, dynamic>? userData;
  final VoidCallback onNotificationTap;
  final VoidCallback? onLogoTap;
  final VoidCallback? onProfileTap;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.user,
    this.userData,
    required this.onNotificationTap,
    this.onLogoTap,
    this.onProfileTap,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data() ?? userData ?? {};
        final firstName = (liveData['first_name'] as String?)?.trim() ?? '';
        final middleName = (liveData['middle_name'] as String?)?.trim() ?? '';
        final lastName = (liveData['last_name'] as String?)?.trim() ?? '';
        final computedName = [firstName, middleName, lastName].where((s) => s.isNotEmpty).join(' ');
        final String fullName = computedName.isNotEmpty
            ? computedName
            : ((liveData['full_name'] as String?)?.trim().isNotEmpty == true)
                ? (liveData['full_name'] as String).trim()
                : ((liveData['name'] as String?)?.trim().isNotEmpty == true)
                    ? (liveData['name'] as String).trim()
                    : (user.displayName != null && user.displayName!.trim().isNotEmpty)
                        ? user.displayName!.trim()
                        : ((liveData['username'] as String?)?.trim().isNotEmpty == true)
                            ? (liveData['username'] as String).trim()
                            : ((user.email != null && user.email!.contains('@'))
                                ? user.email!.split('@')[0]
                                : 'User');
        final String profileImageUrl = liveData['photoUrl'] ?? liveData['profile_image_url'] ?? user.photoURL ?? '';

        return AppBar(
          backgroundColor: isDark ? const Color(0xFF333333) : Colors.white,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      shape: Border(
        bottom: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      toolbarHeight: 70,
      title: SizedBox(
        width: double.infinity,
        height: 70,
        child: Stack(
          children: [

            
            // Left Group: Burger + Logo
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showBackButton)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87, size: 28),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  IconButton(
                    icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87, size: 28),
                    onPressed: () => _openDrawer(context),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () {
                        AdminDashboard.resetToDashboard();
                        HomePage.resetToDashboard();
                        if (onLogoTap != null) {
                          onLogoTap!();
                        }
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Image.asset('assets/logotext.png', height: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Right Group: Profile Info
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (screenWidth > 600)
                      PopupMenuButton<String>(
                        offset: const Offset(0, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isDark ? const Color(0xFF333333) : Colors.white,
                        onSelected: (value) {
                          if (value == 'profile') {
                            onProfileTap?.call();
                          } else if (value == 'settings') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsPage(user: user),
                              ),
                            );
                          } else if (value == 'logout') {
                            AuthService.instance.confirmAndSignOut(context);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                const SizedBox(width: 12),
                                Text('My Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Row(
                              children: [
                                Icon(Icons.settings_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                const SizedBox(width: 12),
                                Text('Settings', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 20, color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 12),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (screenWidth > 600)
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary,
                              backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                              onBackgroundImageError: profileImageUrl.isNotEmpty ? (exception, stackTrace) {} : null,
                              child: profileImageUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 16) : null,
                            ),
                            Icon(Icons.keyboard_arrow_down, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                          ],
                        ),
                      ),
                    const SizedBox(width: 16),
                    NotificationIconButton(
                      userId: user.uid,
                      onTap: onNotificationTap,
                    ),
                  ],
                ),
              ),
            ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _openDrawer(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) {
      scaffold.openDrawer();
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Drawer',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: UniversalDrawer(
            user: user,
            userData: userData ?? const {},
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80.0);
}
