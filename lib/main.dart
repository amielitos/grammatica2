import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/role_service.dart';
import 'services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pages
import 'pages/sign_in_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GrammaticaApp());
}

class GrammaticaApp extends StatelessWidget {
  const GrammaticaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grammatica',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges(),
        builder: (context, authSnap) {
          if (authSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = authSnap.data;
          if (user == null) return const SignInPage();

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
              if (!userDocSnap.hasData ||
                  !(userDocSnap.data?.exists ?? false)) {
                // User was removed from database; force sign out and show sign in
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await AuthService.instance.signOut();
                });
                return const SignInPage();
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
                  if (role == UserRole.admin) {
                    return AdminDashboard(user: user);
                  }
                  return HomePage(user: user);
                },
              );
            },
          );
        },
      ),
    );
  }
}
