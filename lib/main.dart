import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/role_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

// Pages
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/otp_verification_page.dart';
import 'pages/force_reset_password_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Dotenv initialization note: $e');
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: "assets/env");
      } catch (fallbackError) {
        debugPrint('Fallback dotenv initialization note: $fallbackError');
      }
    }
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// AppCheck disabled for production to avoid 403 token fetch error without reCAPTCHA setup


  if (kIsWeb) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        webExperimentalForceLongPolling: true,
      );
    } catch (e) {
      debugPrint('Firestore initialization error: $e');
    }
  }

  runApp(const GrammaticaApp());
}

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
final notificationVisibleNotifier = ValueNotifier<bool>(false);

class GrammaticaApp extends StatelessWidget {
  const GrammaticaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          scaffoldMessengerKey: AuthService.messengerKey,
          title: 'Grammatica',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            final screenWidth = mediaQueryData.size.width;
            double scale = 1.0;
            if (screenWidth < 360) {
              scale = (screenWidth / 360).clamp(0.85, 1.0);
            } else if (screenWidth > 1200) {
              scale = 1.05;
            }

            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            );
          },
          home: const _AuthWrapper(key: ValueKey('grammatica_auth_wrapper')),
          routes: {
            '/login': (context) => const LoginPage(),
            '/register': (context) => const SignupPage(),
          },
        );
      },
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.userChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final user = authSnap.data;
        if (user == null) {
          return Theme(data: AppTheme.lightTheme, child: const LandingPage());
        }

        // Single Firestore listener for the user's document
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots()
              .distinct((prev, curr) {
                final p = prev.data();
                final c = curr.data();
                return p?['role'] == c?['role'] &&
                    p?['has_completed_onboarding'] ==
                        c?['has_completed_onboarding'] &&
                    p?['phone_number'] == c?['phone_number'] &&
                    p?['date_of_birth'] == c?['date_of_birth'] &&
                    p?['photoUrl'] == c?['photoUrl'] &&
                    p?['username'] == c?['username'] &&
                    p?['status'] == c?['status'] &&
                    p?['requires_email_verification'] ==
                        c?['requires_email_verification'];
              }),
          builder: (context, userDocSnap) {
            if (userDocSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (!userDocSnap.hasData || !(userDocSnap.data?.exists ?? false)) {
              // Auto-create missing user document in Firestore to prevent infinite loading
              FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'uid': user.uid,
                'email': user.email ?? '',
                'createdAt': FieldValue.serverTimestamp(),
                'role': 'LEARNER',
                'status': 'ACTIVE',
                'subscription_status': 'NONE',
                'username': user.displayName ?? ((user.email != null && user.email!.contains('@')) ? user.email!.split('@')[0] : 'Grammatica Learner'),
                'photoUrl': user.photoURL ?? '',
                'has_completed_onboarding': false,
              }, SetOptions(merge: true));

              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text("Setting up your account..."),
                    ],
                  ),
                ),
              );
            }

            final data = userDocSnap.data?.data() ?? {};

            // Security Check: Deactivated Status
            final status = (data['status'] as String?)?.toUpperCase();
            if (status == 'DEACTIVATED') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AuthService.instance.signOut();
                AuthService.showSnackBar(
                  'Your account has been deactivated. Please contact support.',
                );
              });
              return Theme(
                data: AppTheme.lightTheme,
                child: const LandingPage(),
              );
            }

            // Email verification check: ONLY applies to new users starting now.
            // Legacy / current users bypass email verification.
            final isGoogleUser = user.providerData.any(
              (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
            );
            final bool requiresEmailVerification = (data['requires_email_verification'] == true);
            if (!isGoogleUser && requiresEmailVerification && !user.emailVerified) {
              return OtpVerificationPage(
                email: user.email ?? '',
              );
            }

            // Sync theme preference
            final themePref = data['theme_preference'] as String?;
            if (themePref != null) {
              final mode = themePref == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.light;
              if (themeNotifier.value != mode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  themeNotifier.value = mode;
                });
              }
            }

            // Mandatory temporary password reset check
            if (data['mustResetPassword'] == true) {
              return ForceResetPasswordPage(user: user);
            }

            // Derive role and info status
            final roleStr = (data['role'] as String?) ?? 'LEARNER';
            final role = roleFromString(roleStr);

            final phone = data['phone_number'] as String?;
            final dobTimestamp = data['date_of_birth'] as Timestamp?;
            final hasMissingInfo =
                (phone == null || phone.isEmpty) || (dobTimestamp == null);

            // Explicit cast to bool? to prevent TypeError on Flutter Web
            // where dynamic null throws: 'Null' is not a subtype of 'bool'
            final hasCompletedOnboarding =
                (data['has_completed_onboarding'] as bool?) ?? true;

            if (role == UserRole.admin ||
                role == UserRole.educator ||
                role == UserRole.validator ||
                role == UserRole.superadmin) {
              return AdminDashboard(
                key: ValueKey('admin_${user.uid}'),
                user: user,
                role: role,
                userData: data,
                showProfileWarning: hasMissingInfo,
              );
            }

            if (hasCompletedOnboarding == false && role == UserRole.learner) {
              return OnboardingPage(user: user);
            }

            return HomePage(
              key: ValueKey('home_${user.uid}'),
              user: user,
              role: role,
              userData: data,
              showProfileWarning: hasMissingInfo,
            );
          },
        );
      },
    );
  }
}
