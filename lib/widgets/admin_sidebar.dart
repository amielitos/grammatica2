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
    
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : Colors.white,
      ),
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
                  final isSelected = selectedIndex == index;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7CB342) : Colors.transparent,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                      leading: Icon(
                        item.icon,
                        color: isSelected ? Colors.white : const Color(0xFF7CB342),
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
                      selected: isSelected,
                      onTap: () {
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
            Divider(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              indent: 16,
              endIndent: 16,
              height: 1,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error, size: 28),
              title: Text(
                'Sign Out',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: onSignOut,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
