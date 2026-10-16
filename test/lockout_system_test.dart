import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grammatica/services/auth_service.dart';
import 'package:grammatica/services/device_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Three Attempts Lockout System Tests', () {
    test('Lockout policy constants are properly set', () {
      expect(AuthService.maxFailedAttempts, 3);
      expect(AuthService.lockoutDuration, const Duration(minutes: 5));
      expect(AuthService.attemptExpirationWindow, const Duration(minutes: 15));
      expect(DeviceSessionService.maxFailedAttempts, 3);
      expect(DeviceSessionService.lockoutDuration, const Duration(minutes: 5));
      expect(DeviceSessionService.attemptExpirationWindow, const Duration(minutes: 15));
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

    test('DeviceSessionService records failed attempts and locks out strictly on 3rd attempt', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DeviceSessionService.instance;

      // Initial state
      var state = await service.getLockoutState();
      expect(state.isLocked, isFalse);
      expect(state.failedCount, 0);

      // 1st attempt
      state = await service.recordFailedAttempt();
      expect(state.isLocked, isFalse);
      expect(state.failedCount, 1);

      // 2nd attempt
      state = await service.recordFailedAttempt();
      expect(state.isLocked, isFalse);
      expect(state.failedCount, 2);

      // 3rd attempt -> Locked for 5 mins
      state = await service.recordFailedAttempt();
      expect(state.isLocked, isTrue);
      expect(state.failedCount, 3);
      expect(state.remainingDuration.inMinutes, greaterThanOrEqualTo(4));

      // Clear lockout
      await service.clearLockout();
      state = await service.getLockoutState();
      expect(state.isLocked, isFalse);
      expect(state.failedCount, 0);
    });

    test('DeviceSessionService resets failed count after 15 minute sliding window', () async {
      final nowEpoch = DateTime.now().toUtc().millisecondsSinceEpoch;
      // Stale attempt from 20 minutes ago (exceeding 15-min window)
      final twentyMinutesAgo = nowEpoch - const Duration(minutes: 20).inMilliseconds;

      SharedPreferences.setMockInitialValues({
        'device_failed_login_count': 2,
        'device_last_failed_login_epoch': twentyMinutesAgo,
      });

      final service = DeviceSessionService.instance;
      final state = await service.getLockoutState();

      // Stale 2 attempts must reset to 0 so next attempt won't immediately trigger lockout
      expect(state.failedCount, 0);
      expect(state.isLocked, isFalse);
    });
  });
}
