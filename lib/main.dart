import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../firebase_options.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/signin.dart';
import 'screens/profile_screen.dart';
import 'screens/verify_email_screen.dart';

import 'screens/splash_screen.dart';

void main() async{
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Aidora',
            themeMode: themeProvider.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            routes: {
              '/home': (_) => const HomeScreen(),
              '/requests': (_) => const HomeScreen(initialIndex: 1),
              '/chat': (_) => const HomeScreen(initialIndex: 2),
              '/profile': (_) => const ProfileScreen(),
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Only allow verified users to enter the app
          if (user.emailVerified) {
            return const HomeScreen();
          } else {
            return VerifyEmailScreen(user: user);
          }
        }

        return const SignInScreen();
      },
    );
  }
}
