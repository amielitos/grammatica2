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

    return AlertDialog(
      title: Text('Subscribe to $educatorName'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTierOption(
              context,
              tier: 'Basic',
              price: 'Free',
              description: 'Access to free content.',
              role: 'Viewer',
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            _buildTierOption(
              context,
              tier: 'Standard',
              price: '\$$standardPrice/mo',
              description: 'Access to members-only content.',
              role: 'Subscriber',
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildTierOption(
              context,
              tier: 'Premium',
              price: '\$$premiumPrice/mo',
              description: 'Hands-on teaching materials.',
              role: 'Mentored',
              color: Colors.amber.shade700,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildTierOption(
    BuildContext context, {
    required String tier,
    required String price,
    required String description,
    required String role,
    required Color color,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, tier),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tier,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  price,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Role: $role',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
