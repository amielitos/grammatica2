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
          // --- EDIT TERMS AND CONDITIONS CONTENT HERE ---
          // You can modify the text below to update your Terms and Conditions.
          // Use \n for new lines.
          'Welcome to Grammatica!\n\n'
          '1. Acceptance of Terms\n'
          'By creating an account, you agree to abide by these terms...\n\n' // <-- Edit this section
          '2. Privacy Policy\n'
          'Your data is handled according to our privacy policy...\n\n' // <-- Edit this section
          '3. User Conduct\n'
          'Users must not engage in any illegal activities...\n\n' // <-- Edit this section
          '4. Intellectual Property\n'
          'All content on Grammatica is protected by copyright...\n\n' // <-- Edit this section
          '5. Termination\n'
          'We reserve the right to terminate accounts for violations...\n\n' // <-- Edit this section
          '6. Changes to Terms\n'
          'We may update these terms from time to time...\n\n' // <-- Edit this section
          'Thank you for using Grammatica!\n\n'
          '(Scroll to the bottom to accept)',
          // --- END OF CONTENT ---
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
