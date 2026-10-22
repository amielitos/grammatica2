import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/services/idempotency_service.dart';
import 'package:grammatica/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Idempotency System Architecture Tests', () {
    late IdempotencyService service;

    setUp(() {
      service = IdempotencyService.instance;
    });

    test('UUID v4 generator produces valid RFC 4122 compliant UUID strings', () {
      final uuid1 = service.generateUuidV4();
      final uuid2 = service.generateUuidV4();

      expect(uuid1.length, equals(36));
      expect(uuid2.length, equals(36));
      expect(uuid1, isNot(equals(uuid2)));

      final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(uuid1), isTrue,
          reason: '$uuid1 should match RFC 4122 v4 format');
      expect(uuidRegex.hasMatch(uuid2), isTrue,
          reason: '$uuid2 should match RFC 4122 v4 format');
    });

    test('Deterministic payment key generator produces scoped keys', () {
      const learnerUid = 'learner_123';
      const educatorUid = 'educator_456';
      const tier = 'Premium';
      const salt = 'session_789';

      final key1 = service.generatePaymentKey(
        learnerUid: learnerUid,
        educatorUid: educatorUid,
        tier: tier,
        sessionSalt: salt,
      );

      final key2 = service.generatePaymentKey(
        learnerUid: learnerUid,
        educatorUid: educatorUid,
        tier: tier,
        sessionSalt: salt,
      );

      expect(key1, equals(key2));
      expect(key1, equals('pay_learner_123_educator_456_premium_session_789'));
    });

    test('Deterministic mentorship key generator formats properly', () {
      final time = DateTime(2026, 10, 23, 14, 30);
      final key = service.generateMentorshipKey(
        educatorUid: 'edu_1',
        studentUid: 'stu_2',
        startTime: time,
      );

      expect(key,
          equals('mentor_edu_1_stu_2_${time.millisecondsSinceEpoch}'));
    });

    test('Deterministic AI generation key computes stable hashes', () {
      final key1 = service.generateAiKey(
        action: 'quiz',
        contentSnippet: 'Grammar lesson on past participles',
      );

      final key2 = service.generateAiKey(
        action: 'quiz',
        contentSnippet: 'Grammar lesson on past participles',
      );

      expect(key1, equals(key2));
      expect(key1.startsWith('ai_quiz_'), isTrue);
    });

    test('buildHeaders attaches Idempotency-Key and X-Idempotency-Key', () {
      const customKey = 'test-idempotency-key-123';
      final headers = service.buildHeaders(
        key: customKey,
        baseHeaders: {'Authorization': 'Bearer token'},
      );

      expect(headers['Idempotency-Key'], equals(customKey));
      expect(headers['X-Idempotency-Key'], equals(customKey));
      expect(headers['Authorization'], equals('Bearer token'));
    });

    test('In-flight single-flight coalesces concurrent duplicate calls into 1 execution',
        () async {
      int executionCount = 0;

      Future<String> slowOperation() async {
        executionCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'result_$executionCount';
      }

      const testKey = 'concurrent_payment_test';

      // Launch 3 simultaneous executions with the same idempotency key
      final future1 = service.executeDeduplicated(key: testKey, action: slowOperation);
      final future2 = service.executeDeduplicated(key: testKey, action: slowOperation);
      final future3 = service.executeDeduplicated(key: testKey, action: slowOperation);

      final results = await Future.wait([future1, future2, future3]);

      // All 3 callers must get the EXACT same return value
      expect(results[0], equals('result_1'));
      expect(results[1], equals('result_1'));
      expect(results[2], equals('result_1'));

      // The underlying operation must have executed ONLY ONCE!
      expect(executionCount, equals(1));
    });

    test('Sequential calls with different keys execute independently', () async {
      int count = 0;

      final r1 = await service.executeDeduplicated(
        key: 'key_a',
        action: () async => ++count,
      );
      final r2 = await service.executeDeduplicated(
        key: 'key_b',
        action: () async => ++count,
      );

      expect(r1, equals(1));
      expect(r2, equals(2));
      expect(count, equals(2));
    });

    test('PaymentRecordResult holds success, duplicate status, and payment ID', () {
      const freshResult = PaymentRecordResult(
        isSuccess: true,
        isDuplicate: false,
        paymentId: 'pay_PM-12345',
        message: 'Payment recorded successfully.',
      );

      expect(freshResult.isSuccess, isTrue);
      expect(freshResult.isDuplicate, isFalse);
      expect(freshResult.paymentId, equals('pay_PM-12345'));

      const duplicateResult = PaymentRecordResult(
        isSuccess: true,
        isDuplicate: true,
        paymentId: 'pay_PM-12345',
        message: 'Payment was previously recorded.',
      );

      expect(duplicateResult.isSuccess, isTrue);
      expect(duplicateResult.isDuplicate, isTrue);
      expect(duplicateResult.paymentId, equals('pay_PM-12345'));
    });
  });
}
