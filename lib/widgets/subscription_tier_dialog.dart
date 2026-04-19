import 'package:flutter/material.dart';

class SubscriptionTierDialog extends StatelessWidget {
  final Map<String, dynamic>? pricing;
  final String educatorName;

  const SubscriptionTierDialog({
    super.key,
    required this.pricing,
    required this.educatorName,
  });

  @override
  Widget build(BuildContext context) {
    final standardPrice = pricing?['standard'] ?? 3;
    final premiumPrice = pricing?['premium'] ?? 7;

    return Dialog(
      backgroundColor: const Color(0xFFF6F3EC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(42),
        side: const BorderSide(color: Colors.black, width: 1.0),
      ),
      child: Container(
        width: 960,
        height: 534,
        padding: const EdgeInsets.only(
          top: 32.0,
          bottom: 24.0,
          left: 32.0,
          right: 32.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subscribe to $educatorName',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            // Wrap allows it to flow to the next line on mobile screens
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildCard(
                  context,
                  tier: 'Basic',
                  price: 'Free',
                  description: 'Access to free content.',
                  role: 'Viewer',
                  mainColor: const Color(0xFFF9D866),
                  bgColor: const Color(0xFFFFFBEA),
                  strokeColor: const Color(0xFFE5C048),
                  icon: Icons.menu_book,
                ),
                _buildCard(
                  context,
                  tier: 'Standard',
                  price: '\$$standardPrice/mo',
                  description: 'Access to members-only content.',
                  role: 'Subscriber',
                  mainColor: const Color(0xFF98E274),
                  bgColor: const Color(0xFFECFBE6),
                  strokeColor: const Color(0xFF75CB4B),
                  icon: Icons.people_alt,
                ),
                _buildCard(
                  context,
                  tier: 'Premium',
                  price: '\$$premiumPrice/mo',
                  description: 'Hands-on teaching materials',
                  role: 'Mentored',
                  mainColor: const Color(0xFFF67576),
                  bgColor: const Color(0xFFFDEAEB),
                  strokeColor: const Color(0xFFDF5758),
                  icon: Icons.workspace_premium_outlined, // closest to crown
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String tier,
    required String price,
    required String description,
    required String role,
    required Color mainColor,
    required Color bgColor,
    required Color strokeColor,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, tier),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        width: 263,
        height: 362,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: strokeColor, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                ClipPath(
                  clipper: HeaderCurveClipper(),
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    color: mainColor,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 28),
                    child: Text(
                      tier,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 90,
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: mainColor, width: 2.0),
                    ),
                    child: Icon(icon, color: mainColor, size: 36),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 55,
            ), // Space for circle overlapping below header
            Text(
              role,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Includes:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                width: 150, // Slightly wider compact button width
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: strokeColor, width: 1.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  price,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 35);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 15,
      size.width,
      size.height - 35,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
