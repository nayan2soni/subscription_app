import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subscription_app/services/subscription_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SubscriptionService _service = SubscriptionService();
  late Timer _renewalTimer;
  User? _user;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _signIn();
    _renewalTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      if (_user != null) {
        try {
          await _service.checkAndRenewSubscriptions();
          print('Renewal check completed');
        } catch (e) {
          print('Renewal check failed: $e');
        }
      }
    });
    _checkRenewals();
  }

  Future<void> _signIn() async {
    try {
      print('Checking current user...');
      final auth = FirebaseAuth.instance;
      User? currentUser = auth.currentUser;
      if (currentUser == null) {
        print('No current user, attempting anonymous sign-in...');
        final userCredential = await auth.signInAnonymously().timeout(
          Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Sign-in timed out'),
        );
        currentUser = userCredential.user;
        print('Anonymous sign-in succeeded: UID=${currentUser?.uid}');
      } else {
        print('Existing user found: UID=${currentUser.uid}');
      }
      setState(() {
        _user = currentUser;
        _statusMessage = 'Signed in as: ${_user?.uid}';
      });
    } catch (e, stackTrace) {
      setState(() {
        _statusMessage = 'Sign-in failed: $e';
      });
      print('Sign-in failed with error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _checkRenewals() async {
    if (_user != null) {
      try {
        await _service.checkAndRenewSubscriptions();
        print('Initial renewal check completed');
      } catch (e) {
        print('Initial renewal check failed: $e');
      }
    } else {
      print('Skipping renewal check: User not signed in');
    }
  }

  @override
  void dispose() {
    _renewalTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Subscription App')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_statusMessage),
              SizedBox(height: 20),
              if (_user != null) ...[
                ElevatedButton(
                  onPressed: () async {
                    print('Button pressed: Subscribe to Basic');
                    try {
                      await _service.subscribeToPlan('basic');
                      print('Subscribed to Basic');
                    } catch (e) {
                      print('Subscribe failed: $e');
                    }
                  },
                  child: const Text('Subscribe to Basic'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    print('Button pressed: Upgrade to Premium');
                    try {
                      final result = await _service.upgradePlan('premium');
                      print(result['message']);
                    } catch (e) {
                      print('Upgrade failed: $e');
                    }
                  },
                  child: const Text('Upgrade to Premium'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    print('Button pressed: Cancel Subscription');
                    try {
                      await _service.cancelSubscription();
                      print('Subscription cancelled');
                    } catch (e) {
                      print('Cancel failed: $e');
                    }
                  },
                  child: const Text('Cancel Subscription'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    print('Button pressed: Check Renewal');
                    try {
                      await _service.checkAndRenewSubscriptions();
                      print('Renewal checked');
                    } catch (e) {
                      print('Renewal check failed: $e');
                    }
                  },
                  child: const Text('Check Renewal'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}