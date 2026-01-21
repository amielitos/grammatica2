import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A wrapper widget that applies a subtle animated rainbow gradient background.
/// Can be used as a replacement for Scaffold or as a body wrapper.
class RainbowBackground extends StatelessWidget {
  final Widget child;
  final Scaffold? scaffold; // If you want to wrap a whole scaffold

  const RainbowBackground({super.key, required this.child, this.scaffold});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),

        // Content
        SafeArea(child: child),
      ],
    );
  }
}
