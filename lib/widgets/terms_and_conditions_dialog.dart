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
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent == 0) {
        setState(() {
          _canAccept = true;
        });
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 20) {
      setState(() {
        _canAccept = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terms and Conditions'),
      content: SingleChildScrollView(
        controller: _scrollController,
        child: const Text(
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
          'Thank you for using Grammatica!\n\n'
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
