import 'package:flutter/material.dart';
import 'package:subscription_app/services/subscription_service.dart';
import 'package:provider/provider.dart';

class PlanSelectionScreen extends StatelessWidget {
  final plans = ['basic', 'premium', 'enterprise'];

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Select Plan')),
      body: ListView.builder(
        itemCount: plans.length,
        itemBuilder: (context, index) {
          final plan = plans[index];
          final details = subscriptionService.plans[plan]!;
          return ListTile(
            title: Text(plan.capitalize()),
            subtitle: Text('Cost: ${details['cost']} | Validity: ${details['validityDays']} days'),
            onTap: () async {
              try {
                await subscriptionService.subscribeToPlan(plan);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Subscribed to $plan')),
                );
                Navigator.pop(context);
                Navigator.pushNamed(context, '/status');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          );
        },
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}
