import 'package:flutter/material.dart';
import 'modern_bottom_nav.dart'; // For ModernNavItem class

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;
  final bool showProfileWarning;
  final bool isDrawer;

  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.showProfileWarning = false,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Grammatica',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = currentIndex == index;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Icon(
                        item.icon,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        onTap(index);
                        if (isDrawer) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
