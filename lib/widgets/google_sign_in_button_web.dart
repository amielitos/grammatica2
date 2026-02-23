import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import '../services/auth_service.dart';

Widget buildWebButton({bool enabled = true, VoidCallback? onDisabledPress}) {
  return FutureBuilder<void>(
    future: AuthService.instance.ensureGoogleSignInInitialized(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        // Render a placeholder of the same size while initializing
        return const SizedBox(height: 54, width: double.infinity);
      }

      if (snapshot.hasError) {
        // Initialization failed, so we can't render the button.
        // Log the error and hide the button to avoid "Bad state" crashes.
        debugPrint('Google Sign-In initialization failed: ${snapshot.error}');
        return const SizedBox.shrink();
      }

      final platform = GoogleSignInPlatform.instance;
      if (platform is web.GoogleSignInPlugin) {
        return SizedBox(
          height: 54,
          width: double.infinity,
          child: Stack(
            children: [
              Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: platform.renderButton(
                  configuration: web.GSIButtonConfiguration(
                    type: web.GSIButtonType.standard,
                    theme: web.GSIButtonTheme.outline,
                    size: web.GSIButtonSize.large,
                    text: web.GSIButtonText.continueWith,
                    shape: web.GSIButtonShape.rectangular,
                    logoAlignment: web.GSIButtonLogoAlignment.left,
                  ),
                ),
              ),
              if (!enabled)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDisabledPress,
                    child: Container(color: Colors.transparent),
                  ),
                ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
