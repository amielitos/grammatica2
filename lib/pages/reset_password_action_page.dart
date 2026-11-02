import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

enum ResetPageStatus {
  verifying,
  ready,
  invalidCode,
  submitting,
  success,
}

class ResetPasswordActionPage extends StatefulWidget {
  final String oobCode;

  const ResetPasswordActionPage({
    super.key,
    required this.oobCode,
  });

  @override
  State<ResetPasswordActionPage> createState() =>
      _ResetPasswordActionPageState();
}

class _ResetPasswordActionPageState extends State<ResetPasswordActionPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ResetPageStatus _status = ResetPageStatus.verifying;
  String? _email;
  String? _errorMessage;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Real-time password requirement validations
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>~_\-+=]'));
  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text == _passwordController.text;

  int get _score {
    final pass = _passwordController.text;
    if (pass.isEmpty) return 0;
    int s = 0;
    if (_hasMinLength) s++;
    if (_hasUppercase) s++;
    if (_hasLowercase) s++;
    if (_hasDigit) s++;
    if (_hasSpecialChar) s++;
    return s;
  }

  String get _passwordStrength {
    if (_passwordController.text.isEmpty) return "";
    if (_score == 5) return "Strong";
    if (_score >= 3) return "Medium";
    return "Weak";
  }

  Color get _strengthColor {
    final strength = _passwordStrength;
    if (strength == "Strong") return const Color(0xFF16A34A);
    if (strength == "Medium") return Colors.orange;
    if (strength.contains("Weak")) return Colors.red;
    return Colors.grey;
  }

  bool get _isFormValid =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasDigit &&
      _hasSpecialChar &&
      _passwordsMatch;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _verifyCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() {
      _status = ResetPageStatus.verifying;
      _errorMessage = null;
    });

    try {
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(
        widget.oobCode,
      );
      if (!mounted) return;
      setState(() {
        _email = email;
        _status = ResetPageStatus.ready;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = ResetPageStatus.invalidCode;
        _errorMessage = e.message ??
            'This password reset link is invalid or has expired. Please request a new one.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = ResetPageStatus.invalidCode;
        _errorMessage = 'Failed to verify reset code: $e';
      });
    }
  }

  Future<void> _handlePasswordReset() async {
    if (!_isFormValid || _status == ResetPageStatus.submitting) return;

    setState(() {
      _status = ResetPageStatus.submitting;
      _errorMessage = null;
    });

    try {
      final newPassword = _passwordController.text.trim();
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: newPassword,
      );

      // Auto-unlock account if locked due to prior failed attempts
      if (_email != null && _email!.isNotEmpty) {
        try {
          await AuthService.instance.unlockAccount(_email!);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _status = ResetPageStatus.success;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = ResetPageStatus.ready;
        _errorMessage = e.message ?? 'Failed to update password. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = ResetPageStatus.ready;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _buildContent(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_status) {
      case ResetPageStatus.verifying:
        return _buildVerifyingState(isDark);
      case ResetPageStatus.invalidCode:
        return _buildInvalidCodeState(isDark);
      case ResetPageStatus.success:
        return _buildSuccessState(isDark);
      case ResetPageStatus.ready:
      case ResetPageStatus.submitting:
        return _buildFormState(isDark);
    }
  }

  Widget _buildVerifyingState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logotext.png', height: 40),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 20),
        Text(
          'Verifying reset link...',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildInvalidCodeState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logotext.png', height: 40),
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.link_off_rounded,
            color: Color(0xFFEF4444),
            size: 32,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Invalid or Expired Link',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _errorMessage ??
              'This password reset link is invalid or has expired. Please request a new link from the login page.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Back to Grammatica',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logotext.png', height: 40),
        const SizedBox(height: 24),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF10B981),
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Password Reset Successfully',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your account password has been updated. You can now log in with your new credentials.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Proceed to Sign In',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand Logo
        Center(child: Image.asset('assets/logotext.png', height: 38)),
        const SizedBox(height: 20),

        // Title
        Text(
          'Reset your password',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        // Target Email Pill
        if (_email != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.4)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  'for $_email',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Error message if any
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // New Password Input
        Text(
          'New Password',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Enter new password',
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _score / 5,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Strength: $_passwordStrength',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _strengthColor,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        // Confirm Password Input
        Text(
          'Confirm New Password',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Confirm new password',
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            prefixIcon: const Icon(Icons.lock_clock_outlined, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (_confirmPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _passwordsMatch ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 14,
                color: _passwordsMatch ? const Color(0xFF10B981) : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                _passwordsMatch ? "Passwords match" : "Passwords do not match",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _passwordsMatch ? const Color(0xFF10B981) : Colors.red,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Password Requirements Checklist
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Requirements',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),
              _buildRequirementRow('At least 8 characters', _hasMinLength, isDark),
              const SizedBox(height: 6),
              _buildRequirementRow(
                'At least 1 uppercase letter (A-Z)',
                _hasUppercase,
                isDark,
              ),
              const SizedBox(height: 6),
              _buildRequirementRow(
                'At least 1 lowercase letter (a-z)',
                _hasLowercase,
                isDark,
              ),
              const SizedBox(height: 6),
              _buildRequirementRow(
                'At least 1 number (0-9)',
                _hasDigit,
                isDark,
              ),
              const SizedBox(height: 6),
              _buildRequirementRow(
                'At least 1 special character',
                _hasSpecialChar,
                isDark,
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Allowed special characters: ! @ # \$ % ^ & * ( ) , . ? " : { } | < > ~ _ - + =',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _buildRequirementRow(
                'Passwords must match',
                _passwordsMatch,
                isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isFormValid && _status != ResetPageStatus.submitting)
                ? _handlePasswordReset
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFCBD5E1),
              disabledForegroundColor: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _status == ResetPageStatus.submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Save New Password',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Back to Login Link
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: Text(
              'Cancel and return to home',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementRow(String text, bool isMet, bool isDark) {
    final hasInput = _passwordController.text.isNotEmpty;
    final Color iconColor;
    final IconData iconData;

    if (isMet) {
      iconColor = const Color(0xFF10B981);
      iconData = Icons.check_circle_rounded;
    } else if (hasInput) {
      iconColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      iconData = Icons.circle_outlined;
    } else {
      iconColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
      iconData = Icons.circle_outlined;
    }

    return Row(
      children: [
        Icon(iconData, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
              color: isMet
                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }
}

