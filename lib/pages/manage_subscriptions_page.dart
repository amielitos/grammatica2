import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_colors.dart';

class ManageSubscriptionsPage extends StatelessWidget {
  final User user;
  const ManageSubscriptionsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Manage Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGreen.withOpacity(0.05),
              Colors.blue.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService.instance.streamLearnerSubscriptions(
              user.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final subscriptions = snapshot.data ?? [];
              final active = subscriptions
                  .where((s) => s['status'] == 'active')
                  .toList();
              final cancelled = subscriptions
                  .where((s) => s['status'] == 'cancelled')
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle(
                    context,
                    'Active Subscriptions',
                    CupertinoIcons.checkmark_circle_fill,
                    Colors.green,
                  ),
                  if (active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No active subscriptions.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...active.map(
                      (s) => _buildSubscriptionCard(context, s, isActive: true),
                    ),

                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    context,
                    'Subscription History',
                    CupertinoIcons.clock_fill,
                    Colors.grey,
                  ),
                  if (cancelled.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No cancelled subscriptions.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...cancelled.map(
                      (s) =>
                          _buildSubscriptionCard(context, s, isActive: false),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    Map<String, dynamic> sub, {
    required bool isActive,
  }) {
    final eduData = sub['educatorData'] as Map<String, dynamic>? ?? {};
    final username = eduData['username'] as String? ?? 'Educator';
    final fee = eduData['subscription_fee'] ?? 3;
    final billingCycle = sub['billingCycle'] as String? ?? 'monthly';
    final eduUid = sub['educatorUid'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                backgroundImage:
                    (eduData['photoUrl'] as String?)?.isNotEmpty == true
                    ? NetworkImage(eduData['photoUrl'])
                    : null,
                child: (eduData['photoUrl'] as String?)?.isEmpty ?? true
                    ? const Icon(
                        CupertinoIcons.person_fill,
                        color: AppColors.primaryGreen,
                      )
                    : null,
              ),
              title: Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isActive
                      ? 'Billed ${billingCycle == 'monthly' ? '\$$fee/mo' : '\$${fee * 10}/yr'}'
                      : 'Cancelled',
                  style: TextStyle(
                    color: isActive ? Colors.grey[700] : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing: isActive
                  ? IconButton(
                      icon: const Icon(
                        CupertinoIcons.xmark_circle,
                        color: Colors.red,
                      ),
                      onPressed: () =>
                          _confirmCancel(context, eduUid, username),
                    )
                  : const Icon(CupertinoIcons.clear, color: Colors.grey),
            ),
            if (isActive) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Billing Cycle',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: billingCycle,
                      children: const {
                        'monthly': Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Monthly'),
                        ),
                        'annual': Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Annual'),
                        ),
                      },
                      onValueChanged: (val) {
                        if (val != null) {
                          DatabaseService.instance
                              .updateSubscriptionBillingCycle(eduUid, val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, String eduUid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: Text(
          'Are you sure you want to cancel your subscription to $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.unsubscribeFromEducator(eduUid);
    }
  }
}
