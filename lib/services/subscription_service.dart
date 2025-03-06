import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser!.uid;

  final Map<String, Map<String, dynamic>> plans = {
    'basic': {'cost': 500, 'validityDays': 30},
    'premium': {'cost': 1000, 'validityDays': 30},
    'enterprise': {'cost': 2000, 'validityDays': 30},
  };

  Future<bool> subscribeToPlan(String planId, BuildContext context) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();
    final now = DateTime.now().toUtc();

    try {
      final newRenewalDate = now.add(Duration(days: plans[planId]!['validityDays'] as int));
      if (userSnapshot.exists) {
        final data = userSnapshot.data() as Map<String, dynamic>;
        final status = data['subscriptionStatus'] ?? 'none';

        if (status == 'active') {
          final renewalDate = (data['renewalDate'] as Timestamp).toDate();
          await userDoc.update({
            'renewalDate': renewalDate.add(Duration(days: plans[planId]!['validityDays'] as int)),
            'lastPaymentDate': now,
            'currentPlan': planId,
          });
        } else {
          await userDoc.set({
            'userId': userId,
            'email': _auth.currentUser!.email ?? 'anonymous',
            'currentPlan': planId,
            'renewalDate': newRenewalDate,
            'subscriptionStatus': 'active',
            'lastPaymentDate': now,
            'gracePeriodEnd': null,
          }, SetOptions(merge: true));
        }
      } else {
        await userDoc.set({
          'userId': userId,
          'email': _auth.currentUser!.email ?? 'anonymous',
          'currentPlan': planId,
          'renewalDate': newRenewalDate,
          'subscriptionStatus': 'active',
          'lastPaymentDate': now,
          'walletBalance': 0,
        });
      }

      await _addTransaction(planId, 'completed');
      return true;
    } catch (e) {
      print('Subscription error: $e');
      return false;
    }
  }

  Future<bool> upgradeOrDowngradePlan(String newPlanId, BuildContext context) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();
    final now = DateTime.now().toUtc();

    if (!userSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No active subscription to upgrade.')));
      return false;
    }

    final data = userSnapshot.data() as Map<String, dynamic>;
    final currentPlan = data['currentPlan'] ?? 'none';
    final renewalDate = (data['renewalDate'] as Timestamp?)?.toDate();
    final status = data['subscriptionStatus'] ?? 'none';
    final walletBalance = data['walletBalance'] as int? ?? 0;

    if (status != 'active' || renewalDate == null || renewalDate.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subscription not active for upgrade.')));
      return false;
    }

    try {
      final currentPlanCost = plans[currentPlan]!['cost'] as int;
      final newPlanCost = plans[newPlanId]!['cost'] as int;
      int amountToPay = newPlanCost - currentPlanCost;

      String message;
      if (amountToPay < 0) {
        // Downgrade: Credit excess to wallet
        final credit = -amountToPay;
        amountToPay = 0;
        await userDoc.update({
          'walletBalance': walletBalance + credit,
        });
        message = '$credit credited to wallet';
      } else if (amountToPay > 0 && walletBalance >= amountToPay) {
        // Upgrade: Debit from wallet if enough balance
        await userDoc.update({
          'walletBalance': walletBalance - amountToPay,
        });
        message = 'Paid $amountToPay from wallet';
        amountToPay = 0;
      } else {
        // Upgrade: Pay cash if wallet insufficient
        message = amountToPay > 0 ? 'Plan changed to $newPlanId for $amountToPay' : 'Plan changed to $newPlanId';
      }

      final newRenewalDate = now.add(Duration(days: plans[newPlanId]!['validityDays'] as int));
      await userDoc.update({
        'currentPlan': newPlanId,
        'renewalDate': newRenewalDate,
        'lastPaymentDate': now,
        'subscriptionStatus': 'active',
      });

      if (amountToPay > 0) {
        await _addTransaction(newPlanId, 'completed', amount: amountToPay);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return true;
    } catch (e) {
      print('Upgrade error: $e');
      return false;
    }
  }

  Future<void> checkAndRenewSubscriptions() async {
    final now = DateTime.now().toUtc();
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();
    if (!userSnapshot.exists) return;

    final data = userSnapshot.data() as Map<String, dynamic>;
    final renewalDate = (data['renewalDate'] as Timestamp?)?.toDate();
    final status = data['subscriptionStatus'] ?? 'none';
    final currentPlan = data['currentPlan'] ?? 'none';

    if (status == 'active' && renewalDate != null && renewalDate.isBefore(now)) {
      final recentTransactions = await _firestore
          .collection('users/$userId/transactions')
          .where('timestamp', isGreaterThan: now.subtract(Duration(minutes: 5)))
          .where('status', isEqualTo: 'completed')
          .get();
      if (recentTransactions.docs.isNotEmpty) {
        print('Duplicate renewal prevented');
        return;
      }

      bool paymentSuccess = true;
      if (paymentSuccess) {
        final validityDays = plans[currentPlan]!['validityDays'] as int;
        final newRenewalDate = now.add(Duration(days: validityDays));

        await userDoc.update({
          'renewalDate': newRenewalDate,
          'lastPaymentDate': now,
          'subscriptionStatus': 'active',
          'gracePeriodEnd': null,
        });
        await _addTransaction(currentPlan, 'completed');
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

    final data = userSnapshot.data() as Map<String, dynamic>;
    final renewalDate = (data['renewalDate'] as Timestamp?)?.toDate();
    final now = DateTime.now().toUtc();

    if (renewalDate != null && renewalDate.isAfter(now)) {
      await userDoc.update({
        'subscriptionStatus': 'active',
      });
    } else {
      await userDoc.update({
        'subscriptionStatus': 'inactive',
        'currentPlan': 'none',
        'renewalDate': null,
        'lastPaymentDate': null,
        'gracePeriodEnd': null,
      });
    }
  }

  Future<void> _addTransaction(String planId, String status, {int amount = 0}) async {
    await _firestore.collection('users/$userId/transactions').add({
      'planId': planId,
      'amount': amount > 0 ? amount : plans[planId]!['cost'] as int,
      'timestamp': DateTime.now().toUtc(),
      'status': status,
    });
  }

  Future<bool> resubscribeAfterExpiry(String planId, BuildContext context) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();
    final now = DateTime.now().toUtc();

    if (userSnapshot.exists) {
      final data = userSnapshot.data() as Map<String, dynamic>;
      final status = data['subscriptionStatus'] ?? 'none';
      final renewalDate = data['renewalDate'] != null
          ? (data['renewalDate'] as Timestamp).toDate()
          : null;

      if (status == 'expired' && (renewalDate == null || renewalDate.isBefore(now))) {
        final newRenewalDate = now.add(Duration(days: plans[planId]!['validityDays'] as int));
        await userDoc.set({
          'currentPlan': planId,
          'renewalDate': newRenewalDate,
          'subscriptionStatus': 'active',
          'lastPaymentDate': now,
          'gracePeriodEnd': null,
        }, SetOptions(merge: true));
        await _addTransaction(planId, 'completed');
        return true;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot resubscribe: Subscription not expired.')));
    return false;
  }
}