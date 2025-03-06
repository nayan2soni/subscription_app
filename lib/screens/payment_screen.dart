import 'package:flutter/material.dart';
import 'package:subscription_app/services/subscription_service.dart';
import 'package:provider/provider.dart';

class PaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Extract arguments
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final plan = args?['plan'] as String? ?? 'basic';
    final amountToPay = args?['amount'] as int? ?? 0;

    final subscriptionService = Provider.of<SubscriptionService>(context, listen: false);

    print('PaymentScreen - Plan: $plan, Amount to Pay: $amountToPay');

    return Scaffold(
      appBar: AppBar(title: Text('Payment')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              amountToPay > 0
                  ? 'Amount to Pay: $amountToPay'
                  : 'No additional payment required',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment Confirmed')),
                );
                Navigator.pushReplacementNamed(context, '/status');
              },
              child: Text('Confirm'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}