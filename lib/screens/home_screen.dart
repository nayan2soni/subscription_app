import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:subscription_app/main.dart';
import 'package:subscription_app/screens/login_screen.dart';
import 'package:subscription_app/services/subscription_service.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final subscriptionService = Provider.of<SubscriptionService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription App'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.light
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/plans'),
              child: Text('Select Plan'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/status'),
              child: Text('View Subscription Status'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await subscriptionService.checkAndRenewSubscriptions();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renewal checked')),
                );
              },
              child: Text('Check Renewal Manually'),
            ),
          ],
        ),
      ),
    );
  }
}