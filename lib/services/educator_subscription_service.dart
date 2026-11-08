import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/paymongo_qr_dialog.dart';
import 'paymongo_service.dart';
import 'database_service.dart';
import 'idempotency_service.dart';

class EducatorSubscriptionService {
  EducatorSubscriptionService._();
  static final instance = EducatorSubscriptionService._();

  /// Cutoff: Any educator account created before November 5, 2026 is grandfathered as an existing educator.
  static final DateTime existingEducatorCutoff = DateTime(2026, 11, 5, 0, 0, 0);

  /// Default subscription amount for Grammatica Educator Platform plan (₱392.00 / ~$7.00 USD)
  static const double educatorSubscriptionAmountPhp = 392.0;

  /// Disclaimer shown to learners applying as an educator before submitting documents
  static const String applicationDisclaimer =
      'Uploading content to Grammatica requires you to be subscribed for 6\$ a month, would you like to proceed?';

  /// Returns true if the user is recognized as an existing educator on the system.
  static bool isExistingEducator(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    // Explicit flag takes highest priority
    if (userData['isExistingEducator'] == false) return false;
    if (userData['isExistingEducator'] == true) return true;

    // Account creation date check (grandfathered if account was created before cutoff)
    final createdAt = userData['createdAt'];
    if (createdAt is Timestamp && createdAt.toDate().isBefore(existingEducatorCutoff)) {
      return true;
    }

    // Educator start date check (grandfathered if educator start date was before cutoff)
    final educatorStartDate = userData['educatorStartDate'];
    if (educatorStartDate is Timestamp && educatorStartDate.toDate().isBefore(existingEducatorCutoff)) {
      return true;
    }

    return false;
  }

  /// Returns true if the educator has an active subscription or is grandfathered as an existing educator.
  static bool isSubscribed(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    // Existing educators on the system are completely exempt
    if (isExistingEducator(userData)) return true;

    // Active subscription flags
    if (userData['has_educator_subscription'] == true ||
        userData['hasEducatorSubscription'] == true ||
        userData['educator_subscription_status'] == 'ACTIVE' ||
        userData['subscription_status'] == 'ACTIVE') {
      return true;
    }

    return false;
  }

  /// Asynchronously checks subscription status in Firestore and ensures the educator is subscribed.
  /// If subscribed or existing, returns true immediately.
  /// Otherwise, displays the PayMongo QR dialog with "Simulate Payment".
  /// Unless they simulate/complete payment, they cannot proceed (returns false if cancelled/closed).
  static Future<bool> ensureSubscribed(
    BuildContext context, {
    required User user,
    Map<String, dynamic>? userData,
  }) async {
    Map<String, dynamic>? data = userData;

    // Always fetch fresh data if userData wasn't provided or subscription is not yet recognized
    if (data == null || !isSubscribed(data)) {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (snap.exists) {
          data = snap.data();
        }
      } catch (e) {
        debugPrint('[EducatorSubscriptionService] Error fetching user data: $e');
      }
    }

    // Existing or already subscribed educators proceed without barrier
    if (isSubscribed(data)) {
      return true;
    }

    if (!context.mounted) return false;

    final educatorDisplayName = data?['username'] ?? data?['full_name'] ?? user.displayName ?? 'Educator';
    final idempotencyKey = IdempotencyService.instance.generatePaymentKey(
      learnerUid: user.uid,
      educatorUid: 'grammatica_platform',
      tier: 'Educator Subscription',
    );

    // Show non-dismissible QR payment modal
    final paymentResult = await showDialog<PaymongoPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymongoQrDialog(
        tier: 'Educator Subscription',
        amount: educatorSubscriptionAmountPhp,
        educatorName: 'Grammatica',
        learnerName: educatorDisplayName,
        learnerEmail: user.email,
        idempotencyKey: idempotencyKey,
        customTitle: 'Grammatica Educator Subscription',
        customSubtitle: 'Grammatica Educator Subscription - Upload Content & Mentorship',
        customNotice: 'Subscribe to Grammatica to upload content and use the mentorship system.',
        customSuccessMessage:
            'You are now subscribed to Grammatica! You can now create lessons, upload content, and use the mentorship system.',
      ),
    );

    if (paymentResult != null && paymentResult.isSuccess) {
      await DatabaseService.instance.recordEducatorSubscriptionPayment(
        educatorUid: user.uid,
        educatorEmail: user.email ?? '',
        educatorName: educatorDisplayName,
        referenceNumber: paymentResult.referenceNumber,
        paymentMethod: paymentResult.paymentMethod,
        amount: paymentResult.amount,
        paymongoLinkId: paymentResult.linkId,
        idempotencyKey: paymentResult.idempotencyKey ?? idempotencyKey,
      );
      return true;
    }

    // User cancelled or closed dialog without payment -> do not proceed to target action
    return false;
  }
}
