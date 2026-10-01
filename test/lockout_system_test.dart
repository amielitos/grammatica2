import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/services/auth_service.dart';

void main() {
  group('Three Attempts Lockout System Tests', () {
    test('Lockout policy constants are properly set', () {
      expect(AuthService.maxFailedAttempts, 3);
      expect(AuthService.lockoutDuration, const Duration(minutes: 5));
    });

    test('LockoutStatus correctly reports active lock state and duration', () {
      final now = DateTime.now();
      final lockedUntil = now.add(const Duration(minutes: 4, seconds: 30));

      final status = LockoutStatus(
        isLocked: true,
        failedCount: 3,
        lockedUntil: lockedUntil,
        remainingDuration: const Duration(minutes: 4, seconds: 30),
      );

      expect(status.isLocked, isTrue);
      expect(status.failedCount, 3);
      expect(status.remainingDuration.inMinutes, 4);
      expect(status.remainingDuration.inSeconds, 270);
    });

    test('LockoutStatus correctly reports unlocked state', () {
      const status = LockoutStatus(
        isLocked: false,
        failedCount: 1,
        lockedUntil: null,
        remainingDuration: Duration.zero,
      );

      expect(status.isLocked, isFalse);
      expect(status.failedCount, 1);
      expect(status.lockedUntil, isNull);
      expect(status.remainingDuration, Duration.zero);
    });

    test('Remaining attempts warning threshold calculation', () {
      // 1st failed attempt -> 2 remaining
      int failedAttempts = 1;
      int remaining = AuthService.maxFailedAttempts - failedAttempts;
      expect(remaining, 2);

      // 2nd failed attempt -> 1 remaining (warning threshold)
      failedAttempts = 2;
      remaining = AuthService.maxFailedAttempts - failedAttempts;
      expect(remaining, 1);

      // 3rd failed attempt -> 0 remaining (locked!)
      failedAttempts = 3;
      remaining = AuthService.maxFailedAttempts - failedAttempts;
      expect(remaining, 0);
      expect(failedAttempts >= AuthService.maxFailedAttempts, isTrue);
    });
  });
}
