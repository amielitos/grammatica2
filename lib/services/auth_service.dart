import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class AuthService {
  AuthService._() {
    // Listen to Google Sign-In events (especially useful for Web GIS button)
    _googleSignIn.authenticationEvents.listen(_handleGoogleSignInEvent);

    // Initialize early on web to ensure GIS is ready for buttons
    if (kIsWeb) {
      _ensureGoogleSignInInitialized().catchError((e) {
        debugPrint('Early web GoogleSignIn initialization failed: $e');
      });
    }
  }
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;
  Future<void>? _googleSignInInit;

  Future<void> _handleGoogleSignInEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      try {
        final googleAuth = event.user.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        await _ensureUserDocumentExists(userCredential.user);
      } catch (e) {
        debugPrint('Error handling Google Sign-In event: $e');
      }
    }
  }

  Future<void> _ensureUserDocumentExists(User? user) async {
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
      }
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_isGoogleSignInInitialized) return;
    if (_googleSignInInit != null) return _googleSignInInit;

    _googleSignInInit = _googleSignIn.initialize(
      clientId: kIsWeb
          ? '458713583940-v6j8pjs8bj4ftmibm8ml78rl1qrm6ib5.apps.googleusercontent.com'
          : null,
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
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> googleSignIn() async {
    await _ensureGoogleSignInInitialized();

    // On web, authenticate() is not supported and throws UnimplementedError in this plugin.
    // The UI should show the official button instead.
    if (kIsWeb) {
      throw FirebaseAuthException(
        code: 'unsupported-platform',
        message:
            'Direct Google Sign-In is not supported on Web. Please use the Google Sign-In button.',
      );
    }

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
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
        message: 'Sign in failed: $e',
      );
    }

    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign in aborted by user',
      );
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    await _ensureUserDocumentExists(userCredential.user);
    return userCredential;
  }

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required DateTime dateOfBirth,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user != null) {
      // Create users/{uid} with defaults and new fields
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'LEARNER',
        'status': 'ACTIVE',
        'subscription_status': 'NONE',
        'username': fullName,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'date_of_birth': Timestamp.fromDate(dateOfBirth),
        'photoUrl': '', // Initialize with empty photo URL
        'has_completed_onboarding': false,
      });
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
          await _ensureGoogleSignInInitialized();
          await _googleSignIn.signOut();
        }
      }
    } catch (e) {
      debugPrint('Error during Google sign out: $e');
    }
    await _auth.signOut();
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
}
