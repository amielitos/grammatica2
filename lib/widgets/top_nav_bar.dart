import 'package:flutter/material.dart';

class TopNavBar extends StatelessWidget {
  const TopNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800; // Consistent breakpoint

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo + Text Group
          InkWell(
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', height: 40),
                const SizedBox(width: 8),
                Image.asset('assets/logotext.png', height: 28),
              ],
            ),
          ),
          Spacer(),
          if (isDesktop) ...[
            _buildNavButton('All About Grammatica'),
            SizedBox(width: 28),
            _buildNavButton("FAQ's"),
          ],
        ],
      ),
    );
  }

  Widget _buildNavButton(String text) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Color(0xFF1D1B20),
          fontWeight: FontWeight.w500,
          fontSize: 15,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}


