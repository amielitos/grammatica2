import 'package:flutter/material.dart';
import 'modern_bottom_nav.dart'; // For ModernNavItem class
import '../theme/app_colors.dart';
import '../services/auth_service.dart';

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;
  final bool showProfileWarning;
  final bool isDrawer;
  final VoidCallback? onSignOut;

  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.showProfileWarning = false,
    this.isDrawer = false,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF222222) : Colors.white,
      child: SizedBox(
        width: 250,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: Image.asset(
                'assets/logotext.png',
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
            Divider(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              indent: 16,
              endIndent: 16,
              height: 1,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = currentIndex == index;
                  return Material(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                      leading: Icon(
                        item.icon,
                        color: isSelected ? Colors.white : AppColors.primary,
                        size: 28,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white70 : Colors.grey.shade600),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        if (isDrawer && (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
                          Navigator.pop(context);
                        } else if (isDrawer && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        onTap(index);
                      },
                    ),
                  );
                },
              ),
            ),
            Divider(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              height: 1,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                if (isDrawer) {
                  Navigator.pop(context);
                }
                if (onSignOut != null) {
                  onSignOut!();
                } else {
                  AuthService.instance.signOut();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
    );
  }
}
