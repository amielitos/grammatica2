import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/design_ornaments.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _step = 0; // 0: Email input, 1: Success confirmation

  // ─── Step 0 ───────────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _targetEmail;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
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

  // ─── Logic ────────────────────────────────────────────────────────────────
  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Please enter a valid email address.', error: true);
      return;
    }
    setState(() => _isSending = true);
    try {
      // Use Firebase Authentication's built-in password reset
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // Auto-unlock account if it was locked due to failed login attempts
      await AuthService.instance.unlockAccount(email);

      if (mounted) {
        setState(() {
          _isSending = false;
          _targetEmail = email;
        });
        _goToStep(1);
        _showSnack('Password reset email sent!');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'No account found with this email address.';
            break;
          case 'invalid-email':
            message = 'Please enter a valid email address.';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Please try again later.';
            break;
          default:
            message = 'Something went wrong. Please try again.';
        }
        _showSnack(message, error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showSnack('Something went wrong. Please try again.', error: true);
      }
    }
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
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20))],
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
                            height: 300,
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [_buildEmailStep(), _buildSuccessStep()],
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
    const titles = ['Recover Account', 'Check Your Email'];
    const subs = ['Secure your access to Grammatica.', 'We\'ve sent you a password reset link.'];
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE2F3D9), Color(0xFFF9FFF6)]),
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logotext.png', height: 26, errorBuilder: (_, _, _) => const Icon(Icons.lock, color: Color(0xFF81B655))),
          const SizedBox(height: 20),
          Text(titles[_step], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(subs[_step], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List.generate(3, (i) {
        if (i % 2 != 0) return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 8), height: 3, decoration: BoxDecoration(color: (i ~/ 2 < _step) ? const Color(0xFF81B655) : Colors.grey[100], borderRadius: BorderRadius.circular(2))));
        int idx = i ~/ 2; bool active = idx <= _step;
        return Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: active ? const Color(0xFF81B655) : Colors.white, shape: BoxShape.circle, border: Border.all(color: active ? const Color(0xFF81B655) : Colors.grey[200]!, width: 2)),
          child: Center(child: Icon(idx < _step ? Icons.check : (idx == 0 ? Icons.email : Icons.mark_email_read), color: active ? Colors.white : Colors.grey[300], size: 14)),
        );
      }),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Enter the email address associated with your Grammatica account and we\'ll send you a link to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        _field(controller: _emailController, hint: 'Recovery Email', icon: Icons.alternate_email_rounded, keyboard: TextInputType.emailAddress),
        const SizedBox(height: 32),
        _btn(label: 'Send Reset Link', isLoading: _isSending, onTap: _sendResetEmail),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded, size: 48, color: Color(0xFF10B981)),
        ),
        const SizedBox(height: 20),
        Text(
          'We\'ve sent a password reset link to:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          _targetEmail ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Text(
          'Click the link in the email to create a new password. If you don\'t see it, check your spam folder.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _sendResetEmail,
          icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF81B655)),
          label: const Text('Resend Email', style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _field({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, VoidCallback? onToggle, TextInputType? keyboard}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: TextField(
        controller: controller, obscureText: obscure, keyboardType: keyboard,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
          suffixIcon: onToggle != null ? IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF94A3B8), size: 18), onPressed: onToggle) : null,
          hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  Widget _btn({required String label, required bool isLoading, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81B655), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBackLink() {
    return Padding(padding: const EdgeInsets.only(bottom: 24), child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Sign In', style: TextStyle(color: Colors.black38, fontSize: 13, fontWeight: FontWeight.bold))));
  }
}
