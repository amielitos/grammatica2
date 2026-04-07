import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'notification_widgets.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User user;
  final Map<String, dynamic> userData;
  final VoidCallback onNotificationTap;
  final VoidCallback? onLogoTap;
  final VoidCallback? onProfileTap;

  const CustomAppBar({
    super.key,
    required this.user,
    required this.userData,
    required this.onNotificationTap,
    this.onLogoTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final String fullName = userData['username'] ?? userData['full_name'] ?? user.displayName ?? 'User';
    final String profileImageUrl = userData['photoUrl'] ?? userData['profile_image_url'] ?? user.photoURL ?? '';
    final screenWidth = MediaQuery.of(context).size.width;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF333333) : Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: isDark ? Colors.white : AppColors.textPrimary, size: 32),
        onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      ),
      toolbarHeight: 80,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            // Logo Image
            GestureDetector(
              onTap: onLogoTap,
              child: Image.asset('assets/logotext.png', height: 28),
            ),
            const Spacer(),
            // Middle Links (Hide on mobile phones to prevent overflow)
            if (screenWidth > 800) ...[
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All About Grammatica is coming soon!')),
                  );
                },
                child: Text(
                  'All About Grammatica',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1D1B20),
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("FAQ's is coming soon!")),
                  );
                },
                child: Text(
                  "FAQ's",
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1D1B20),
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
      actions: [
        // User Name (Hide on very small screens)
        if (screenWidth > 600)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                fullName,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        
        // Profile Icon
        GestureDetector(
          onTap: onProfileTap,
          child: Center(
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
              child: profileImageUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Notification Bell
        NotificationIconButton(
          userId: user.uid,
          onTap: onNotificationTap,
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80.0);
}
