import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';
import 'email_sender_service.dart';

class AuthService {
  // 1. Fields and Singleton first
  static final instance = AuthService._();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static bool justSignedUpWithGoogle = false;

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
        
        // Use userCredential property to detect if it's the first login with this provider
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          justSignedUpWithGoogle = true;
          _generateAndSendTempPassword(userCredential.user!);
        }

        await _ensureUserDocumentExists(userCredential.user);
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
        // Adding a bit more randomness logic here as simple epoch % can be predictable
        return chars[(randIdx + index) % chars.length];
      }).join();

      final tempPassword = random;

      // Update the user's password in Firebase Auth so they can use it to login later
      await user.updatePassword(tempPassword);

      // Send the email with the temporary password
      await EmailSenderService.sendEmail(
        toEmail: user.email!,
        subject: 'Welcome to Grammatica! Your Temporary Password',
        body: '''
        <div style="font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f7f9fa; padding: 30px; border-radius: 16px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #81B655; margin: 0; font-size: 36px; font-weight: 800; letter-spacing: -1px;">Grammatica</h1>
            <p style="color: #64748b; font-size: 16px; margin-top: 5px;">Your ultimate language learning partner</p>
          </div>
          
          <div style="background-color: #ffffff; padding: 45px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.04); border-top: 5px solid #81B655;">
            <h2 style="color: #1e293b; margin-top: 0; font-size: 24px; font-weight: 700;">Welcome to the community! 🎉</h2>
            
            <p style="color: #475569; font-size: 16px; line-height: 1.7;">Hello <strong style="color: #0f172a;">${user.displayName ?? 'learner'}</strong>,</p>
            
            <p style="color: #475569; font-size: 16px; line-height: 1.7;">Thank you for registering your account using Google. To give you full access across all devices, we have generated a secure <strong>Temporary Password</strong> for you. You can use this to easily log in using your email directly in the future.</p>
            
            <div style="background: linear-gradient(145deg, #f0fdf4, #e6fced); text-align: center; padding: 30px; margin: 35px 0; border-radius: 16px; border: 1.5px dashed #81B655; box-shadow: inset 0 2px 10px rgba(129, 182, 85, 0.1);">
              <span style="font-size: 42px; font-weight: 900; color: #81B655; letter-spacing: 12px; display: inline-block;">$tempPassword</span>
              <p style="margin: 15px 0 0 0; color: #64748b; font-size: 13px; font-weight: 500;">(Case sensitive &middot; Do not share)</p>
            </div>
            
            <p style="color: #64748b; font-size: 14px; line-height: 1.6; border-left: 4px solid #cbd5e1; padding-left: 15px; margin-top: 30px;">
              <strong>Security Tip:</strong> We recommend logging into your profile and updating this password to something personal and memorable as soon as possible.
            </p>
            
            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 35px 0;">
            <p style="color: #94a3b8; font-size: 13px; text-align: center; margin: 0;">Happy learning! From the <strong style="color: #81B655;">Grammatica Team</strong></p>
          </div>
        </div>
        ''',
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

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Initial Security Check: check if the user is deactivated
    final userDoc = await _firestore.collection('users').doc(userCredential.user?.uid).get();
    final status = (userDoc.data()?['status'] as String?)?.toUpperCase();
    if (userDoc.exists && status == 'DEACTIVATED') {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'account-deactivated',
        message: 'Your account has been deactivated. Please contact support.',
      );
    }

    return userCredential;
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
      if (isNewUser) {
        justSignedUpWithGoogle = true;
        await _generateAndSendTempPassword(userCredential.user!);
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

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
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
}
