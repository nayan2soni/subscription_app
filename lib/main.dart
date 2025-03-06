import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:subscription_app/screens/home_screen.dart';
import 'package:subscription_app/screens/subscription_status_screen.dart';
import 'package:subscription_app/screens/plan_selection_screen.dart';
import 'package:subscription_app/screens/login_screen.dart';
import 'package:subscription_app/screens/signup_screen.dart';
import 'package:subscription_app/screens/payment_screen.dart';
import 'package:subscription_app/services/subscription_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider(create: (_) => SubscriptionService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print('Auth state: ${snapshot.data?.uid ?? "No user"}, Connection: ${snapshot.connectionState}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          return snapshot.hasData ? HomeScreen() : LoginScreen();
        },
      ),
      routes: {
        '/status': (context) => SubscriptionStatusScreen(),
        '/plans': (context) => PlanSelectionScreen(),
        '/payment': (context) => PaymentScreen(),
        '/signup': (context) => SignupScreen(),
      },
    );
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class AuthService {
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut(); // Clear Google Sign-In session
    print('Signed out from Firebase and Google');
  }
}