class EmailValidatorService {
  EmailValidatorService._();

  /// The only accepted email domains on Grammatica.
  static const Set<String> allowedDomains = {
    'gmail.com',
    'yahoo.com',
    'hotmail.com',
  };

  /// The only accepted email domains for super admin additions.
  static const Set<String> superAdminAllowedDomains = {
    'yahoo.com',
    'gmail.com',
    'hotmail.com',
  };

  /// Returns true if [email] has an accepted domain (@gmail.com, @yahoo.com, @hotmail.com).
  static bool isAllowedEmail(String email) {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) return false;
    final parts = clean.split('@');
    if (parts.length != 2) return false;
    final domain = parts[1].trim();
    return allowedDomains.contains(domain);
  }

  /// Returns true if [email] has an accepted domain for super admin additions (@yahoo.com, @gmail.com, @hotmail.com).
  static bool isAllowedSuperAdminEmail(String email) {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) return false;
    final parts = clean.split('@');
    if (parts.length != 2) return false;
    final domain = parts[1].trim();
    return superAdminAllowedDomains.contains(domain);
  }

  /// Convenience method: returns true if the email is not an allowed domain.
  static bool isDisposableEmail(String email) {
    return !isAllowedEmail(email);
  }
}
