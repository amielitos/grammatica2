import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database_service.dart';
import 'email_sender_service.dart';
import 'email_validator_service.dart';
import 'device_session_service.dart';
import '../pages/home_page.dart';
import '../pages/admin_dashboard.dart';

class LockoutStatus {
  final bool isLocked;
  final int failedCount;
  final DateTime? lockedUntil;
  final Duration remainingDuration;

  const LockoutStatus({
    required this.isLocked,
    required this.failedCount,
    this.lockedUntil,
    this.remainingDuration = Duration.zero,
  });
}

class AuthService {
  // 1. Fields and Singleton first
  static final instance = AuthService._();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static bool justSignedUpWithGoogle = false;
  static String? preferredGoogleRole;

  static const int maxFailedAttempts = 3;
  static const Duration lockoutDuration = Duration(minutes: 5);

  static void showSnackBar(String message, {bool isError = true}) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;
  Future<void>? _googleSignInInit;

  // 2. Private Constructor
  AuthService._() {
    // Listen to Google Sign-In events (especially useful for Web GIS button)
    _googleSignIn.authenticationEvents.listen(_handleGoogleSignInEvent);

    // Initialize early on web to ensure GIS is ready for buttons
    if (kIsWeb) {
      ensureGoogleSignInInitialized().catchError((e) {
        debugPrint('Early web GoogleSignIn initialization failed: $e');
      });
    }
  }

  // 3. Methods
  Future<void> _handleGoogleSignInEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      try {
        final googleAuth = event.user.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          debugPrint('Google Sign-In Error: ID Token is null');
          return;
        }

        final credential = GoogleAuthProvider.credential(
          idToken: idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);

