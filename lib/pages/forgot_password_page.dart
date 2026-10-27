import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/design_ornaments.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _step = 0; // 0: Enter Email, 1: Email Sent Success

  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _targetEmail;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onInputChanged);
    _emailController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool get _isEmailValid {
    final email = _emailController.text.trim();
    return email.isNotEmpty && email.contains('@') && email.contains('.');
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 1) {
          _cooldownSeconds--;
        } else {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: error ? const Color(0xFFE11D48) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (!_isEmailValid) {
      _showSnack('Please enter a valid email address.', error: true);
      return;
    }
    setState(() => _isSending = true);
    try {
      // Send official Firebase Auth password reset email directly
      await AuthService.instance.sendPasswordResetEmail(email);

      if (mounted) {
        setState(() {
          _isSending = false;
          _targetEmail = email;
          _step = 1;
        });
        _startCooldown();
        _showSnack('Password reset link sent to your email!');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showSnack(e.message ?? 'Failed to send reset link.', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showSnack('Something went wrong. Please try again.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWrapper(
        imageAssetPath: 'assets/signinbgs.png',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBanner(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStepper(),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _step == 1 ? _buildSuccessStep() : _buildEmailStep(),
                          ),
                        ],
                      ),
                    ),
                    _buildBackLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _step == 1 ? 'Check Your Email' : 'Recover Account';
    final sub = _step == 1
        ? 'We sent a password reset link to your email.'
        : 'Enter your email to receive a password reset link.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF81B655),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Image.asset(
                'assets/logotext.png',
                height: 24,
                errorBuilder: (_, _, _) => const Text(
                  'Grammatica',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF81B655)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: [
        // Step 1 Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF81B655),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.email_outlined, color: Colors.white, size: 16),
          ),
        ),
        // Connecting Line
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 3,
            decoration: BoxDecoration(
              color: _step == 1 ? const Color(0xFF81B655) : Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Step 2 Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _step == 1 ? const Color(0xFF81B655) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _step == 1 ? const Color(0xFF81B655) : Colors.grey[300]!, width: 2),
          ),
          child: Center(
            child: Icon(Icons.mark_email_read_outlined, color: _step == 1 ? Colors.white : Colors.grey[400], size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStep() {
    final emailText = _emailController.text.trim();
    final showEmailFeedback = emailText.isNotEmpty;

    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the email address registered with your Grammatica account. We will send you an official link to reset your password directly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 20),
        _field(
          controller: _emailController,
          hint: 'Recovery Email *',
          icon: Icons.alternate_email_rounded,
          keyboard: TextInputType.emailAddress,
          isValid: showEmailFeedback ? _isEmailValid : null,
        ),
        if (showEmailFeedback) ...[
          const SizedBox(height: 6),
          _validationHint(
            isValid: _isEmailValid,
            text: _isEmailValid ? '✓ Valid email address' : 'Enter a valid email address (e.g. name@domain.com)',
          ),
        ],
        const SizedBox(height: 24),
        _btn(
          label: 'Send Reset Link',
          isLoading: _isSending,
          enabled: _isEmailValid,
          onTap: _sendResetLink,
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFF0FDF4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded, size: 52, color: Color(0xFF81B655)),
        ),
        const SizedBox(height: 20),
        const Text(
          'Reset Link Sent!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a password reset link to\n'),
              TextSpan(
                text: _targetEmail ?? '',
                style: const TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '.\n\nPlease open the link in your email to set a new password.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _btn(
          label: 'Back to Sign In',
          isLoading: false,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Didn't get the email? ", style: TextStyle(fontSize: 13, color: Colors.grey)),
            if (_cooldownSeconds > 0)
              Text("${_cooldownSeconds}s", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey))
            else
              InkWell(
                onTap: _sendResetLink,
                child: const Text('Resend Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF81B655))),
              ),
          ],
        ),
      ],
    );
  }

  Widget _validationHint({required bool isValid, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: isValid ? const Color(0xFF10B981) : const Color(0xFFE11D48),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isValid ? const Color(0xFF10B981) : const Color(0xFFE11D48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool? isValid,
    TextInputType? keyboard,
  }) {
    Color borderColor = const Color(0xFFE2E8F0);
    Color iconColor = const Color(0xFF94A3B8);

    if (isValid != null) {
      if (isValid) {
        borderColor = const Color(0xFF10B981);
        iconColor = const Color(0xFF10B981);
      } else {
        borderColor = const Color(0xFFF43F5E);
        iconColor = const Color(0xFFF43F5E);
      }
    }

    final bool isRequired = hint.trim().endsWith('*');
    final String cleanHint = isRequired
        ? hint.replaceAll(RegExp(r'\s*\*'), '').trim()
        : hint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isValid == true ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isValid != null ? 1.8 : 1.0),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: iconColor, size: 18),
          suffixIcon: isValid != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 18,
                    color: isValid ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                  ),
                )
              : null,
          hintText: isRequired ? null : hint,
          label: isRequired
              ? Text.rich(
                  TextSpan(
                    text: cleanHint,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.normal),
                    children: const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.normal),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _btn({
    required String label,
    required bool isLoading,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (isLoading || !enabled) ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF81B655) : const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: enabled ? 2 : 0,
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: TextStyle(color: enabled ? Colors.white : const Color(0xFF94A3B8), fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBackLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
        label: const Text('Back to Sign In', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
