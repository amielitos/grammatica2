import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'notification_widgets.dart';
import '../pages/settings_page.dart';
import '../services/auth_service.dart';

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
    final String fullName = userData?['username'] ?? userData?['full_name'] ?? user.displayName ?? 'User';
    final String profileImageUrl = userData?['photoUrl'] ?? userData?['profile_image_url'] ?? user.photoURL ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Only open drawer if we are not on a wide screen that already shows the sidebar
    
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
            // Middle Group: Links (Dead Center)
            if (screenWidth > 1100)
              Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavLink('All About Grammatica', isDark),
                    const SizedBox(width: 40),
                    _buildNavLink("FAQ's", isDark),
                  ],
                ),
              ),
            
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
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87, size: 28),
                      onPressed: () {
                        final scaffold = Scaffold.maybeOf(context);
                        scaffold?.openDrawer();
                      },
                    ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () {
                        if (onLogoTap != null) {
                          onLogoTap!();
                        } else {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        }
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
                          AuthService.instance.signOut();
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
                          if (screenWidth > 800)
                            Text(
                              fullName,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
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
  }

  Widget _buildNavLink(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80.0);
}
