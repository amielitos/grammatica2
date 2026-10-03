import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/design_ornaments.dart';

/// Firebase-native Email Verification Page.
/// Replaces the legacy SMTP OTP relay with direct Firebase Authentication
/// email verification (`sendEmailVerification` and `user.reload()`).
class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String? password;
  final String? fullName;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? expectedOtp;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.password,
    this.fullName,
    this.phoneNumber,
    this.dateOfBirth,
    this.expectedOtp,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

typedef EmailVerificationPage = OtpVerificationPage;

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  bool _isChecking = false;
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    // Periodically poll Firebase Auth to check if the user verified their email via the link
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkVerificationSilently();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerificationSilently() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified && mounted) {
        _autoCheckTimer?.cancel();
        _onVerificationSuccess();
      }
    } catch (_) {}
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Session expired. Please log in to continue."),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed != null && refreshed.emailVerified) {
        if (mounted) _onVerificationSuccess();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Email not verified yet. Please check your inbox and click the verification link.",
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error checking status: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      await AuthService.instance.sendEmailVerification(
        email: widget.email,
        fullName: widget.fullName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text("Verification link resent successfully! Please check your inbox."),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF81B655),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to resend: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onVerificationSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFF81B655), size: 28),
              SizedBox(width: 10),
              Text(
                "Email Verified!",
                style: TextStyle(
                  color: Color(0xFF81B655),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "Your email address has been verified successfully. Your Grammatica account is now fully active!",
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text("Continue to App", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGoBack() async {
    _autoCheckTimer?.cancel();
    _cooldownTimer?.cancel();
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWrapper(
        imageAssetPath: 'assets/signinbgs.png',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Badge
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2F3D9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 44,
                        color: Color(0xFF81B655),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      "Verify Your Email",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
                        children: [
                          const TextSpan(text: "We sent a Firebase verification link to\n"),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              color: Color(0xFF81B655),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instruction Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.touch_app_outlined, size: 20, color: Colors.grey.shade700),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "1. Open your email inbox and click the verification link.",
                                  style: TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 20, color: Colors.grey.shade700),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "2. Return here and tap 'I've Verified My Email' to continue.",
                                  style: TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.markunread_mailbox_outlined, size: 20, color: Colors.grey.shade500),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Tip: Can't find the email? Check your Spam or Junk folder.",
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Primary Verification Check Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isChecking ? null : _checkVerificationStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81B655),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isChecking
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "I've Verified My Email",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Resend Email Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't receive the email? ",
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                        if (_cooldownSeconds > 0)
                          Text(
                            "Resend in ${_cooldownSeconds}s",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        else
                          InkWell(
                            onTap: _isResending ? null : _resendVerificationEmail,
                            child: _isResending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF81B655)),
                                  )
                                : const Text(
                                    "Resend Link",
                                    style: TextStyle(
                                      color: Color(0xFF81B655),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Back to Sign In
                    TextButton.icon(
                      onPressed: _handleGoBack,
                      icon: const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
                      label: const Text(
                        "Back to Sign In",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
