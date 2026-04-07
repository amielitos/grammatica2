import 'package:flutter/material.dart';
import 'modern_bottom_nav.dart'; // For ModernNavItem

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String userName;
  final List<ModernNavItem> items;
  final VoidCallback onSignOut;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userName,
    required this.items,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 250,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Modern Header with Logos
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', height: 36),
                  const SizedBox(width: 8),
                  Image.asset('assets/logotext.png', height: 26),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                return Container(
                  color: isSelected ? primaryColor : Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected ? Colors.white : primaryColor,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      // Close drawer if it's open (mobile)
                      if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                        Navigator.pop(context);
                      }
                      onItemSelected(index);
                    },
                  ),
                );
              },
            ),
          ),
          Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(
              'Sign Out',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: onSignOut,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
