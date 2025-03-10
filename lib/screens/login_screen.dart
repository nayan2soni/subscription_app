import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:subscription_app/screens/home_screen.dart';
import 'package:subscription_app/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  String? _errorMessage;

  Future<void> _loginWithEmailPassword() async {
    setState(() => _errorMessage = null);
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _saveUserData(userCredential.user!);
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      setState(() => _errorMessage = 'Email Login failed: $e');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _errorMessage = null);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _errorMessage = 'Google Sign-In cancelled');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _saveUserData(userCredential.user!);
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      setState(() => _errorMessage = 'Google Sign-In failed: $e');
    }
  }

  Future<void> _saveUserData(User user) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userDoc.set({
      'userId': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? 'User',
      'lastLogin': DateTime.now().toUtc(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            if (_errorMessage != null)
              Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginWithEmailPassword,
              child: Text('Login with Email'),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.login),
              label: Text('Continue with Google'),
              onPressed: _signInWithGoogle,
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: Text('Don\'t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}