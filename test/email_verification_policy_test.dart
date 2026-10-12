import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Email Verification Policy Tests', () {
    bool requiresVerification({
      required bool isGoogleUser,
      required bool emailVerified,
      required Map<String, dynamic>? userData,
    }) {
      if (isGoogleUser || emailVerified) {
        return false;
      }
      return userData?['requires_email_verification'] == true;
    }

    test('Legacy users without requires_email_verification flag bypass verification', () {
      final legacyUserData = <String, dynamic>{
        'uid': 'legacy-user-123',
        'email': 'legacy@example.com',
        'role': 'LEARNER',
        'status': 'ACTIVE',
      };

      expect(
        requiresVerification(
          isGoogleUser: false,
          emailVerified: false,
          userData: legacyUserData,
        ),
        isFalse,
      );
    });

    test('Legacy users with requires_email_verification set to false bypass verification', () {
      final legacyUserData = <String, dynamic>{
        'uid': 'legacy-user-456',
        'requires_email_verification': false,
      };

      expect(
        requiresVerification(
          isGoogleUser: false,
          emailVerified: false,
          userData: legacyUserData,
        ),
        isFalse,
      );
    });

    test('New users starting now with requires_email_verification: true must verify email', () {
      final newUserData = <String, dynamic>{
        'uid': 'new-user-789',
        'email': 'new@example.com',
        'requires_email_verification': true,
      };

      expect(
        requiresVerification(
          isGoogleUser: false,
          emailVerified: false,
          userData: newUserData,
        ),
        isTrue,
      );
    });

    test('New users who have completed verification bypass prompt', () {
      final newUserData = <String, dynamic>{
        'uid': 'new-user-789',
        'requires_email_verification': true,
      };

      expect(
        requiresVerification(
          isGoogleUser: false,
          emailVerified: true,
          userData: newUserData,
        ),
        isFalse,
      );
    });

    test('Google users always bypass email verification', () {
      final googleUserData = <String, dynamic>{
        'requires_email_verification': true,
      };

      expect(
        requiresVerification(
          isGoogleUser: true,
          emailVerified: false,
          userData: googleUserData,
        ),
        isFalse,
      );
    });
  });
}
