import 'package:flutter/material.dart';

class ModernBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;
  final bool showProfileWarning;

  const ModernBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.showProfileWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: items
          .map(
            (e) => BottomNavigationBarItem(icon: Icon(e.icon), label: e.label),
          )
          .toList(),
    );
  }
}

class ModernNavItem {
  final IconData icon;
  final String label;

  const ModernNavItem({required this.icon, required this.label});
}