        // Check if first-time sign up with Google
        final isNew = (userCredential.additionalUserInfo?.isNewUser ?? false);
        final isNewDoc = await _ensureUserDocumentExists(userCredential.user);
        if (isNew || isNewDoc) {
          justSignedUpWithGoogle = true;
          _generateAndSendTempPassword(userCredential.user!);
          if (userCredential.user?.email != null) {
            EmailSenderService.sendWelcomeEmail(
              recipientEmail: userCredential.user!.email!,
              recipientName: userCredential.user!.displayName ?? 'Learner',
            ).catchError((e) {
              debugPrint('Error sending welcome confirmation email: $e');
              return false;
            });
          }
        }
      } catch (e) {
        debugPrint('Error handling Google Sign-In event: $e');
        AuthService.messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<bool> _ensureUserDocumentExists(User? user, {String? role}) async {
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        String chosenRole = (role ?? preferredGoogleRole ?? '').trim().toUpperCase();
        if (chosenRole != 'VALIDATOR' && chosenRole != 'LEARNER') {
          final navContext = navigatorKey.currentContext;
          if (navContext != null && navContext.mounted) {
            final selected = await showDialog<String>(
              context: navContext,
              barrierDismissible: false,
              builder: (ctx) => const _GoogleRoleSelectionDialog(),
            );
            if (selected != null && selected.isNotEmpty) {
              chosenRole = selected.toUpperCase();
            }
          }
        }
        if (chosenRole != 'VALIDATOR') {
          chosenRole = 'LEARNER';
        }
        final isValidator = chosenRole == 'VALIDATOR';
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'role': chosenRole,
          'status': isValidator ? 'Validator in Review' : 'ACTIVE',
          'isVerified': !isValidator,
          'subscription_status': 'NONE',
          'username': user.displayName ?? 'Google User',
          'photoUrl': user.photoURL ?? '',
          'has_completed_onboarding': false,
        });
        preferredGoogleRole = null;
        return true; // Is new user
      }
      return false; // Not new
    }
    return false;
  }

  Future<void> _generateAndSendTempPassword(User user) async {
    if (user.email == null) return;
    try {
      // Setup a simple 6-character temporary password (e.g., GH78K2)
      final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid O, 0, I, 1 for clarity
      final random = List.generate(6, (index) {
        final randIdx = DateTime.now().microsecondsSinceEpoch % chars.length;
        return chars[(randIdx + index) % chars.length];
      }).join();

      final tempPassword = random;

      // Update the user's password in Firebase Auth so they can use it to login later
      await user.updatePassword(tempPassword);

      // Send the branded email with the temporary password & Grammatica logo
      await EmailSenderService.sendTempPasswordEmail(
        recipientEmail: user.email!,
        recipientName: user.displayName ?? 'Learner',
        tempPassword: tempPassword,
      );
    } catch (e) {
      debugPrint('Error generating temp password: $e');
    }
  }

  Future<void> ensureGoogleSignInInitialized() async {
    if (_isGoogleSignInInitialized) return;
    if (_googleSignInInit != null) return _googleSignInInit;

    const webClientId =
        '458713583940-v6j8pjs8bj4ftmibm8ml78rl1qrm6ib5.apps.googleusercontent.com';
    _googleSignInInit = _googleSignIn.initialize(
      clientId: kIsWeb ? webClientId : null,
      serverClientId: kIsWeb ? null : webClientId,
    );

    try {
      await _googleSignInInit;
      _isGoogleSignInInitialized = true;
    } catch (e) {
      _googleSignInInit = null;
      rethrow;
    }
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  /// Always returns the current, live Firebase Auth user.
  /// Use this instead of stale `widget.user` references for
  /// any Firestore operations or navigation.
  static User get liveUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
          'No authenticated user. This should never happen in an authenticated context.');
    }
    return user;
  }

  /// Returns the current Firebase Auth user if logged in, or null.
  static User? get maybeLiveUser => FirebaseAuth.instance.currentUser;

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  String _emailDocId(String email) => email.trim().toLowerCase().replaceAll('/', '_');

  /// Sliding window duration after which un-locked failed attempts expire.
  static const Duration attemptExpirationWindow = Duration(minutes: 15);

  /// Helper to clear expired Firestore lockout document quietly
  Future<void> _clearFirestoreLockout(String docId) async {
    try {
      await _firestore.collection('login_attempts').doc(docId).set({
        'failed_count': 0,
        'locked_until': null,
        'last_cleared_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Fetches current lockout status for the active device and optionally for an email.
  Future<LockoutStatus> getLockoutStatus(String email) async {
    final emailClean = email.trim().toLowerCase();

    // 1. Device/session level lockout check (takes precedence to protect this device)
    final deviceState = await DeviceSessionService.instance.getLockoutState();
    if (deviceState.isLocked) {
      return LockoutStatus(
        isLocked: true,
        failedCount: deviceState.failedCount,
        lockedUntil: deviceState.lockedUntil,
        remainingDuration: deviceState.remainingDuration,
      );
    }

    if (emailClean.isEmpty) {
      return LockoutStatus(
        isLocked: false,
        failedCount: deviceState.failedCount,
      );
    }

    try {
      final doc = await _firestore
          .collection('login_attempts')
          .doc(_emailDocId(emailClean))
          .get();
      if (!doc.exists) {
        return LockoutStatus(isLocked: false, failedCount: deviceState.failedCount);
      }
      final data = doc.data() ?? {};
      int failedCount = (data['failed_count'] as num?)?.toInt() ?? 0;
      final lockedUntilTs = data['locked_until'] as Timestamp?;
      final lastFailedTs = data['last_failed_at'] as Timestamp?;
      final now = DateTime.now();

      // Check if email-specific lockout is active in Firestore
      if (lockedUntilTs != null) {
        final lockedUntilDate = lockedUntilTs.toDate();
        if (lockedUntilDate.isAfter(now)) {
          return LockoutStatus(
            isLocked: true,
            failedCount: math.max(failedCount, deviceState.failedCount),
            lockedUntil: lockedUntilDate,
            remainingDuration: lockedUntilDate.difference(now),
          );
        } else {
          // Lock expired in Firestore: clear it asynchronously
          _clearFirestoreLockout(_emailDocId(emailClean));
          failedCount = 0;
        }
      } else if (lastFailedTs != null) {
        // Sliding window: If last failed attempt was >15 minutes ago, reset stale count
        if (now.difference(lastFailedTs.toDate()) > attemptExpirationWindow) {
          failedCount = 0;
        }
      }

      final effectiveCount = math.max(failedCount, deviceState.failedCount);
      return LockoutStatus(
        isLocked: false,
        failedCount: effectiveCount,
      );
    } catch (e) {
      debugPrint('Error getting lockout status: $e');
      return LockoutStatus(isLocked: false, failedCount: deviceState.failedCount);
    }
  }

  /// Records a failed login attempt on this device and syncs to Firestore.
  /// Locks the device for 5 minutes if 3 failed attempts are reached (regardless of email change).
  Future<LockoutStatus> _recordFailedAttempt(String email) async {
    final emailClean = email.trim().toLowerCase();

    // 1. Record on this physical device/session (persists across email changes!)
    final deviceState = await DeviceSessionService.instance.recordFailedAttempt();
    final deviceId = await DeviceSessionService.instance.getDeviceId();

    final nowUtc = DateTime.now().toUtc();
    final lockUntilUtc = nowUtc.add(lockoutDuration);
    final lockUntilTs = Timestamp.fromDate(lockUntilUtc);

    try {
      // 2. Synchronize device attempt to Firestore
      final devDocRef = _firestore.collection('login_attempts').doc(deviceId);
      if (deviceState.isLocked) {
        await devDocRef.set({
          'device_id': deviceId,
          'failed_count': deviceState.failedCount,
          'last_failed_at': FieldValue.serverTimestamp(),
          'locked_until': lockUntilTs,
        }, SetOptions(merge: true));
      } else {
        await devDocRef.set({
          'device_id': deviceId,
          'failed_count': deviceState.failedCount,
          'last_failed_at': FieldValue.serverTimestamp(),
          'locked_until': null,
        }, SetOptions(merge: true));
      }

      // 3. If email provided, also sync to email document with sliding window
      if (emailClean.isNotEmpty) {
        final emailDocRef = _firestore
            .collection('login_attempts')
            .doc(_emailDocId(emailClean));

        final doc = await emailDocRef.get();
        int emailCount = 0;
        if (doc.exists) {
          final data = doc.data() ?? {};
          final lockedUntilTs = data['locked_until'] as Timestamp?;
          final lastFailedTs = data['last_failed_at'] as Timestamp?;
          
          if (lockedUntilTs != null && lockedUntilTs.toDate().toUtc().isBefore(nowUtc)) {
            emailCount = 0;
          } else if (lastFailedTs != null && nowUtc.difference(lastFailedTs.toDate().toUtc()) > attemptExpirationWindow) {
            emailCount = 0;
          } else {
            emailCount = (data['failed_count'] as num?)?.toInt() ?? 0;
          }
        }
        emailCount += 1;

        if (deviceState.isLocked || emailCount >= maxFailedAttempts) {
          await emailDocRef.set({
            'email': emailClean,
            'failed_count': math.max(emailCount, deviceState.failedCount),
            'last_failed_at': FieldValue.serverTimestamp(),
            'locked_until': lockUntilTs,
            'device_id': deviceId,
          }, SetOptions(merge: true));

          // Mirror to user doc if user exists
          try {
            final userQuery = await _firestore
                .collection('users')
                .where('email', isEqualTo: emailClean)
                .limit(1)
                .get();
            if (userQuery.docs.isNotEmpty) {
              final uDoc = userQuery.docs.first;
              final recipientName = (uDoc.data()['username'] ??
                      uDoc.data()['full_name'] ??
                      'Learner')
                  .toString();
              await uDoc.reference.update({
                'locked_until': lockUntilTs,
              });

              // Send email alert asynchronously
              EmailSenderService.sendAccountLockedEmail(
                recipientEmail: emailClean,
                recipientName: recipientName,
                lockoutMinutes: lockoutDuration.inMinutes,
              ).catchError((e) {
                debugPrint('Error sending account locked email: $e');
                return false;
              });
            }
          } catch (e) {
            debugPrint('Error syncing locked_until to user doc: $e');
          }
        } else {
          await emailDocRef.set({
            'email': emailClean,
            'failed_count': math.max(emailCount, deviceState.failedCount),
            'last_failed_at': FieldValue.serverTimestamp(),
            'locked_until': null,
            'device_id': deviceId,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Error syncing failed login attempt to Firestore: $e');
    }

    return LockoutStatus(
      isLocked: deviceState.isLocked,
      failedCount: deviceState.failedCount,
      lockedUntil: deviceState.lockedUntil,
      remainingDuration: deviceState.remainingDuration,
    );
  }

  /// Clears failed attempts and unlocks device and account
  Future<void> resetLoginAttempts(String email, {String? uid}) async {
    // 1. Clear device-level lockout
    await DeviceSessionService.instance.clearLockout();
    try {
      final deviceId = await DeviceSessionService.instance.getDeviceId();
      await _firestore.collection('login_attempts').doc(deviceId).set({
        'failed_count': 0,
        'locked_until': null,
        'last_cleared_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // 2. Clear email-level lockout
    final emailClean = email.trim().toLowerCase();
    if (emailClean.isNotEmpty) {
      try {
        final docRef = _firestore
            .collection('login_attempts')
            .doc(_emailDocId(emailClean));
        await docRef.set({
          'email': emailClean,
          'failed_count': 0,
          'locked_until': null,
          'last_failed_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also clear on user document
        if (uid != null && uid.isNotEmpty) {
          await _firestore.collection('users').doc(uid).update({
            'locked_until': null,
          }).catchError((_) {});
        } else {
          final query = await _firestore
              .collection('users')
              .where('email', isEqualTo: emailClean)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            await query.docs.first.reference.update({
              'locked_until': null,
            }).catchError((_) {});
          }
        }
      } catch (e) {
        debugPrint('Error resetting login attempts: $e');
      }
    }
  }

  /// Unlocks an account immediately (called by admin or self-unlock via password reset)
  Future<void> unlockAccount(String email, {String? uid}) async {
    await resetLoginAttempts(email, uid: uid);
  }


  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final emailClean = email.trim().toLowerCase();

    // Pre-check: Is the account locked?
    final lockStatus = await getLockoutStatus(emailClean);
    if (lockStatus.isLocked) {
      final remaining = lockStatus.remainingDuration;
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      final timeStr = minutes > 0
          ? '$minutes min ${seconds > 0 ? "$seconds sec" : ""}'
          : '$seconds seconds';
      throw FirebaseAuthException(
        code: 'account-locked',
        message:
            'Your account is temporarily locked due to 3 failed attempts. Please try again in $timeStr, or reset your password.',
      );
    }

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check user document and verification policy
      final user = userCredential.user;
      if (user != null) {
        // Initial Security Check: check if the user is deactivated or archived
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        final status = (userData?['status'] as String?)?.toUpperCase();
        final isArchived = status == 'ARCHIVED' || userData?['isArchived'] == true;
        if (userDoc.exists && (status == 'DEACTIVATED' || isArchived)) {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: isArchived ? 'account-archived' : 'account-deactivated',
            message: isArchived
                ? 'This account has been archived. Please contact support.'
                : 'Your account has been deactivated. Please contact support.',
          );
        }

        // Email verification check: ONLY applies to new users starting now.
        // Legacy or current users (where requires_email_verification != true) bypass verification.
        final bool requiresEmailVerification = (userData?['requires_email_verification'] == true);
        if (requiresEmailVerification) {
          await user.reload();
          final refreshedUser = _auth.currentUser ?? user;
          final isGoogleUser = refreshedUser.providerData.any(
            (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
          );
          if (!isGoogleUser && !refreshedUser.emailVerified) {
            await _auth.signOut();
            throw FirebaseAuthException(
              code: 'email-not-verified',
              message:
                  'Your email has not been verified yet. Please check your inbox and confirm your identity before signing in.',
            );
          }
        }
      }

      // Successful login -> Reset attempts & lockout
      await resetLoginAttempts(emailClean, uid: userCredential.user?.uid);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-not-found') {
        final result = await _recordFailedAttempt(emailClean);
        if (result.isLocked) {
          throw FirebaseAuthException(
            code: 'account-locked',
            message:
                'Too many failed login attempts. Your account has been temporarily locked for 5 minutes. A security notification was sent to your email.',
          );
        } else {
          final attemptsRemaining = maxFailedAttempts - result.failedCount;
          final warning = attemptsRemaining == 1
              ? 'Invalid email or password. Warning: 1 attempt remaining before your account is locked.'
              : 'Invalid email or password. $attemptsRemaining attempts remaining.';
          throw FirebaseAuthException(
            code: e.code,
            message: warning,
          );
        }
      }
      rethrow;
    }
  }

  Future<UserCredential> googleSignIn({String? role}) async {
    await ensureGoogleSignInInitialized();

    // On Web, direct programmatic sign-in via authenticate() is not supported.
    // The UI must use the official renderButton() widget.
    if (kIsWeb) {
      throw FirebaseAuthException(
        code: 'unsupported-platform',
        message:
            'Google Sign-In on Web requires the official Google button. Please use the button provided in the UI.',
      );
    }

    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'ERROR_MISSING_ID_TOKEN',
          message: 'Google Sign-In failed: Missing ID Token',
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Security Check: Deactivated or Archived Status
      final userDoc = await _firestore.collection('users').doc(userCredential.user?.uid).get();
      final userData = userDoc.data();
      final status = (userData?['status'] as String?)?.toUpperCase();
      final isArchived = status == 'ARCHIVED' || userData?['isArchived'] == true;
      if (userDoc.exists && (status == 'DEACTIVATED' || isArchived)) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
          code: isArchived ? 'account-archived' : 'account-deactivated',
          message: isArchived
              ? 'This account has been archived. Please contact support.'
              : 'Your account has been deactivated. Please contact support.',
        );
      }

      bool isNewUser = await _ensureUserDocumentExists(userCredential.user, role: role);
      final isNewAuthUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      if (isNewUser || isNewAuthUser) {
        justSignedUpWithGoogle = true;
        await _generateAndSendTempPassword(userCredential.user!);
        if (userCredential.user?.email != null) {
          EmailSenderService.sendWelcomeEmail(
            recipientEmail: userCredential.user!.email!,
            recipientName: userCredential.user!.displayName ?? 'Learner',
          ).catchError((e) {
            debugPrint('Error sending welcome confirmation email: $e');
            return false;
          });
        }
      }
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'ERROR_SIGN_IN_FAILED',
        message: 'Google Sign-In failed: $e',
      );
    }
  }

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required DateTime dateOfBirth,
    String role = 'learner',
  }) async {
    if (!EmailValidatorService.isAllowedEmail(email)) {
      throw FirebaseAuthException(
        code: 'ERROR_INVALID_EMAIL',
        message: 'Only @gmail.com, @yahoo.com, and @hotmail.com email addresses are allowed.',
      );
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred
        .user!; // User is guaranteed to be non-null after successful creation
    // Create users/{uid} with defaults and new fields
    final isValidator = role.toUpperCase() == 'VALIDATOR';
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'role': role.toUpperCase(),
      'status': isValidator ? 'Validator in Review' : 'ACTIVE',
      'isVerified': !isValidator,
      'subscription_status': 'NONE',
      'username': fullName,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'date_of_birth': Timestamp.fromDate(dateOfBirth),
      'photoUrl': '', // Initialize with empty photo URL
      'has_completed_onboarding': false,
      'theme_preference': 'light',
      'requires_email_verification': true, // Only new users starting now require verification
    });

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }

    return cred;
  }

  Future<bool> confirmAndSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text('Are you sure you want to sign out of Grammatica?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        await signOut(context);
      } else {
        await signOut();
      }
      return true;
    }
    return false;
  }

  Future<void> signOut([BuildContext? context]) async {
    try {
      if (context != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } catch (_) {}

    try {
      // If signed in with Google, sign out from Google too
      final user = _auth.currentUser;
      if (user != null) {
        final isGoogleUser = user.providerData.any(
          (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
        );
        if (isGoogleUser) {
          await ensureGoogleSignInInitialized();
          await _googleSignIn.signOut();
        }
      }
    } catch (e) {
      debugPrint('Error during Google sign out: $e');
    }
    // Always reset dashboard state to main Dashboard tab (index 0)
    try {
      AdminDashboard.resetToDashboard();
      HomePage.resetToDashboard();
    } catch (_) {}
    await _auth.signOut();

    try {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } catch (_) {}
  }

  /// Archives the current user account.
  /// Per system requirement: Accounts are NEVER permanently deleted.
  /// The user is marked ARCHIVED in Firestore, barred from signing in,
  /// but retained in Auth/Firestore so their email cannot be claimed or reused.
  Future<void> archiveAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Guard: Administrator and Superadmin accounts cannot be archived
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final role = (userDoc.data()?['role'] as String?)?.toUpperCase();
      if (role == 'ADMIN' || role == 'SUPERADMIN') {
        throw FirebaseAuthException(
          code: 'admin-account-archive-forbidden',
          message: 'Administrator accounts cannot be archived.',
        );
      }
    }

    try {
      // 1. Mark account as ARCHIVED in Firestore
      await DatabaseService.instance.archiveUserAccount(uid);

      // 2. Sign out the user immediately
      await signOut();
    } catch (e) {
      debugPrint('Error archiving account: $e');
      rethrow;
    }
  }

  /// Permanently deletes the current user account from Firebase Auth and Firestore.
  /// This operation is triggered exclusively by the account owner.
  /// If the user registers again with the same email, it will be treated as a brand new account.
  Future<void> permanentlyDeleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final email = user.email;

    // Guard: Administrator and Superadmin accounts cannot be deleted
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final role = (userDoc.data()?['role'] as String?)?.toUpperCase();
      if (role == 'ADMIN' || role == 'SUPERADMIN') {
        throw FirebaseAuthException(
          code: 'admin-account-deletion-forbidden',
          message: 'Administrator accounts cannot be permanently deleted.',
        );
      }
    }

    try {
      // 1. Completely delete Firestore documents for this user
      await DatabaseService.instance.permanentlyDeleteUserAccount(uid, email: email);

      // 2. Delete user from Firebase Authentication
      await user.delete();

      // 3. Clear Google Sign-In and device session
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      await DeviceSessionService.instance.clearLockout();
    } catch (e) {
      debugPrint('Error during permanent account deletion: $e');
      rethrow;
    }
  }

  /// Deletes the current user account (routes to [permanentlyDeleteAccount]).
  Future<void> deleteAccount() async {
    await permanentlyDeleteAccount();
  }

  /// Reauthenticates current user using password (for Email/Password accounts)
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found.',
      );
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
  }

  /// Reauthenticates current user with Google (for Google Sign-In accounts)
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found.',
      );
    }
    await ensureGoogleSignInInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final String? idToken = googleAuth.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'ERROR_MISSING_ID_TOKEN',
        message: 'Google re-authentication failed: Missing ID Token',
      );
    }
    final cred = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final emailClean = email.trim().toLowerCase();

    // 1. Trigger Firebase Auth native password reset email (contains secret oobCode)
    await _auth.sendPasswordResetEmail(email: emailClean);

    // 2. Auto-unlock account if locked
    await unlockAccount(emailClean);

    debugPrint('✅ Official Firebase password reset email sent to $emailClean');
  }

  /// Verifies a 6-digit password reset OTP and updates password
  Future<bool> verifyAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final emailClean = email.trim().toLowerCase();
    final docRef = _firestore.collection('password_resets').doc(_emailDocId(emailClean));
    final doc = await docRef.get();

    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'invalid-otp',
        message: 'Invalid verification code. Please request a new code.',
      );
    }

    final data = doc.data() ?? {};
    final storedOtp = data['otp']?.toString();
    final expiresAtTs = data['expires_at'] as Timestamp?;

    if (storedOtp != otp.trim()) {
      throw FirebaseAuthException(
        code: 'invalid-otp',
        message: 'The 6-digit code you entered is incorrect. Please check your email.',
      );
    }

    if (expiresAtTs != null && expiresAtTs.toDate().isBefore(DateTime.now())) {
      throw FirebaseAuthException(
        code: 'expired-otp',
        message: 'This verification code has expired. Please tap Resend Code.',
      );
    }

    // 1. Update password in Firebase Auth if current user session exists
    bool updatedDirectly = false;
    final user = _auth.currentUser;
    if (user != null && user.email?.toLowerCase() == emailClean) {
      try {
        await user.updatePassword(newPassword);
        updatedDirectly = true;
        debugPrint('✅ Firebase Auth password updated directly for logged-in session.');
      } catch (e) {
        debugPrint('Note on direct password update: $e');
      }
    }

    // 2. Save approved reset record in Firestore & unlock account
    try {
      await docRef.set({
        'email': emailClean,
        'otp_verified': true,
        'reset_approved': true,
        'pending_password': newPassword,
        'updated_directly': updatedDirectly,
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update lockout / user doc
      await unlockAccount(emailClean);
      debugPrint('✅ Approved password reset record updated in Firestore.');
    } catch (e) {
      debugPrint('Error updating reset record: $e');
    }

    return true;
  }

  Future<void> sendEmailVerification({String? email, String? fullName}) async {
    final user = _auth.currentUser;
    final targetEmail = (email ?? user?.email ?? '').trim().toLowerCase();
    if (targetEmail.isEmpty) return;

    String recipientName = fullName ?? user?.displayName ?? 'Learner';
    if (recipientName == 'Learner' || recipientName.isEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(user?.uid).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          recipientName = (data['username'] ?? data['full_name'] ?? 'Learner').toString();
        }
      } catch (_) {}
    }

    final otpCode = (100000 + (DateTime.now().microsecondsSinceEpoch % 899999)).toString();

    try {
      await _firestore.collection('email_verifications').doc(_emailDocId(targetEmail)).set({
        'email': targetEmail,
        'otp': otpCode,
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving email verification OTP to Firestore: $e');
    }

    // Send the branded Grammatica Email with logo and OTP!
    await EmailSenderService.sendOtpEmail(
      recipientEmail: targetEmail,
      recipientName: recipientName,
      otpCode: otpCode,
    );

    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('Firebase default email verification trigger: $e');
      }
    }
  }

  /// Checks whether a user is required to verify their email before accessing the application.
  /// Only new users registered with requires_email_verification: true are subject to verification.
  /// Legacy/current users bypass this requirement.
  Future<bool> userRequiresEmailVerification(User user) async {
    final isGoogleUser = user.providerData.any(
      (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
    );
    if (isGoogleUser || user.emailVerified) {
      return false;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      return doc.data()?['requires_email_verification'] == true;
    } catch (e) {
      debugPrint('Error checking userRequiresEmailVerification: $e');
      return false;
    }
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  Future<bool> isEmailTaken(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if email is taken: $e');
      return false;
    }
  }

  /// Deactivates the current user's account by marking `is_active: false` and `status: 'deactivated'` in Firestore and signing out.
  Future<void> deactivateAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Guard: Administrator accounts cannot be deactivated
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final role = (userDoc.data()?['role'] as String?)?.toUpperCase();
      if (role == 'ADMIN' || role == 'SUPERADMIN') {
        throw FirebaseAuthException(
          code: 'admin-deactivation-forbidden',
          message: 'Administrator accounts cannot be deactivated.',
        );
      }
    }

    await _firestore.collection('users').doc(uid).set({
      'is_active': false,
      'status': 'deactivated',
      'deactivated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await signOut();
  }
}

class _GoogleRoleSelectionDialog extends StatefulWidget {
  const _GoogleRoleSelectionDialog();

  @override
  State<_GoogleRoleSelectionDialog> createState() => _GoogleRoleSelectionDialogState();
}

class _GoogleRoleSelectionDialogState extends State<_GoogleRoleSelectionDialog> {
  String _selectedRole = 'LEARNER';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF81B655).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_pin_rounded, color: Color(0xFF81B655), size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose Your Role',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome to Grammatica! How will you use your account?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleOption(
              role: 'LEARNER',
              title: 'Learner',
              subtitle: 'Access interactive lessons, AI quizzes, and practice tools.',
              icon: Icons.school_rounded,
              color: const Color(0xFF81B655),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildRoleOption(
              role: 'VALIDATOR',
              title: 'Validator',
              subtitle: 'Review and validate educational lessons created by educators.',
              icon: Icons.verified_rounded,
              color: const Color(0xFF3B82F6),
              isDark: isDark,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81B655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, _selectedRole),
            child: Text(
              'Continue as ${_selectedRole == "VALIDATOR" ? "Validator" : "Learner"}',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

