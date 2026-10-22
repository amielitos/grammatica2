import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Result object returned by [showContentDenialDialog].
class ContentDenialResult {
  final String category;
  final String explanation;

  const ContentDenialResult({
    required this.category,
    required this.explanation,
  });
}

/// Overhauled Content Denial & Deletion Dialog for both Validators and Admins.
///
/// Features:
/// 1. Category selection: "Non-Educational", "Promotes Gambling", "Sexual Content", "Other".
/// 2. Detailed explanation text box with a mandatory minimum of 30 characters.
/// 3. Dynamic live character counter and validation indicator.
/// 4. Author notification guarantee.
Future<ContentDenialResult?> showContentDenialDialog(
  BuildContext context, {
  required String contentTitle,
  String? authorName,
  bool isPermanentDeletion = false,
}) {
  return showDialog<ContentDenialResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ContentDenialDialog(
      contentTitle: contentTitle,
      authorName: authorName,
      isPermanentDeletion: isPermanentDeletion,
    ),
  );
}

class _ContentDenialDialog extends StatefulWidget {
  final String contentTitle;
  final String? authorName;
  final bool isPermanentDeletion;

  const _ContentDenialDialog({
    required this.contentTitle,
    this.authorName,
    required this.isPermanentDeletion,
  });

  @override
  State<_ContentDenialDialog> createState() => _ContentDenialDialogState();
}

class _ContentDenialDialogState extends State<_ContentDenialDialog> {
  static const int _minCharLimit = 30;

  static const List<_CategoryItem> _categories = [
    _CategoryItem(
      label: 'Non-Educational',
      description: 'Irrelevant, spam, gibberish, or lacks pedagogical value',
      icon: Icons.school_outlined,
    ),
    _CategoryItem(
      label: 'Promotes Gambling',
      description: 'Contains betting, casinos, or gambling promotion',
      icon: Icons.casino_outlined,
    ),
    _CategoryItem(
      label: 'Sexual Content',
      description: 'Explicit, sexually suggestive, or inappropriate material',
      icon: Icons.explicit_rounded,
    ),
    _CategoryItem(
      label: 'Other',
      description: 'Violates platform safety rules or community guidelines',
      icon: Icons.shield_outlined,
    ),
  ];

  String _selectedCategory = 'Non-Educational';
  final TextEditingController _explanationController = TextEditingController();

  @override
  void dispose() {
    _explanationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textLength = _explanationController.text.trim().length;
    final isLengthValid = textLength >= _minCharLimit;
    final remainingChars = _minCharLimit - textLength;

    final primaryActionColor =
        widget.isPermanentDeletion ? const Color(0xFFD32F2F) : const Color(0xFFE05050);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Icon & Title ─────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryActionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.isPermanentDeletion
                            ? Icons.delete_forever_rounded
                            : Icons.block_rounded,
                        color: primaryActionColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isPermanentDeletion
                                ? 'Permanently Delete Lesson'
                                : 'Deny & Reject Content',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: "${widget.contentTitle}"',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryActionColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Warning Notification Notice ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The author will receive an official notification containing the category and explanation below.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Category Selection ──────────────────────────────────
                Text(
                  'VIOLATION CATEGORY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                ..._categories.map((cat) {
                  final isSelected = _selectedCategory == cat.label;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat.label),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryActionColor.withValues(alpha: 0.08)
                              : (isDark ? const Color(0xFF263346) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? primaryActionColor
                                : (isDark ? Colors.white12 : Colors.grey.shade200),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              cat.icon,
                              size: 20,
                              color: isSelected
                                  ? primaryActionColor
                                  : (isDark ? Colors.white70 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? primaryActionColor
                                          : (isDark ? Colors.white : AppColors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    cat.description,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? primaryActionColor : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: primaryActionColor,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // ── Detailed Explanation Field ──────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DETAILED EXPLANATION *',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      isLengthValid
                          ? '$textLength / $_minCharLimit min ✓'
                          : '$textLength / $_minCharLimit min ($remainingChars more required)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLengthValid ? Colors.green : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _explanationController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 4,
                  minLines: 3,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Provide a thorough explanation why this content had to be removed or denied (minimum 30 characters)...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF263346) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primaryActionColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Action Buttons ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: isLengthValid
                          ? () {
                              Navigator.pop(
                                context,
                                ContentDenialResult(
                                  category: _selectedCategory,
                                  explanation: _explanationController.text.trim(),
                                ),
                              );
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryActionColor,
                        disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        widget.isPermanentDeletion
                            ? Icons.delete_forever_rounded
                            : Icons.send_rounded,
                        size: 18,
                      ),
                      label: Text(
                        widget.isPermanentDeletion
                            ? 'Permanently Delete & Notify'
                            : 'Deny Content & Notify',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String label;
  final String description;
  final IconData icon;

  const _CategoryItem({
    required this.label,
    required this.description,
    required this.icon,
  });
}
