import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;

Widget buildWebButton() {
  final platform = GoogleSignInPlatform.instance;
  if (platform is web.GoogleSignInPlugin) {
    return SizedBox(
      height: 54,
      width: double.infinity,
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
    );
  }
  return const SizedBox.shrink();
}
