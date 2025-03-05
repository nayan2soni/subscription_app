import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser!.uid;

  final Map<String, Map<String, dynamic>> plans = {
    'basic': {'cost': 500, 'validityDays': 30},
    'premium': {'cost': 1000, 'validityDays': 30},
    'enterprise': {'cost': 2000, 'validityDays': 30},
  };

Future<bool> subscribeToPlan(String planId) async {
  final userDoc = _firestore.collection('users').doc(userId);
  final userSnapshot = await userDoc.get();
  final now = DateTime.now();

  try {
    if (userSnapshot.exists) {
      final data = userSnapshot.data()!;
      final currentPlan = data['currentPlan'] ?? 'none';
      final renewalDate = data['renewalDate'] != null
          ? (data['renewalDate'] as Timestamp).toDate()
          : null;

      if (currentPlan != 'none' && renewalDate!.isAfter(now)) {
        final newRenewalDate = renewalDate.add(Duration(days: plans[planId]!['validityDays']));
        await userDoc.update({
          'renewalDate': newRenewalDate,
          'lastPaymentDate': now,
        });
      } else {
        final newRenewalDate = now.add(Duration(days: plans[planId]!['validityDays']));
        await userDoc.set({
          'currentPlan': planId,
          'renewalDate': newRenewalDate,
          'subscriptionStatus': 'active',
          'lastPaymentDate': now,
          'gracePeriodEnd': null,
        }, SetOptions(merge: true));
      }
    } else {
      final newRenewalDate = now.add(Duration(days: plans[planId]!['validityDays']));
      await userDoc.set({
        'userId': userId,
        'email': _auth.currentUser!.email ?? 'anonymous',
        'currentPlan': planId,
        'renewalDate': newRenewalDate,
        'subscriptionStatus': 'active',
        'lastPaymentDate': now,
      });
    }

    await _firestore.collection('users/$userId/transactions').add({
      'planId': planId,
      'amount': plans[planId]!['cost'],
      'timestamp': now,
      'status': 'completed',
    });
    return true; // Success
  } catch (e) {
    print('Subscription error: $e');
    return false; // Failure
  }
}

  Future<void> checkAndRenewSubscriptions() async {
  final now = DateTime.now();
  final userDoc = _firestore.collection('users').doc(userId);

  final userSnapshot = await userDoc.get();
  if (!userSnapshot.exists) return;

  final userData = userSnapshot.data()!;
  final renewalDate = (userData['renewalDate'] as Timestamp?)?.toDate();
  final status = userData['subscriptionStatus'] ?? 'none';
  final currentPlan = userData['currentPlan'] ?? 'none';

  if (status == 'active' && renewalDate != null && renewalDate.isBefore(now)) {
    bool paymentSuccess = true; // Replace with real payment logic later

    if (paymentSuccess) {
      final validityDays = plans[currentPlan]!['validityDays'] as int;
      final newRenewalDate = now.add(Duration(days: validityDays));

      await userDoc.update({
        'renewalDate': newRenewalDate,
        'lastPaymentDate': now,
        'subscriptionStatus': 'active',
        'gracePeriodEnd': null,
      });

      await _firestore.collection('users/$userId/transactions').add({
        'planId': currentPlan,
        'amount': plans[currentPlan]!['cost'],
        'timestamp': now,
        'status': 'completed',
      });
    } else {
      const gracePeriodDays = 7;
      final gracePeriodEnd = renewalDate.add(Duration(days: gracePeriodDays));
      await userDoc.update({
        'subscriptionStatus': 'expired',
        'gracePeriodEnd': gracePeriodEnd,
      });
    }
  }
  print('Renewal check completed for user $userId');
}

  Future<void> cancelSubscription() async {
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();

    if (!userSnapshot.exists) return;

    await userDoc.update({'subscriptionStatus': 'cancelled'});
  }
}
