import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CenterNoticeDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final String buttonText;
  final bool? isSuccess;

  const CenterNoticeDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.iconColor = const Color(0xFF81B655),
    this.buttonText = 'Got it',
    this.isSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    String title = 'Notice',
    required String message,
    IconData? icon,
    Color? iconColor,
    String buttonText = 'Got it',
    bool? isSuccess,
  }) {
    IconData resolvedIcon = icon ??
        (isSuccess == true
            ? Icons.check_circle_outline_rounded
            : (isSuccess == false
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded));

    Color resolvedColor = iconColor ??
        (isSuccess == true
            ? const Color(0xFF81B655)
            : (isSuccess == false ? Colors.redAccent : const Color(0xFF81B655)));

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CenterNoticeDialog(
        title: title,
        message: message,
        icon: resolvedIcon,
        iconColor: resolvedColor,
        buttonText: buttonText,
        isSuccess: isSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 10,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 30),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    buttonText,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
