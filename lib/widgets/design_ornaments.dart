import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_colors.dart';

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  final String? imageAssetPath;

  const BackgroundWrapper({
    super.key,
    required this.child,
    this.imageAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageAssetPath != null)
            Positioned.fill(
              child: Image.asset(imageAssetPath!, fit: BoxFit.cover),
            )
          else ...[
            // Background Blob 1
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  color: AppColors.blobLightGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Background Blob 2
            Positioned(
              bottom: -50,
              right: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: const BoxDecoration(
                  color: AppColors.blobLightYellow,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Blur Effect Layer
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],
          // Content
          SafeArea(child: child),
        ],
      ),
    );
  }
}
