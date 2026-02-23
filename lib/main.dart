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
      // Clear any corrupted persistence state on web to fix b815 assertion
      await FirebaseFirestore.instance.clearPersistence();
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
          title: 'Grammatica',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            // Calculate a scale factor based on screen width.
            // On very small screens (< 360), we scale down slightly.
            // On large screens, we might scale up or keep 1.0.
            final screenWidth = mediaQueryData.size.width;
            double scale = 1.0;
            if (screenWidth < 360) {
              scale = (screenWidth / 360).clamp(0.85, 1.0);
            } else if (screenWidth > 1200) {
              scale = 1.05; // Less aggressive scaling for large screens
            }

            return Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => MediaQuery(
                    data: mediaQueryData.copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.getMainGradient(context),
                      ),
                      child: child!,
                    ),
                  ),
                ),
              ],
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => _AuthWrapper(),
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
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          );
        }
        final user = authSnap.data;
        if (user == null) {
          return Theme(data: AppTheme.lightTheme, child: const LoginPage());
        }

        // Single Firestore listener for the user's document
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userDocSnap) {
            if (userDocSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            }
            if (!userDocSnap.hasData || !(userDocSnap.data?.exists ?? false)) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primaryGreen),
                      SizedBox(height: 16),
                      Text("Setting up your account..."),
                    ],
                  ),
                ),
              );
            }

            final data = userDocSnap.data?.data() ?? {};

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

            if (role == UserRole.admin || role == UserRole.educator) {
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
