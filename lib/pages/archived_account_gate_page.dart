import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class ArchivedAccountGatePage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> userData;

  const ArchivedAccountGatePage({
    super.key,
    required this.user,
    required this.userData,
  });

  @override
  State<ArchivedAccountGatePage> createState() =>
      _ArchivedAccountGatePageState();
}

class _ArchivedAccountGatePageState extends State<ArchivedAccountGatePage> {
  static const int _cooldownDurationSeconds = 300; // 5 minutes

  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initCooldown();
  }

  @override
  void didUpdateWidget(covariant ArchivedAccountGatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData['reactivation_last_requested_at'] !=
        widget.userData['reactivation_last_requested_at']) {
      _initCooldown();
    }
  }

  void _initCooldown() {
    _countdownTimer?.cancel();

    final lastReq = widget.userData['reactivation_last_requested_at'];
    DateTime? lastReqTime;
    if (lastReq is Timestamp) {
      lastReqTime = lastReq.toDate();
    } else if (lastReq is DateTime) {
      lastReqTime = lastReq;
    }

    if (lastReqTime != null) {
      final elapsed = DateTime.now().difference(lastReqTime).inSeconds;
      if (elapsed < _cooldownDurationSeconds) {
        setState(() {
          _secondsRemaining = _cooldownDurationSeconds - elapsed;
        });
        _startTimer();
        return;
      }
    }

    setState(() {
      _secondsRemaining = 0;
    });
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRequestReactivation() async {
    if (_secondsRemaining > 0 || _isSending) return;

    setState(() {
      _isSending = true;
    });

    final email = widget.user.email ?? widget.userData['email'] ?? '';
    final username = widget.userData['username'] ??
        widget.userData['full_name'] ??
        widget.user.displayName ??
        'User';

    try {
      // 1. Record reactivation request in Firestore
      await DatabaseService.instance.requestAccountReactivation(widget.user.uid);

      // 2. Alert Super Admins via NotificationService
      await NotificationService.instance.notifySuperAdminsOfReactivationRequest(
        uid: widget.user.uid,
        userEmail: email,
        username: username,
      );

      if (!mounted) return;

      setState(() {
        _isSending = false;
        _secondsRemaining = _cooldownDurationSeconds;
      });
      _startTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reactivation request submitted! A Super Admin has been notified.',
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit reactivation request: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isReactivationPending =
        widget.userData['reactivation_requested'] == true;
    final bool isOnCooldown = _secondsRemaining > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 36,
                ),
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
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.08,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Header
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.28),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.archive_outlined,
                        color: Color(0xFFF59E0B),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Title
                    Text(
                      'Account Archived',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Main Notice Text
                    Text(
                      'Your account has been archived due to inactivity.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dedicated Status Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isReactivationPending
                            ? (isDark
                                ? const Color(0xFF0C4A6E).withValues(alpha: 0.3)
                                : const Color(0xFFF0F9FF))
                            : (isDark
                                ? const Color(0xFF334155).withValues(alpha: 0.3)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isReactivationPending
                              ? (isDark
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFFBAE6FD))
                              : (isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isReactivationPending
                                ? Icons.hourglass_top_rounded
                                : Icons.info_outline_rounded,
                            color: isReactivationPending
                                ? const Color(0xFF0284C7)
                                : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isReactivationPending
                                      ? 'Status: Reactivation Request Pending'
                                      : 'Status: Account Inactive',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isReactivationPending
                                        ? (isDark
                                            ? const Color(0xFF7DD3FC)
                                            : const Color(0xFF0369A1))
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF334155)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isReactivationPending
                                      ? 'Your request was submitted. A Super Admin has been notified and will review your account.'
                                      : 'You can request to have your account reactivated by clicking the button below.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Primary Button: Request Reactivation with 5-Minute Lockout
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: (isOnCooldown || _isSending)
                            ? null
                            : _handleRequestReactivation,
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
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isOnCooldown
                                    ? Icons.timer_outlined
                                    : Icons.send_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isSending
                              ? 'Sending Request...'
                              : (isOnCooldown
                                  ? 'Request Reactivation (Wait ${_formatDuration(_secondsRemaining)})'
                                  : (isReactivationPending
                                      ? 'Resend Reactivation Request'
                                      : 'Request Reactivation')),
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    if (isOnCooldown) ...[
                      const SizedBox(height: 8),
                      Text(
                        'You can send another reminder to the Super Admin once the cooldown ends.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Secondary Button: Log Out
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await AuthService.instance.signOut();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF475569),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(
                          'Log out',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

