import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grammatica/services/educator_subscription_service.dart';

void main() {
  group('Educator Subscription Service Tests', () {
    test('existing educator with isExistingEducator == true is recognized as existing and subscribed', () {
      final existingData = {
        'role': 'EDUCATOR',
        'isExistingEducator': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
      };

      expect(EducatorSubscriptionService.isExistingEducator(existingData), isTrue);
      expect(EducatorSubscriptionService.isSubscribed(existingData), isTrue);
    });

    test('educator with creation date before cutoff is recognized as existing and subscribed', () {
      final olderAccountData = {
        'role': 'EDUCATOR',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 15)),
      };

      expect(EducatorSubscriptionService.isExistingEducator(olderAccountData), isTrue);
      expect(EducatorSubscriptionService.isSubscribed(olderAccountData), isTrue);
    });

    test('educator with educatorStartDate before cutoff is recognized as existing and subscribed', () {
      final olderEducatorRoleData = {
        'role': 'EDUCATOR',
        'educatorStartDate': Timestamp.fromDate(DateTime(2026, 9, 20)),
      };

      expect(EducatorSubscriptionService.isExistingEducator(olderEducatorRoleData), isTrue);
      expect(EducatorSubscriptionService.isSubscribed(olderEducatorRoleData), isTrue);
    });

    test('new educator registered after cutoff without subscription is recognized as NOT existing and NOT subscribed', () {
      final newEducatorData = {
        'role': 'EDUCATOR',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 10)),
      };

      expect(EducatorSubscriptionService.isExistingEducator(newEducatorData), isFalse);
      expect(EducatorSubscriptionService.isSubscribed(newEducatorData), isFalse);
    });

    test('new educator registered after cutoff who has subscribed is recognized as subscribed', () {
      final subscribedNewEducator = {
        'role': 'EDUCATOR',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 10)),
        'has_educator_subscription': true,
        'educator_subscription_status': 'ACTIVE',
      };

      expect(EducatorSubscriptionService.isExistingEducator(subscribedNewEducator), isFalse);
      expect(EducatorSubscriptionService.isSubscribed(subscribedNewEducator), isTrue);
    });

    test('newly approved educator with isExistingEducator == false is NOT existing and NOT subscribed even if account is older', () {
      final newlyApprovedData = {
        'role': 'EDUCATOR',
        'isExistingEducator': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
        'educatorStartDate': Timestamp.fromDate(DateTime(2026, 11, 5)),
      };

      expect(EducatorSubscriptionService.isExistingEducator(newlyApprovedData), isFalse);
      expect(EducatorSubscriptionService.isSubscribed(newlyApprovedData), isFalse);
    });

    test('null user data returns false for both isExistingEducator and isSubscribed', () {
      expect(EducatorSubscriptionService.isExistingEducator(null), isFalse);
      expect(EducatorSubscriptionService.isSubscribed(null), isFalse);
    });

    test('applicationDisclaimer matches exact required message', () {
      expect(
        EducatorSubscriptionService.applicationDisclaimer,
        equals(
          'Uploading content to Grammatica requires you to be subscribed for 6\$ a month, would you like to proceed?',
        ),
      );
    });
  });
}

