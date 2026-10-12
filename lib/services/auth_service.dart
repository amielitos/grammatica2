import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';
import 'email_sender_service.dart';

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
  static bool justSignedUpWithGoogle = false;

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

  Future<bool> _ensureUserDocumentExists(User? user) async {
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'LEARNER',
          'status': 'ACTIVE',
          'subscription_status': 'NONE',
          'username': user.displayName ?? 'Google User',
          'photoUrl': user.photoURL ?? '',
          'has_completed_onboarding': false,
        });
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

  /// Fetches current lockout status for an email
  Future<LockoutStatus> getLockoutStatus(String email) async {
    final emailClean = email.trim().toLowerCase();
    if (emailClean.isEmpty) {
      return const LockoutStatus(isLocked: false, failedCount: 0);
    }
    try {
      final doc = await _firestore
          .collection('login_attempts')
          .doc(_emailDocId(emailClean))
          .get();
      if (!doc.exists) {
        return const LockoutStatus(isLocked: false, failedCount: 0);
      }
      final data = doc.data() ?? {};
      final failedCount = (data['failed_count'] as num?)?.toInt() ?? 0;
      final lockedUntilTs = data['locked_until'] as Timestamp?;

      if (lockedUntilTs != null) {
        final lockedUntilDate = lockedUntilTs.toDate();
        final now = DateTime.now();
        if (lockedUntilDate.isAfter(now)) {
          return LockoutStatus(
            isLocked: true,
            failedCount: failedCount,
            lockedUntil: lockedUntilDate,
            remainingDuration: lockedUntilDate.difference(now),
          );
        }
      }
      return LockoutStatus(
        isLocked: false,
        failedCount: failedCount,
      );
    } catch (e) {
      debugPrint('Error getting lockout status: $e');
      return const LockoutStatus(isLocked: false, failedCount: 0);
    }
  }

  /// Records a failed login attempt. Locks the account for 5 mins if 3 attempts reached.
  Future<LockoutStatus> _recordFailedAttempt(String email) async {
    final emailClean = email.trim().toLowerCase();
    final docRef = _firestore
        .collection('login_attempts')
        .doc(_emailDocId(emailClean));

    try {
      final doc = await docRef.get();
      int currentCount = 0;
      if (doc.exists) {
        final data = doc.data() ?? {};
        final lockedUntilTs = data['locked_until'] as Timestamp?;
        // If a previous lock expired, restart counting from 0
        if (lockedUntilTs != null &&
            lockedUntilTs.toDate().isBefore(DateTime.now())) {
          currentCount = 0;
        } else {
          currentCount = (data['failed_count'] as num?)?.toInt() ?? 0;
        }
      }
      currentCount += 1;

      if (currentCount >= maxFailedAttempts) {
        final lockUntil = DateTime.now().add(lockoutDuration);
        final lockUntilTs = Timestamp.fromDate(lockUntil);

        await docRef.set({
          'email': emailClean,
          'failed_count': currentCount,
          'last_failed_at': FieldValue.serverTimestamp(),
          'locked_until': lockUntilTs,
        }, SetOptions(merge: true));

        // Mirror to users collection if user doc exists
        String recipientName = 'Learner';
        try {
          final userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: emailClean)
              .limit(1)
              .get();
          if (userQuery.docs.isNotEmpty) {
            final uDoc = userQuery.docs.first;
            recipientName = (uDoc.data()['username'] ??
                    uDoc.data()['full_name'] ??
                    'Learner')
                .toString();
            await uDoc.reference.update({
              'locked_until': lockUntilTs,
            });
          }
        } catch (e) {
          debugPrint('Error syncing locked_until to user doc: $e');
        }

        // Send email alert asynchronously
        EmailSenderService.sendAccountLockedEmail(
          recipientEmail: emailClean,
          recipientName: recipientName,
          lockoutMinutes: lockoutDuration.inMinutes,
        ).catchError((e) {
          debugPrint('Error sending account locked email: $e');
          return false;
        });

        return LockoutStatus(
          isLocked: true,
          failedCount: currentCount,
          lockedUntil: lockUntil,
          remainingDuration: lockoutDuration,
        );
      } else {
        await docRef.set({
          'email': emailClean,
          'failed_count': currentCount,
          'last_failed_at': FieldValue.serverTimestamp(),
          'locked_until': null,
        }, SetOptions(merge: true));

        return LockoutStatus(
          isLocked: false,
          failedCount: currentCount,
        );
      }
    } catch (e) {
      debugPrint('Error recording failed login attempt: $e');
      return const LockoutStatus(isLocked: false, failedCount: 0);
    }
  }

  /// Clears failed attempts and unlocks account
  Future<void> resetLoginAttempts(String email, {String? uid}) async {
    final emailClean = email.trim().toLowerCase();
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
        // Initial Security Check: check if the user is deactivated
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        final status = (userData?['status'] as String?)?.toUpperCase();
        if (userDoc.exists && status == 'DEACTIVATED') {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'account-deactivated',
            message: 'Your account has been deactivated. Please contact support.',
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

  Future<UserCredential> googleSignIn() async {
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

      // Security Check: Deactivated Status
      final userDoc = await _firestore.collection('users').doc(userCredential.user?.uid).get();
      final status = (userDoc.data()?['status'] as String?)?.toUpperCase();
      if (userDoc.exists && status == 'DEACTIVATED') {
        await _auth.signOut();
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
          code: 'account-deactivated',
          message: 'Your account has been deactivated. Please contact support.',
        );
      }

      bool isNewUser = await _ensureUserDocumentExists(userCredential.user);
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
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred
        .user!; // User is guaranteed to be non-null after successful creation
    // Create users/{uid} with defaults and new fields
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'role': role.toUpperCase(),
      'status': 'ACTIVE',
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

  Future<void> signOut() async {
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
    _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Guard: Administrator and Superadmin accounts cannot be deleted
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final role = (userDoc.data()?['role'] as String?)?.toUpperCase();
      if (role == 'ADMIN' || role == 'SUPERADMIN') {
        throw FirebaseAuthException(
          code: 'admin-account-deletion-forbidden',
          message: 'Administrator accounts cannot be deleted.',
        );
      }
    }

    try {
      // 1. Delete all Firestore and Storage data
      await DatabaseService.instance.deleteUserAccount(uid);

      // 2. Delete the Auth user
      // Note: This may require recent authentication.
      // If it fails, the UI should catch it and handle re-authentication if necessary.
      await user.delete();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
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

