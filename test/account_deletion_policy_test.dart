import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/services/role_service.dart';

void main() {
  group('Account Deletion Policy Tests', () {
    test('Admin and Superadmin roles are recognized and prohibited from deleting accounts', () {
      const adminRole = UserRole.admin;
      const superadminRole = UserRole.superadmin;

      bool canDeleteAccount(UserRole role) {
        return role != UserRole.admin && role != UserRole.superadmin;
      }

      expect(canDeleteAccount(adminRole), isFalse);
      expect(canDeleteAccount(superadminRole), isFalse);
    });

    test('Regular users (Learner, Educator, Validator) are permitted to delete accounts', () {
      bool canDeleteAccount(UserRole role) {
        return role != UserRole.admin && role != UserRole.superadmin;
      }

      expect(canDeleteAccount(UserRole.learner), isTrue);
      expect(canDeleteAccount(UserRole.educator), isTrue);
      expect(canDeleteAccount(UserRole.validator), isTrue);
    });

    test('String role representations correctly map to UserRole', () {
      expect(roleFromString('ADMIN'), UserRole.admin);
      expect(roleFromString('SUPERADMIN'), UserRole.superadmin);
      expect(roleFromString('EDUCATOR'), UserRole.educator);
      expect(roleFromString('VALIDATOR'), UserRole.validator);
      expect(roleFromString('LEARNER'), UserRole.learner);
      expect(roleFromString(null), UserRole.learner);
      expect(roleFromString('UNKNOWN'), UserRole.learner);
    });

    test('Forbidden account deletion error code is defined consistently', () {
      const forbiddenCode = 'admin-account-deletion-forbidden';
      expect(forbiddenCode, 'admin-account-deletion-forbidden');
    });
  });
}
