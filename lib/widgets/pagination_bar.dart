import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Reusable, responsive pagination bar matching Grammatica design language.
class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final String itemName;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.itemName = 'items',
  });

  int get totalPages => totalItems == 0 ? 1 : (totalItems / pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    if (totalItems <= pageSize) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final startIndex = (currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: isMobile
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navBtn(
                  icon: Icons.chevron_left_rounded,
                  label: 'Prev',
                  enabled: currentPage > 1,
                  onTap: () => onPageChanged(currentPage - 1),
                  isDark: isDark,
                ),
                Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF81B655),
                  ),
                ),
                _navBtn(
                  icon: Icons.chevron_right_rounded,
                  label: 'Next',
                  enabled: currentPage < totalPages,
                  onTap: () => onPageChanged(currentPage + 1),
                  isDark: isDark,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81B655).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pageSize per page',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF81B655),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Showing ${startIndex + 1}–$endIndex of $totalItems $itemName',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _navBtn(
                      icon: Icons.chevron_left_rounded,
                      label: 'Previous',
                      enabled: currentPage > 1,
                      onTap: () => onPageChanged(currentPage - 1),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    ..._buildPageNumbers(totalPages, isDark),
                    const SizedBox(width: 6),
                    _navBtn(
                      icon: Icons.chevron_right_rounded,
                      label: 'Next',
                      enabled: currentPage < totalPages,
                      onTap: () => onPageChanged(currentPage + 1),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages, bool isDark) {
    final List<Widget> widgets = [];
    final int start = (currentPage - 2).clamp(1, totalPages);
    final int end = (currentPage + 2).clamp(1, totalPages);

    if (start > 1) {
      widgets.add(_pageNumberBtn(1, isDark));
      if (start > 2) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('…', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
        ));
      }
    }

    for (int p = start; p <= end; p++) {
      widgets.add(_pageNumberBtn(p, isDark));
    }

    if (end < totalPages) {
      if (end < totalPages - 1) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('…', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
        ));
      }
      widgets.add(_pageNumberBtn(totalPages, isDark));
    }

    return widgets;
  }

  Widget _pageNumberBtn(int page, bool isDark) {
    final isSelected = page == currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPageChanged(page),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF81B655) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF81B655)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            '$page',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isDark ? Colors.white70 : AppColors.textPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
