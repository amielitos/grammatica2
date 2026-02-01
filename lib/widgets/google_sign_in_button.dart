import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Conditional import for web button
import 'google_sign_in_button_stub.dart'
    if (dart.library.js_util) 'google_sign_in_button_web.dart'
    as platform_button;

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget? child;

  const GoogleSignInButton({super.key, required this.onPressed, this.child});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return platform_button.buildWebButton();
    }

    return child ?? const SizedBox.shrink();
  }
}
