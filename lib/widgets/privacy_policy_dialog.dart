import 'package:flutter/material.dart';

class PrivacyPolicyDialog extends StatefulWidget {
  const PrivacyPolicyDialog({super.key});

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: Color(0xFF81B655)),
          SizedBox(width: 10),
          Expanded(child: Text('Privacy Policy', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: const Text(
            'GRAMMATICA — PRIVACY POLICY\n\n'
            'Effective Date: October 31, 2026\n\n'
            '1. Introduction\n'
            'Grammatica values the privacy of its users. This Privacy Policy explains how personal information is collected, used, stored, and protected when using the platform.\n\n'
            '2. Information We Collect\n'
            'Grammatica may collect the following information:\n'
            '• Personal details, including name, email address, phone number, and date of birth.\n'
            '• Account and profile information.\n'
            '• Educator and Validator application documents.\n'
            '• Learning activities, assessment results, and progress records.\n'
            '• Enrollment details and mentorship schedules.\n'
            '• Technical information related to account and application usage.\n\n'
            '3. Use of Personal Information\n'
            'Collected information may be used to:\n'
            '• Create and manage user accounts.\n'
            '• Verify user identities and applications.\n'
            '• Monitor learning progress and achievements.\n'
            '• Manage Educator enrollment and mentorship sessions.\n'
            '• Provide AI-assisted learning features.\n'
            '• Maintain application security and improve services.\n\n'
            '4. Information Access and Sharing\n'
            'Personal information may be accessed by authorized users according to their roles:\n'
            '• Educators: Access relevant information about their enrolled Learners.\n'
            '• Validators: Review Educator applications and submitted educational materials.\n'
            '• Super-Admins: Manage accounts, applications, and platform activities.\n'
            'Information may also be processed by third-party providers necessary for Grammatica services.\n\n'
            '5. Third-Party Services\n'
            'Grammatica uses Google Sign-In for authentication and Google Gemini for AI-assisted features. Google Meet, Zoom, and Microsoft Teams may be used for mentorship sessions. These providers have their own privacy policies and data-handling practices.\n\n'
            '6. AI-Assisted Processing\n'
            'Information and documents submitted through AI Notebook may be processed by Google Gemini to generate lessons, quizzes, and other educational materials. Users should avoid uploading unnecessary personal or confidential information.\n\n'
            '7. Speech and Pronunciation Data\n'
            'Grammatica uses Vosk and Web Speech APIs for English speech recognition and pronunciation activities. Audio processing depends on the technology and features used.\n\n'
            '8. Data Storage and Security\n'
            'Grammatica applies reasonable security measures to protect personal information against unauthorized access, disclosure, alteration, or loss.\n\n'
            '9. Data Retention\n'
            'Personal information is retained only as long as necessary for educational, operational, and legal purposes. Records may be deleted or anonymized when no longer needed, subject to applicable requirements.\n\n'
            '10. User Privacy Rights\n'
            'Under the Philippine Data Privacy Act of 2012, users may exercise their applicable rights, including accessing their personal information, correcting inaccurate details, requesting deletion or blocking when legally permitted, objecting to certain data processing activities, and filing a complaint with the National Privacy Commission.\n\n'
            '11. Policy Updates\n'
            'Grammatica may update this Privacy Policy from time to time. Continued use of the platform indicates acceptance of any revisions.\n\n'
            '12. Contact Information\n'
            'For privacy inquiries and requests, contact grammatica.support@gmail.com.',
            style: TextStyle(fontSize: 13.5, height: 1.5),
          ),
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF81B655),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

