import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents the lockout and failed attempt state for this specific device/session.
class DeviceLockoutState {
  final bool isLocked;
  final int failedCount;
  final DateTime? lockedUntil;
  final Duration remainingDuration;

  const DeviceLockoutState({
    required this.isLocked,
    required this.failedCount,
    this.lockedUntil,
    this.remainingDuration = Duration.zero,
  });

  int get remainingSeconds => remainingDuration.inSeconds;
}

/// Service that generates and manages a persistent device identifier and in-memory session
/// tracking failed login attempts and lockouts per physical device/app installation.
class DeviceSessionService {
  DeviceSessionService._();
  static final DeviceSessionService instance = DeviceSessionService._();

  static const String _prefKeyDeviceId = 'device_session_device_id';
  static const String _prefKeyFailedCount = 'device_failed_login_count';
  static const String _prefKeyLastFailedAt = 'device_last_failed_login_epoch';
  static const String _prefKeyLockedUntil = 'device_lockout_until_epoch';

  /// Number of failed attempts permitted before locking the device.
  static const int maxFailedAttempts = 3;

  /// Duration of device lockout.
  static const Duration lockoutDuration = Duration(minutes: 5);

  /// Sliding window duration after which un-locked failed attempts expire.
  /// If a user made 1 or 2 mistakes > 15 minutes ago, the counter resets.
  static const Duration attemptExpirationWindow = Duration(minutes: 15);

  String? _cachedDeviceId;
  late final String _sessionId = _generateRandomHex(16);

  /// Returns the current app session ID (refreshed on app cold-start).
  String get sessionId => _sessionId;

  /// Returns the persistent unique device ID, generating and saving one if it does not exist.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    String? devId = prefs.getString(_prefKeyDeviceId);
    if (devId == null || devId.isEmpty) {
      devId = 'dev_${_generateRandomHex(24)}';
      await prefs.setString(_prefKeyDeviceId, devId);
    }
    _cachedDeviceId = devId;
    return devId;
  }

  /// Helper to generate secure random hex string.
  static String _generateRandomHex(int length) {
    final random = math.Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Fetches the current lockout state for this device.
  /// Automatically resets expired lockouts and clears attempts older than [attemptExpirationWindow].
  Future<DeviceLockoutState> getLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    final nowEpoch = DateTime.now().toUtc().millisecondsSinceEpoch;

    final lockedUntilEpoch = prefs.getInt(_prefKeyLockedUntil);
    int failedCount = prefs.getInt(_prefKeyFailedCount) ?? 0;
    final lastFailedEpoch = prefs.getInt(_prefKeyLastFailedAt);

    // 1. Check if device is currently locked
    if (lockedUntilEpoch != null) {
      if (lockedUntilEpoch > nowEpoch) {
        final remainingMs = lockedUntilEpoch - nowEpoch;
        final lockedUntilDate = DateTime.fromMillisecondsSinceEpoch(lockedUntilEpoch, isUtc: true).toLocal();
        return DeviceLockoutState(
          isLocked: true,
          failedCount: failedCount,
          lockedUntil: lockedUntilDate,
          remainingDuration: Duration(milliseconds: remainingMs),
        );
      } else {
        // Lock has expired! Reset lockout and failed count
        await clearLockout();
        return const DeviceLockoutState(
          isLocked: false,
          failedCount: 0,
        );
      }
    }

    // 2. If not locked, check if the sliding window expired for previous attempts
    if (lastFailedEpoch != null && failedCount > 0) {
      final elapsedSinceLastFailure = nowEpoch - lastFailedEpoch;
      if (elapsedSinceLastFailure > attemptExpirationWindow.inMilliseconds) {
        // More than 15 minutes of inactivity: reset count so stale attempts don't cause sudden lockout
        await prefs.setInt(_prefKeyFailedCount, 0);
        await prefs.remove(_prefKeyLastFailedAt);
        failedCount = 0;
      }
    }

    return DeviceLockoutState(
      isLocked: false,
      failedCount: failedCount,
    );
  }

  /// Records a failed login attempt on this device.
  /// Enforces sliding window decay and triggers a 5-minute lockout on the 3rd attempt.
  Future<DeviceLockoutState> recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final nowUtc = DateTime.now().toUtc();
    final nowEpoch = nowUtc.millisecondsSinceEpoch;

    // Check existing state first
    final currentState = await getLockoutState();
    if (currentState.isLocked) {
      return currentState;
    }

    int count = currentState.failedCount + 1;
    await prefs.setInt(_prefKeyFailedCount, count);
    await prefs.setInt(_prefKeyLastFailedAt, nowEpoch);

    if (count >= maxFailedAttempts) {
      final lockUntilUtc = nowUtc.add(lockoutDuration);
      final lockUntilEpoch = lockUntilUtc.millisecondsSinceEpoch;
      await prefs.setInt(_prefKeyLockedUntil, lockUntilEpoch);

      debugPrint('[DeviceSession] 🔒 Device locked for ${lockoutDuration.inMinutes} minutes (count: $count)');

      return DeviceLockoutState(
        isLocked: true,
        failedCount: count,
        lockedUntil: lockUntilUtc.toLocal(),
        remainingDuration: lockoutDuration,
      );
    } else {
      debugPrint('[DeviceSession] Failed attempt recorded for device (count: $count/$maxFailedAttempts)');
      return DeviceLockoutState(
        isLocked: false,
        failedCount: count,
      );
    }
  }

  /// Clears failed attempts and unlocks this device (e.g. On successful sign-in).
  Future<void> clearLockout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyLockedUntil);
    await prefs.setInt(_prefKeyFailedCount, 0);
    await prefs.remove(_prefKeyLastFailedAt);
    debugPrint('[DeviceSession] Device lockout and failed attempts cleared.');
  }
}
