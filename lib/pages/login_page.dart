import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/design_ornaments.dart';

import '../widgets/top_nav_bar.dart';
import '../widgets/tagline_hero_text.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  StreamSubscription<User?>? _authSubscription;
  bool _isAccountLocked = false;
  int _lockoutRemainingSeconds = 0;
  Timer? _lockoutTimer;

  Stopwatch? _lockoutStopwatch;

  String _formatRemainingTime(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();
    final initialSeconds = seconds > 0 ? seconds : 300;
    _lockoutStopwatch?.stop();
    _lockoutStopwatch = Stopwatch()..start();

    setState(() {
      _isAccountLocked = true;
      _lockoutRemainingSeconds = initialSeconds;
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = _lockoutStopwatch?.elapsed.inSeconds ?? 0;
      final remaining = initialSeconds - elapsed;
      if (remaining <= 0) {
        timer.cancel();
        _lockoutStopwatch?.stop();
        setState(() {
          _isAccountLocked = false;
          _lockoutRemainingSeconds = 0;
        });
      } else {
        setState(() {
          _lockoutRemainingSeconds = remaining;
        });
      }
    });
  }

  Future<void> _checkInitialLockout() async {
    final status = await AuthService.instance.getLockoutStatus(_emailController.text.trim());
    if (status.isLocked && mounted) {
      final seconds = status.remainingDuration.inSeconds > 0
          ? status.remainingDuration.inSeconds
          : 300;
      _startLockoutCountdown(seconds);
    }
  }

  Future<void> _handleLockoutTriggered(String message) async {
    final status = await AuthService.instance.getLockoutStatus(_emailController.text.trim());
    final seconds = status.remainingDuration.inSeconds > 0
        ? status.remainingDuration.inSeconds
        : 300;
    _startLockoutCountdown(seconds);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RESET',
            textColor: Colors.yellowAccent,
            onPressed: _showForgotPasswordDialog,
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    AuthService.preferredGoogleRole = null;
    _checkInitialLockout();
    _authSubscription = AuthService.instance.authStateChanges().listen((user) async {
      if (user != null && mounted) {
        final isGoogleUser = user.providerData.any(
          (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
        );
        if (isGoogleUser || user.emailVerified) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // Check if this user is a legacy user who bypasses verification
          final requiresVerification =
              await AuthService.instance.userRequiresEmailVerification(user);
          if (!requiresVerification && mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    });
  }

  Future<void> _login() async {
    if (_isAccountLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This device is temporarily locked. Please wait ${_formatRemainingTime(_lockoutRemainingSeconds)}.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Now that sign-in is successful, pop this page so the AuthWrapper in main.dart
      // can show the dashboard.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'account-locked') {
          await _handleLockoutTriggered(e.message ?? 'Account is temporarily locked.');
        } else if (e.code == 'email-not-verified') {
          _showEmailNotVerifiedDialog(_emailController.text.trim());
        } else {
          final isWarning = e.message?.contains('remaining') == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Login failed'),
              backgroundColor: isWarning ? Colors.orange.shade800 : Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: isWarning ? 4 : 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEmailNotVerifiedDialog(String email) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Text(
              "Verify Your Email",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your account has not been verified yet. For your security, you must confirm your identity through Firebase email verification before you can sign in to Grammatica.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await AuthService.instance.sendEmailVerification(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Verification link resent! Please check your inbox and verify before signing in.",
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF81B655),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Failed to resend verification email: $err"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text("Resend Verification Email"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81B655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ForgotPasswordPage(),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.googleSignIn();
      // Now that sign-in is successful, pop this page so the AuthWrapper in main.dart
      // can show the dashboard.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: TopNavBar(),
      ),
      body: BackgroundWrapper(
        imageAssetPath: 'assets/signinbgs.png',
        child: LayoutBuilder(builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 800;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          final authCard = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    padding: const EdgeInsets.only(
                        top: 32, bottom: 16, left: 32, right: 32),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/logotext.png',
                          height: 38,
                          errorBuilder: (ctx, err, st) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.language_rounded,
                                color: Color(0xFF81B655),
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Grammatica',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Welcome Back!",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Sign in to continue your learning journey",
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Form section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isAccountLocked) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.lock_clock_rounded,
                                          color: Color(0xFFDC2626), size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Account Temporarily Locked',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _formatRemainingTime(_lockoutRemainingSeconds),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '3 consecutive failed login attempts detected. For security, sign-in is temporarily paused.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Forgot your password?',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                      TextButton(
                                        onPressed: _isLoading ? null : _showForgotPasswordDialog,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Reset to Unlock Now',
                                          style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          _buildTextField(
                            hintText: 'Email Address *',
                            controller: _emailController,
                            enabled: !_isLoading,
                            prefixIcon: const Icon(Icons.email_outlined),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              if (_passwordController.text.isNotEmpty && !_isLoading) {
                                _login();
                              }
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value.trim())) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            hintText: 'Password *',
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) {
                                _login();
                              }
                            },
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF81B655),
                                size: 22,
                              ),
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (value) => (value == null || value.isEmpty)
                                ? 'Please enter your password'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF81B655),
                                  Color(0xFF75A94B),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: (_isLoading || _isAccountLocked) ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAccountLocked ? Colors.grey.shade400 : Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isAccountLocked
                                          ? 'Locked (${_formatRemainingTime(_lockoutRemainingSeconds)})'
                                          : 'Sign In',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDivider(),
                          const SizedBox(height: 20),
                          GoogleSignInButton(
                            onPressed: _isLoading ? () {} : _loginWithGoogle,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) => const SignupPage(),
                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                            // Pure fade transition
                                            return FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            );
                                          },
                                          transitionDuration: const Duration(milliseconds: 400),
                                        ),
                                      );
                                    },
                              child: RichText(
                                text: TextSpan(
                                  text: "Don't have an account? ",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: "Sign Up",
                                      style: TextStyle(
                                        color: Color(0xFF81B655), // Match green
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: isLargeScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: TaglineHeroText(title: 'Welcome Back!'),
                        ),
                        const SizedBox(width: 60),
                        authCard,
                      ],
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: authCard,
                    ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required TextEditingController controller,
    required Widget prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    bool enabled = true,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRequired = hintText.trim().endsWith('*');
    final String cleanHint = isRequired
        ? hintText.replaceAll(RegExp(r'\s*\*'), '').trim()
        : hintText;

    return Container(
      decoration: BoxDecoration(
        color: !enabled
            ? (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100)
            : (isDark ? const Color(0xFF334155) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: isRequired ? null : hintText,
          label: isRequired
              ? Text.rich(
                  TextSpan(
                    text: cleanHint,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
          hintStyle: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, fontWeight: FontWeight.w600),
          prefixIcon: IconTheme(
              data: IconThemeData(color: isDark ? Colors.white70 : Colors.black54),
              child: prefixIcon),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent, // Inherit from container
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Or continue with",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade300)),
      ],
    );
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _lockoutStopwatch?.stop();
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
