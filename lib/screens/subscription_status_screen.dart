import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_app/services/subscription_service.dart';
import 'package:provider/provider.dart';

class SubscriptionStatusScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final subscriptionService = Provider.of<SubscriptionService>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Subscription Status')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) {
            return Center(child: Text('No subscription yet.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['subscriptionStatus'] ?? 'None';
          final plan = data['currentPlan'] ?? 'None';
          final renewalDate = (data['renewalDate'] as Timestamp?)?.toDate();

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $status', style: Theme.of(context).textTheme.headlineSmall),
                SizedBox(height: 10),
                Text('Plan: $plan', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 10),
                Text(
                  'Renewal Date: ${renewalDate != null ? renewalDate.toString() : 'N/A'}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await subscriptionService.checkAndRenewSubscriptions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Renewal checked')),
                    );
                  },
                  child: Text('Check Renewal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await subscriptionService.cancelSubscription();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Subscription cancelled')),
                    );
                  },
                  child: Text('Cancel Subscription'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
