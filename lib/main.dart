import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/role_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';

// Pages
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GrammaticaApp());
}

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

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
            } else if (screenWidth > 600) {
              scale = 1.1; // Slightly larger for tablets
            }

            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
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
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = authSnap.data;
        if (user == null) {
          return Theme(data: AppTheme.lightTheme, child: const LoginPage());
        }

        // Verify user document exists. If missing (e.g., account deleted), sign out.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userDocSnap) {
            if (userDocSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!userDocSnap.hasData || !(userDocSnap.data?.exists ?? false)) {
              // Document creation might be in progress (race condition).
              // Show loading instead of signing out immediately.
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Setting up your account..."),
                    ],
                  ),
                ),
              );
            }
            final data = userDocSnap.data?.data();
            final themePref = data?['theme_preference'] as String?;
            if (themePref != null) {
              final mode = themePref == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.light;
              if (themeNotifier.value != mode) {
                // Update theme notifier from stored preference
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  themeNotifier.value = mode;
                });
              }
            }

            return StreamBuilder<UserRole>(
              stream: RoleService.instance.roleStream(user.uid),
              builder: (context, roleSnap) {
                if (!roleSnap.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final role = roleSnap.data!;
                if (role == UserRole.admin || role == UserRole.educator) {
                  return AdminDashboard(user: user);
                }

                final hasCompletedOnboarding =
                    data?['has_completed_onboarding'] ?? true;
                if (!hasCompletedOnboarding && role == UserRole.learner) {
                  return OnboardingPage(user: user);
                }

                return HomePage(user: user);
              },
            );
          },
        );
      },
    );
  }
}
