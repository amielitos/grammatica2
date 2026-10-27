import 'package:flutter_test/flutter_test.dart';
import 'package:grammatica/services/email_validator_service.dart';

void main() {
  group('Super Admin Email Validation Tests', () {
    test('Allowed domains for super admin: @yahoo.com, @gmail.com, @hotmail.com', () {
      expect(EmailValidatorService.isAllowedSuperAdminEmail('admin@yahoo.com'), isTrue);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('admin@gmail.com'), isTrue);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('admin@hotmail.com'), isTrue);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('ADMIN@GMAIL.COM'), isTrue);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('  admin@yahoo.com  '), isTrue);
    });

    test('Disallowed domains for super admin: @google.com, @outlook.com, @example.com', () {
      expect(EmailValidatorService.isAllowedSuperAdminEmail('admin@google.com'), isFalse);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('admin@outlook.com'), isFalse);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('admin@example.com'), isFalse);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('admin@grammatica.com'), isFalse);
      expect(EmailValidatorService.isAllowedSuperAdminEmail(''), isFalse);
      expect(EmailValidatorService.isAllowedSuperAdminEmail('invalid-email'), isFalse);
    });

    test('Regular registration allowed domains remain @gmail.com, @yahoo.com, @hotmail.com', () {
      expect(EmailValidatorService.isAllowedEmail('user@gmail.com'), isTrue);
      expect(EmailValidatorService.isAllowedEmail('user@yahoo.com'), isTrue);
      expect(EmailValidatorService.isAllowedEmail('user@hotmail.com'), isTrue);
      expect(EmailValidatorService.isAllowedEmail('user@google.com'), isFalse);
    });
  });
}
