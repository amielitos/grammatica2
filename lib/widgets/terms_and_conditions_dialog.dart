import 'package:flutter/material.dart';

class TermsAndConditionsDialog extends StatefulWidget {
  const TermsAndConditionsDialog({super.key});

  @override
  State<TermsAndConditionsDialog> createState() =>
      _TermsAndConditionsDialogState();
}

class _TermsAndConditionsDialogState extends State<TermsAndConditionsDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _canAccept = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Check if content is short enough to not need scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // If content is shorter than the view, allow acceptance immediately
        if (_scrollController.position.maxScrollExtent <= 0) {
          setState(() {
            _canAccept = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_canAccept) return;
    // Allow acceptance if user has scrolled near the bottom
    // We use a small threshold (e.g., 20 pixels) to account for minor layout variations
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 20) {
      if (!_canAccept) {
        setState(() {
          _canAccept = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terms and Conditions'),
      content: SingleChildScrollView(
        controller: _scrollController,
        child: const Text(
          'GRAMMATICA — TERMS AND CONDITIONS\n'
          'Effective Date: October 31, 2026\n\n'
          '1. Introduction\n'
          'Grammatica is an AI-assisted English learning application that provides interactive lessons, educational activities, assessments, and learning support. By using the platform, users agree to these Terms and Conditions.\n\n'
          '2. User Roles\n'
          'Grammatica supports four user roles:\n'
          '• Learners: Access lessons, complete activities, track progress, enroll in Educators, and apply for the Educator role.\n'
          '• Educators: Create lessons, quizzes, and learning materials, manage enrolled learners, and conduct mentorship sessions.\n'
          '• Validators: Review educational content and applications, then approve or reject submissions.\n'
          '• Super-Admins: Manage accounts, official lessons, applications, platform content, and system settings.\n\n'
          '3. Accounts and Security\n'
          'Users must provide accurate registration details and protect their login credentials. Unauthorized account access and misuse of another user\'s information are prohibited.\n\n'
          '4. Educator Applications\n'
          'Applicants must submit the required credentials for review. Approval depends on the platform\'s validation process and does not guarantee acceptance.\n\n'
          '5. Enrollment and Access\n'
          'Learners may browse Educators and enroll to access eligible courses, custom lessons, members-only content, and mentorship sessions. Removing an enrollment may affect access to restricted materials.\n\n'
          '6. Educational Content\n'
          'Users must submit appropriate educational materials and respect intellectual property rights. Grammatica may reject or archive content that violates platform guidelines. Archived lessons may be permanently deleted after 30 days if not restored.\n\n'
          '7. Artificial Intelligence\n'
          'Grammatica uses Google Gemini cloud services to assist in generating lessons, quizzes, and other educational materials. AI-generated content may contain errors and should be reviewed before educational use.\n\n'
          '8. Practice and Assessments\n'
          'Grammatica offers grammar, spelling, pronunciation, and English assessment activities. Speech recognition and pronunciation analysis are limited to English. Results do not guarantee specific learning outcomes.\n\n'
          '9. Mentorship Sessions\n'
          'Learners may schedule one-on-one sessions with Educators through supported conferencing services, including Google Meet, Zoom, and Microsoft Teams. Users must follow agreed schedules and respect other participants.\n\n'
          '10. User Conduct\n'
          'Users must not engage in harassment, upload harmful content, manipulate learning results, bypass security controls, or use Grammatica for unlawful activities. Violations may result in account restrictions or suspension.\n\n'
          '11. Intellectual Property\n'
          'Grammatica\'s software, branding, and original materials are protected by applicable laws. Users must not reproduce or distribute protected content without authorization.\n\n'
          '12. Account Deactivation and Deletion\n'
          'Eligible Learners, Educators, and Validators may deactivate or delete their accounts through available settings. Super-Admin accounts cannot be deleted through standard profile settings. Certain records may be retained when required by law.\n\n'
          '13. Service Limitations\n'
          'Grammatica depends on internet connectivity and external services for certain features. AI generation uses cloud-based models, while institutional multi-tenant administration, LMS LTI 1.3, and SCORM compliance are not supported.\n\n'
          '14. Limitation of Liability\n'
          'Grammatica does not guarantee uninterrupted service, error-free AI-generated content, or specific educational results. Nothing in these terms excludes liability that cannot legally be excluded.\n\n'
          '15. Changes to Terms\n'
          'Grammatica may update these terms as its features and services change. Revised terms will include an updated effective date.\n\n'
          '16. Governing Law\n'
          'These terms are governed by applicable laws of the Republic of the Philippines.\n\n'
          '17. Contact Information\n'
          'For questions or concerns, contact Grammatica through its official support channel.\n'
          'Email: grammatica.support@gmail.com\n\n'
          '(Scroll to the bottom to accept)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canAccept ? () => Navigator.of(context).pop(true) : null,
          child: const Text('I Agree'),
        ),
      ],
    );
  }
}
