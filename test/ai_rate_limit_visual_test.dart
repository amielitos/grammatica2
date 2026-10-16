import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:grammatica/services/ai_rate_limit_service.dart';
import 'package:grammatica/services/role_service.dart';
import 'package:grammatica/widgets/ai_quota_notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Visual AI Rate Limiting & Quota Tests', () {
    test('AIRateLimitStatus calculates remaining and percentage accurately', () {
      // 1. Normal learner quota: 3 used out of 10
      const statusNormal = AIRateLimitStatus(
        used: 3,
        limit: 10,
        date: '2026-10-17',
        role: UserRole.learner,
        isSubscribed: false,
      );

      expect(statusNormal.isUnlimited, isFalse);
      expect(statusNormal.remaining, 7);
      expect(statusNormal.percentUsed, 0.3);
      expect(statusNormal.isExceeded, isFalse);

      // 2. Low quota: 9 used out of 10
      const statusLow = AIRateLimitStatus(
        used: 9,
        limit: 10,
        date: '2026-10-17',
        role: UserRole.learner,
        isSubscribed: false,
      );
      expect(statusLow.remaining, 1);
      expect(statusLow.percentUsed, 0.9);
      expect(statusLow.isExceeded, isFalse);

      // 3. Exhausted quota: 10 used out of 10
      const statusExceeded = AIRateLimitStatus(
        used: 10,
        limit: 10,
        date: '2026-10-17',
        role: UserRole.learner,
        isSubscribed: false,
      );
      expect(statusExceeded.remaining, 0);
      expect(statusExceeded.percentUsed, 1.0);
      expect(statusExceeded.isExceeded, isTrue);

      // 4. Unlimited quota (admin)
      const statusAdmin = AIRateLimitStatus(
        used: 45,
        limit: -1,
        date: '2026-10-17',
        role: UserRole.admin,
        isSubscribed: false,
      );
      expect(statusAdmin.isUnlimited, isTrue);
      expect(statusAdmin.remaining, 999999);
      expect(statusAdmin.percentUsed, 0.0);
      expect(statusAdmin.isExceeded, isFalse);
    });

    testWidgets('AIQuotaNotification shows popup banner with remaining count', (tester) async {
      const status = AIRateLimitStatus(
        used: 3,
        limit: 10,
        date: '2026-10-17',
        role: UserRole.learner,
        isSubscribed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AIQuotaNotification.show(
                    context,
                    status: status,
                    title: 'Flashcards Generated',
                  );
                },
                child: const Text('Trigger AI'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger AI'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300)); // Finish entrance

      expect(find.text('Flashcards Generated'), findsOneWidget);
      expect(find.text('7 LEFT'), findsOneWidget);
      expect(find.textContaining('7 of 10 generations left today'), findsOneWidget);
    });

    testWidgets('AIQuotaNotification displays Unlimited for administrator', (tester) async {
      const adminStatus = AIRateLimitStatus(
        used: 5,
        limit: -1,
        date: '2026-10-17',
        role: UserRole.admin,
        isSubscribed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AIQuotaNotification.show(
                    context,
                    status: adminStatus,
                    title: 'Assessment Generated',
                  );
                },
                child: const Text('Trigger Admin AI'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Admin AI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Assessment Generated'), findsOneWidget);
      expect(find.text('UNLIMITED'), findsOneWidget);
      expect(find.textContaining('Unlimited AI generations left today'), findsOneWidget);
    });
  });
}
