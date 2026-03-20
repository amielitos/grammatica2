import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../main.dart';

class ManageSubscriptionsPage extends StatefulWidget {
  final User user;
  const ManageSubscriptionsPage({super.key, required this.user});

  @override
  State<ManageSubscriptionsPage> createState() =>
      _ManageSubscriptionsPageState();
}

class _ManageSubscriptionsPageState extends State<ManageSubscriptionsPage> {
  final TextEditingController _standardController = TextEditingController();
  final TextEditingController _premiumController = TextEditingController();
  bool _isEducator = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoadPricing();
  }

  Future<void> _checkRoleAndLoadPricing() async {
    final doc = await DatabaseService.instance.getUserData(widget.user.uid);
    if (doc != null) {
      if (mounted) {
        setState(() {
          _isEducator = doc['role'] == 'Educator';
          final pricing = doc['subscription_pricing'] as Map<String, dynamic>?;
          if (pricing != null) {
            _standardController.text = (pricing['standard'] ?? 3).toString();
            _premiumController.text = (pricing['premium'] ?? 7).toString();
          } else {
            _standardController.text = '3';
            _premiumController.text = '7';
          }
        });
      }
    }
  }

  Future<void> _savePricing() async {
    final standard = int.tryParse(_standardController.text) ?? 3;
    final premium = int.tryParse(_premiumController.text) ?? 7;

    if (standard > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard pricing cannot exceed \$10')),
      );
      return;
    }
    if (premium > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium pricing cannot exceed \$30')),
      );
      return;
    }

    await DatabaseService.instance.updateSubscriptionPricing(
      widget.user.uid,
      standard: standard,
      premium: premium,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pricing updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Manage Subscriptions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEducator) ...[
                      _buildSectionTitle(
                        context,
                        'Subscription Pricing',
                        Icons.payments_rounded,
                        AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Set your monthly rates for learners who subscribe to your content.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildPricingField(
                                label: 'Standard Tier (Max \$10)',
                                controller: _standardController,
                                icon: Icons.star_outline_rounded,
                              ),
                              const SizedBox(height: 20),
                              _buildPricingField(
                                label: 'Premium Tier (Max \$30)',
                                controller: _premiumController,
                                icon: Icons.auto_awesome_rounded,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _savePricing,
                                child: const Text('Save Pricing Settings'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                    _buildLearnerSubscriptions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixText: '\$',
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildLearnerSubscriptions() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamLearnerSubscriptions(
        widget.user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final subscriptions = snapshot.data ?? [];
        final active = subscriptions
            .where((s) => s['status'] == 'active')
            .toList();
        final cancelled = subscriptions
            .where((s) => s['status'] == 'cancelled')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              'Active Subscriptions',
              Icons.stars_rounded,
              AppColors.primary,
            ),
            if (active.isEmpty)
              Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: Text(
                      'No active subscriptions.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              ...active.map(
                (s) => _buildSubscriptionCard(context, s, isActive: true),
              ),
            const SizedBox(height: 48),
            _buildSectionTitle(
              context,
              'Subscription History',
              Icons.history_rounded,
              AppColors.textSecondary,
            ),
            if (cancelled.isEmpty)
              Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: Text(
                      'No subscription history.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              ...cancelled.map(
                (s) => _buildSubscriptionCard(context, s, isActive: false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
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
    final tier = sub['tier'] ?? 'Standard';
    final eduUid = sub['educatorUid'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 2),
          ),
          child: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.05),
            backgroundImage: (eduData['photoUrl'] as String?)?.isNotEmpty == true
                ? NetworkImage(eduData['photoUrl'])
                : null,
            child: (eduData['photoUrl'] as String?)?.isEmpty ?? true
                ? const Icon(Icons.person_rounded, color: AppColors.primary)
                : null,
          ),
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (tier == 'Premium' ? AppColors.accent : AppColors.secondary)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tier,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: tier == 'Premium' ? AppColors.accent : AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${isActive ? 'Active' : 'Cancelled'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        trailing: isActive
            ? IconButton(
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.redAccent,
                ),
                onPressed: () => _confirmCancel(context, eduUid, username),
              )
            : null,
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
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
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
