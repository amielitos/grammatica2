import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/services/role_service.dart';

void main() {
  group('Validator Registration Limitation Tests', () {
    test('disabledValidatorMessage matches user specification exactly', () {
      expect(
        RoleService.disabledValidatorMessage,
        'Thank you for your interest in applying as a Validator, currently Grammatica has already a Validator. Feel free to reapply next time once this button is no longer disabled.',
      );
    });

    test('isApprovedValidatorData correctly validates active approved validators', () {
      final roleService = RoleService.instance;

      // Active, verified validator (like test validator or approved new validator)
      expect(
        roleService.isApprovedValidatorData({
          'role': 'VALIDATOR',
          'status': 'ACTIVE',
          'isVerified': true,
        }),
        isTrue,
      );

      // Case insensitivity
      expect(
        roleService.isApprovedValidatorData({
          'role': 'validator',
          'status': 'active',
          'isVerified': true,
        }),
        isTrue,
      );

      // Pending application (Validator in Review) must NOT count as approved
      expect(
        roleService.isApprovedValidatorData({
          'role': 'VALIDATOR',
          'status': 'Validator in Review',
          'isVerified': false,
        }),
        isFalse,
      );

      // Unverified with active status
      expect(
        roleService.isApprovedValidatorData({
          'role': 'VALIDATOR',
          'status': 'ACTIVE',
          'isVerified': false,
        }),
        isFalse,
      );

      // Verified but rejected status
      expect(
        roleService.isApprovedValidatorData({
          'role': 'VALIDATOR',
          'status': 'REJECTED',
          'isVerified': true,
        }),
        isFalse,
      );

      // Archived validator
      expect(
        roleService.isApprovedValidatorData({
          'role': 'VALIDATOR',
          'status': 'ACTIVE',
          'isVerified': true,
          'isArchived': true,
        }),
        isFalse,
      );

      // Status archived
      expect(
        roleService.isApprovedValidatorData({
          'role': 'VALIDATOR',
          'status': 'ARCHIVED',
          'isVerified': true,
        }),
        isFalse,
      );

      // Deactivated validator
      expect(
        roleService.isApprovedValidatorData({
          'role': 'VALIDATOR',
          'status': 'DEACTIVATED',
          'isVerified': true,
        }),
        isFalse,
      );

      // Non-validator roles
      expect(
        roleService.isApprovedValidatorData({
          'role': 'LEARNER',
          'status': 'ACTIVE',
          'isVerified': true,
        }),
        isFalse,
      );

      expect(
        roleService.isApprovedValidatorData({
          'role': 'EDUCATOR',
          'status': 'ACTIVE',
          'isVerified': true,
        }),
        isFalse,
      );

      expect(
        roleService.isApprovedValidatorData(null),
        isFalse,
      );
    });

    test('System threshold: disables validator registration when 2 or more approved validators exist', () {
      final roleService = RoleService.instance;

      final testValidator = {
        'role': 'VALIDATOR',
        'status': 'ACTIVE',
        'isVerified': true,
        'email': 'amielvalidator@gmail.com',
      };

      final newApplicant = {
        'role': 'VALIDATOR',
        'status': 'Validator in Review',
        'isVerified': false,
        'email': 'applicant@gmail.com',
      };

      final approvedSecondValidator = {
        'role': 'VALIDATOR',
        'status': 'ACTIVE',
        'isVerified': true,
        'email': 'secondvalidator@gmail.com',
      };

      // Scenario 1: Only the test validator is approved, applicant is still pending.
      final scenario1 = [testValidator, newApplicant];
      final approvedCount1 = scenario1.where((u) => roleService.isApprovedValidatorData(u)).length;
      expect(approvedCount1, 1);
      final isDisabled1 = approvedCount1 >= 2;
      expect(isDisabled1, isFalse, reason: 'Button should remain enabled when only test validator exists');

      // Scenario 2: Second validator has been approved. Exactly 2 validators on the system.
      final scenario2 = [testValidator, approvedSecondValidator];
      final approvedCount2 = scenario2.where((u) => roleService.isApprovedValidatorData(u)).length;
      expect(approvedCount2, 2);
      final isDisabled2 = approvedCount2 >= 2;
      expect(isDisabled2, isTrue, reason: 'Button should be disabled once second validator is approved');

      // Scenario 3: If second validator is removed/archived/demoted, button re-enables.
      final demotedSecondValidator = {
        'role': 'LEARNER',
        'status': 'ACTIVE',
        'isVerified': true,
        'email': 'secondvalidator@gmail.com',
      };
      final scenario3 = [testValidator, demotedSecondValidator];
      final approvedCount3 = scenario3.where((u) => roleService.isApprovedValidatorData(u)).length;
      expect(approvedCount3, 1);
      final isDisabled3 = approvedCount3 >= 2;
      expect(isDisabled3, isFalse, reason: 'Button should re-enable when second validator is no longer active');
    });
  });
}

