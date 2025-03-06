import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(subscriptionService.userId)
                    .get();
                final status = userDoc.data()?['subscriptionStatus'] ?? 'none';
                final currentPlan = userDoc.data()?['currentPlan'] ?? 'none';

                // Calculate amount to pay (same as SubscriptionService)
                final currentPlanCost = currentPlan == 'none' ? 0 : subscriptionService.plans[currentPlan]!['cost'] as int;
                final newPlanCost = subscriptionService.plans[plan]!['cost'] as int;
                final amountToPay = newPlanCost - currentPlanCost > 0 ? newPlanCost - currentPlanCost : 0;

                String actionMessage;
                if (status == 'active' && currentPlan != plan) {
                  await subscriptionService.upgradeOrDowngradePlan(plan, context);
                  actionMessage = 'Upgraded/Downgraded to $plan for $amountToPay';
                } else if (status == 'expired' || status == 'inactive') {
                  await subscriptionService.resubscribeAfterExpiry(plan, context);
                  actionMessage = 'Resubscribed to $plan for $newPlanCost';
                } else {
                  await subscriptionService.subscribeToPlan(plan, context);
                  actionMessage = 'Subscribed to $plan for $newPlanCost';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(actionMessage)),
                );
                // Pass both plan and amountToPay to PaymentScreen
                Navigator.pushNamed(context, '/payment', arguments: {'plan': plan, 'amount': amountToPay});
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