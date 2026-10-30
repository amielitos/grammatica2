import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/feedback_service.dart';

class FeedbackDialog extends StatefulWidget {
  final User? user;
  final Map<String, dynamic>? userData;

  const FeedbackDialog({
    super.key,
    this.user,
    this.userData,
  });

  static Future<void> show(
    BuildContext context, {
    User? user,
    Map<String, dynamic>? userData,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FeedbackDialog(user: user, userData: userData),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCategory = 'General Feedback';
  int _rating = 5;
  bool _isSubmitting = false;
  String? _subjectError;
  String? _messageError;

  final List<String> _categories = [
    'General Feedback',
    'Feature Request',
    'Bug Report',
    'Lesson / Content Quality',
    'Other',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 5:
        return '5 - Excellent';
      case 4:
        return '4 - Very Good';
      case 3:
        return '3 - Average';
      case 2:
        return '2 - Needs Improvement';
      case 1:
        return '1 - Poor';
      default:
        return '$r Stars';
    }
  }

  Future<void> _handleSubmit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    bool hasError = false;
    setState(() {
      if (subject.isEmpty) {
        _subjectError = 'Subject is required';
        hasError = true;
      } else {
        _subjectError = null;
      }

      if (message.isEmpty) {
        _messageError = 'Feedback description is required';
        hasError = true;
      } else if (message.length < 5) {
        _messageError = 'Please provide at least 5 characters';
        hasError = true;
      } else {
        _messageError = null;
      }
    });

    if (hasError) return;

    setState(() => _isSubmitting = true);

    final uid = widget.user?.uid ?? widget.userData?['uid'] ?? 'guest';
    final email = widget.user?.email ?? widget.userData?['email'] ?? '';
    final username = widget.userData?['username'] ??
        widget.userData?['full_name'] ??
        widget.user?.displayName ??
        'Grammatica User';
    final role = (widget.userData?['role'] as String?)?.toUpperCase() ?? 'LEARNER';

    try {
      await FeedbackService.instance.submitFeedback(
        userId: uid,
        userEmail: email,
        userName: username,
        userRole: role,
        category: _selectedCategory,
        subject: subject,
        message: message,
        rating: _rating,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thank you! Your feedback has been received and forwarded to our team.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF81B655),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$e'.replaceAll('Exception: ', ''),
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF81B655);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSubColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final effectiveName = widget.userData?['username'] ??
        widget.userData?['full_name'] ??
        widget.user?.displayName ??
        'You';
    final effectiveEmail = widget.user?.email ?? widget.userData?['email'] ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.rate_review_rounded, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Your Feedback',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Help us improve Grammatica. Sent directly to ${FeedbackService.supportEmail}.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: textSubColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSubColor, size: 22),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submitting As Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Submitting as $effectiveName ($effectiveEmail)',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: textSubColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Selector
              Text.rich(
                TextSpan(
                  text: 'Feedback Category',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                  children: const [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: cardBg,
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(
                          cat,
                          style: GoogleFonts.inter(fontSize: 13.5, color: textColor),
                        ),
                      );
                    }).toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rating (1-5 stars)
              Text(
                'Satisfaction Rating',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      final isSelected = starValue <= _rating;
                      return InkWell(
                        onTap: _isSubmitting ? null : () => setState(() => _rating = starValue),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isSelected ? const Color(0xFFF59E0B) : textSubColor.withValues(alpha: 0.5),
                            size: 28,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ratingLabel(_rating),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Subject Input
              Text.rich(
                TextSpan(
                  text: 'Subject',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                  children: const [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectController,
                enabled: !_isSubmitting,
                onChanged: (_) {
                  if (_subjectError != null) setState(() => _subjectError = null);
                },
                decoration: InputDecoration(
                  hintText: 'Brief summary of your feedback',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: textSubColor.withValues(alpha: 0.6)),
                  errorText: _subjectError,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: GoogleFonts.inter(fontSize: 13.5, color: textColor),
              ),
              const SizedBox(height: 16),

              // Message Input
              Text.rich(
                TextSpan(
                  text: 'Feedback Description',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                  children: const [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                enabled: !_isSubmitting,
                maxLines: 5,
                minLines: 3,
                onChanged: (_) {
                  if (_messageError != null) setState(() => _messageError = null);
                },
                decoration: InputDecoration(
                  hintText: 'Describe your idea, report an issue, or tell us what you think...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: textSubColor.withValues(alpha: 0.6)),
                  errorText: _messageError,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: GoogleFonts.inter(fontSize: 13.5, color: textColor),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSubColor,
                      side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _isSubmitting ? 'Sending...' : 'Submit Feedback',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

