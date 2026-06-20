import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
          home: _AuthWrapper(),
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
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
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
                    p?['status'] == c?['status'];
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

            // Derive role and info status
            final roleStr = data['role'] as String?;
            final role = roleFromString(roleStr);

            final phone = data['phone_number'] as String?;
            final dobTimestamp = data['date_of_birth'] as Timestamp?;
            final hasMissingInfo =
                (phone == null || phone.isEmpty) || (dobTimestamp == null);

            final hasCompletedOnboarding =
                data['has_completed_onboarding'] ?? true;

            if (role == UserRole.admin ||
                role == UserRole.educator ||
                role == UserRole.validator ||
                role == UserRole.superadmin) {
              return AdminDashboard(
                user: user,
                role: role,
                userData: data,
                showProfileWarning: hasMissingInfo,
              );
            }

            if (!hasCompletedOnboarding && role == UserRole.learner) {
              return OnboardingPage(user: user);
            }

            return HomePage(
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
