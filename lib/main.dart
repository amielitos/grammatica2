import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/role_service.dart';
import 'services/navigation.dart';

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

          // Ensure user document exists then route based on role
          return FutureBuilder(
            future: RoleService.instance.ensureUserDocument(user),
            builder: (context, _) {
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
