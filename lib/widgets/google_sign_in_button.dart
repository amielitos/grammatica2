import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Conditional import for web button
import 'google_sign_in_button_stub.dart'
    if (dart.library.js_util) 'google_sign_in_button_web.dart'
    as platform_button;

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget? child;

  final bool enabled;
  final VoidCallback? onDisabledPress;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.child,
    this.enabled = true,
    this.onDisabledPress,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return platform_button.buildWebButton(
        enabled: enabled,
        onDisabledPress: onDisabledPress,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : onDisabledPress,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          foregroundColor: const Color(0xFF1F1F1F),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
              height: 18,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Continue with Google',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
