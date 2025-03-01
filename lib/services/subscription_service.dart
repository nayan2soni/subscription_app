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

  Future<void> subscribeToPlan(String planId) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();
    final now = DateTime.now();

    if (userSnapshot.exists) {
      final data = userSnapshot.data()!;
      final currentPlan = data['currentPlan'] ?? 'none';
      final renewalDate = data['renewalDate'] != null
          ? (data['renewalDate'] as Timestamp).toDate()
          : null;

      if (currentPlan != 'none' && renewalDate!.isAfter(now)) {
        final newRenewalDate =
            renewalDate.add(Duration(days: plans[planId]!['validityDays']));
        await userDoc.update({
          'renewalDate': newRenewalDate,
          'lastPaymentDate': now,
        });
      } else {
        final newRenewalDate =
            now.add(Duration(days: plans[planId]!['validityDays']));
        await userDoc.set({
          'currentPlan': planId,
          'renewalDate': newRenewalDate,
          'subscriptionStatus': 'active',
          'lastPaymentDate': now,
          'gracePeriodEnd': null,
        }, SetOptions(merge: true));
      }
    } else {
      final newRenewalDate =
          now.add(Duration(days: plans[planId]!['validityDays']));
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
  }

  Future<void> checkAndRenewSubscriptions() async {
    final now = DateTime.now();
    final usersRef = _firestore.collection('users');
    const gracePeriodDays = 7;

    final expiredSubscriptions = await usersRef
        .where('renewalDate', isLessThanOrEqualTo: now)
        .where('subscriptionStatus', isEqualTo: 'active')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in expiredSubscriptions.docs) {
      final userData = doc.data();
      final userId = doc.id;
      final currentPlan = userData['currentPlan'];

      bool paymentSuccess = true;

      if (paymentSuccess) {
        final validityDays = plans[currentPlan]!['validityDays'] as int;
        final newRenewalDate = now.add(Duration(days: validityDays));

        await usersRef.doc(userId).update({
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
        final renewalDate = (userData['renewalDate'] as Timestamp).toDate();
        final gracePeriodEnd = renewalDate.add(Duration(days: gracePeriodDays));
        await usersRef.doc(userId).update({
          'subscriptionStatus': 'expired',
          'gracePeriodEnd': gracePeriodEnd,
        });
      }
    }
    print('Processed ${expiredSubscriptions.size} renewals for user $userId');
  }

  Future<Map<String, dynamic>> upgradePlan(String newPlanId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final now = DateTime.now();

    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data()!;
    final currentPlan = userData['currentPlan'] ?? 'none';
    final renewalDate = (userData['renewalDate'] as Timestamp).toDate();

    if (currentPlan == 'none' || renewalDate.isBefore(now)) {
      await subscribeToPlan(newPlanId);
      return {'message': 'Subscribed to new plan'};
    }

    final lastPaymentDate = (userData['lastPaymentDate'] as Timestamp).toDate();
    final daysUsed = now.difference(lastPaymentDate).inDays;
    final daysTotal = plans[currentPlan]!['validityDays'] as int;
    final remainingDays = daysTotal - daysUsed;
    final remainingBalance =
        ((plans[currentPlan]!['cost'] as int) * remainingDays / daysTotal).round();
    final adjustedCost =
        (plans[newPlanId]!['cost'] as int) - remainingBalance.clamp(0, double.infinity).toInt();

    final newRenewalDate = now.add(Duration(days: plans[newPlanId]!['validityDays'] as int));

    await userRef.update({
      'currentPlan': newPlanId,
      'renewalDate': newRenewalDate,
      'lastPaymentDate': now,
    });

    await _firestore.collection('users/$userId/transactions').add({
      'planId': newPlanId,
      'amount': adjustedCost,
      'timestamp': now,
      'status': 'completed',
    });

    return {'message': 'Plan upgraded successfully', 'newPlan': newPlanId};
  }

  Future<void> cancelSubscription() async {
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();

    if (!userSnapshot.exists) return;

    await userDoc.update({'subscriptionStatus': 'cancelled'});
  }

  Future<void> resubscribeAfterExpiry(String planId) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final userSnapshot = await userDoc.get();
    final now = DateTime.now();

    if (userSnapshot.exists) {
      final data = userSnapshot.data()!;
      final renewalDate = (data['renewalDate'] as Timestamp).toDate();
      if (data['subscriptionStatus'] == 'expired' && renewalDate.isBefore(now)) {
        await subscribeToPlan(planId);
      }
    }
  }

  Future<bool> hasRecentTransaction(String planId) async {
    final transactions = await _firestore
        .collection('users/$userId/transactions')
        .where('planId', isEqualTo: planId)
        .where('timestamp',
            isGreaterThan: DateTime.now().subtract(Duration(minutes: 5)))
        .get();
    return transactions.docs.isNotEmpty;
  }

  DateTime normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}