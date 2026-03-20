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
    final String fullName = userData['full_name'] ?? userData['username'] ?? 'User';
    final String profileImageUrl = userData['profile_image_url'] ?? '';
    final screenWidth = MediaQuery.of(context).size.width;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 28),
        onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      ),
      title: Row(
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
              child: const Text(
                'All About Grammatica',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 24),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("FAQ's is coming soon!")),
                );
              },
              child: const Text(
                "FAQ's",
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            const Spacer(),
          ],
        ],
      ),
      actions: [
        // User Name (Hide on very small screens)
        if (screenWidth > 600)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                fullName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
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
        
        const SizedBox(width: 8),
        
        // Notification Bell
        NotificationIconButton(
          userId: user.uid,
          onTap: onNotificationTap,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
