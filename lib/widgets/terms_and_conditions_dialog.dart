import 'package:flutter/material.dart';

class TermsAndConditionsDialog extends StatelessWidget {
  const TermsAndConditionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terms and Conditions'),
      content: const SingleChildScrollView(
        child: Text(
          'Welcome to Grammatica!\n\n'
          '1. Acceptance of Terms\n'
          'By creating an account, you agree to abide by these terms...\n\n'
          '2. Privacy Policy\n'
          'Your data is handled according to our privacy policy...\n\n'
          '3. User Conduct\n'
          'Users must not engage in any illegal activities...\n\n'
          '4. Intellectual Property\n'
          'All content on Grammatica is protected by copyright...\n\n'
          '5. Termination\n'
          'We reserve the right to terminate accounts for violations...\n\n'
          '6. Changes to Terms\n'
          'We may update these terms from time to time...\n\n'
          'Thank you for using Grammatica!',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
