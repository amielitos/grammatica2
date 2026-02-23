import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final selectedColor = isDark ? Colors.white : AppColors.primaryGreen;
    final unselectedColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      width: 250,
      height: double.infinity,
      color: backgroundColor,
      child: Column(
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Row(
              children: [
                // You can replace this with your actual logo asset if available
                Icon(
                  Icons.auto_stories,
                  size: 32,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 12),
                Text(
                  'Grammatica',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = currentIndex == index;
                final itemColor = isSelected ? selectedColor : unselectedColor;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        onTap(index);
                        if (isDrawer) {
                          Navigator.pop(context); // Close drawer on selection
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: isSelected
                            ? BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(item.icon, color: itemColor, size: 24),
                                if (index == items.length - 1 &&
                                    showProfileWarning)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: itemColor,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // User Profile / Footer could go here
          if (!isDrawer) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '© 2026 Grammatica',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
