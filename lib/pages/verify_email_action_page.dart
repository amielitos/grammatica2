import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/email_sender_service.dart';
import '../theme/app_colors.dart';
import '../utils/url_cleaner.dart';

enum VerifyEmailStatus {
  verifying,
  success,
  alreadyVerified,
  invalidCode,
}

class VerifyEmailActionPage extends StatefulWidget {
  final String oobCode;

  const VerifyEmailActionPage({
    super.key,
    required this.oobCode,
  });

  @override
  State<VerifyEmailActionPage> createState() => _VerifyEmailActionPageState();
}

class _VerifyEmailActionPageState extends State<VerifyEmailActionPage> {
  VerifyEmailStatus _status = VerifyEmailStatus.verifying;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyEmail();
  }

  Future<void> _verifyEmail() async {
    setState(() {
      _status = VerifyEmailStatus.verifying;
      _errorMessage = null;
    });

    try {
      // 1. Apply verification code to Firebase Authentication
      await FirebaseAuth.instance.applyActionCode(widget.oobCode);

      // 2. Clear query parameters from browser URL bar to avoid re-triggering on refresh
      clearBrowserUrlParams('/');

      // 3. Refresh user session if currently signed in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        await currentUser.getIdToken(true);

        // Update Firestore to unblock verification gate
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'requires_email_verification': false,
          'isVerified': true,
        }).catchError((_) {});

        // Send welcome onboarding confirmation email
        final targetEmail = currentUser.email ?? '';
        final targetName = currentUser.displayName ?? 'Learner';
        if (targetEmail.isNotEmpty) {
          EmailSenderService.sendWelcomeEmail(
            recipientEmail: targetEmail,
            recipientName: targetName,
          ).catchError((_) => false);
        }
      }

      if (mounted) {
        setState(() {
          _status = VerifyEmailStatus.success;
        });
      }
    } on FirebaseAuthException catch (e) {
      clearBrowserUrlParams('/');

      // Check if user is actually already verified
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.reload();
          await currentUser.getIdToken(true);
          if (currentUser.emailVerified) {
            await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
              'requires_email_verification': false,
              'isVerified': true,
            }).catchError((_) {});

            if (mounted) {
              setState(() {
                _status = VerifyEmailStatus.alreadyVerified;
              });
            }
            return;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _status = VerifyEmailStatus.invalidCode;
          _errorMessage = e.message ??
              'This email verification link is invalid, expired, or has already been used. Please request a new link or try signing in.';
        });
      }
    } catch (e) {
      clearBrowserUrlParams('/');
      if (mounted) {
        setState(() {
          _status = VerifyEmailStatus.invalidCode;
          _errorMessage = 'Failed to verify email address: $e';
        });
      }
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
      case VerifyEmailStatus.verifying:
        return _buildVerifyingState(isDark);
      case VerifyEmailStatus.success:
        return _buildSuccessState(isDark);
      case VerifyEmailStatus.alreadyVerified:
        return _buildAlreadyVerifiedState(isDark);
      case VerifyEmailStatus.invalidCode:
        return _buildInvalidCodeState(isDark);
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
          'Verifying your email address...',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please wait while we confirm your credentials.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(bool isDark) {
    final currentUser = FirebaseAuth.instance.currentUser;

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
          'Email Verified Successfully!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your email address has been verified. Your Grammatica account is now fully active and ready to use.',
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
              if (currentUser != null) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              } else {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
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
              currentUser != null ? 'Continue to App' : 'Proceed to Sign In',
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

  Widget _buildAlreadyVerifiedState(bool isDark) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/logotext.png', height: 40),
        const SizedBox(height: 24),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: Color(0xFF3B82F6),
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Email Already Verified',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your email address has already been confirmed. You can continue straight to your Grammatica account.',
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
              if (currentUser != null) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              } else {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
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
              currentUser != null ? 'Continue to App' : 'Sign In',
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
              'This email verification link is invalid or has expired. If you need a new link, please log in and request a new verification email.',
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
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
              'Back to Sign In',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
          child: Text(
            'Go to Homepage',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}

