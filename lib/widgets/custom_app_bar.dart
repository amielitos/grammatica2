import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'notification_widgets.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User user;
  final Map<String, dynamic>? userData;
  final VoidCallback onNotificationTap;
  final VoidCallback? onLogoTap;
  final VoidCallback? onProfileTap;

  const CustomAppBar({
    super.key,
    required this.user,
    this.userData,
    required this.onNotificationTap,
    this.onLogoTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final String fullName = userData?['username'] ?? userData?['full_name'] ?? user.displayName ?? 'User';
    final String profileImageUrl = userData?['photoUrl'] ?? userData?['profile_image_url'] ?? user.photoURL ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF333333) : Colors.white,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      shape: Border(
        bottom: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
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
                  IconButton(
                    icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87, size: 28),
                    onPressed: () {
                      final scaffold = Scaffold.maybeOf(context);
                      if (scaffold?.hasDrawer ?? false) {
                        scaffold?.openDrawer();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Menu is available on the main dashboard.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onLogoTap,
                    child: Image.asset('assets/logotext.png', height: 24),
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
                    GestureDetector(
                      onTap: onProfileTap,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                        child: profileImageUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 16) : null,
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
