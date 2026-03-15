import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEducator) ...[
                _buildSectionTitle(
                  context,
                  'Subscription Pricing',
                  Icons.edit,
                  Theme.of(context).colorScheme.primary,
                ),
                Card(
                  elevation: 0,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPricingField(
                          label: 'Standard Tier (Max \$10)',
                          controller: _standardController,
                          icon: Icons.subscriptions,
                        ),
                        const SizedBox(height: 16),
                        _buildPricingField(
                          label: 'Premium Tier (Max \$30)',
                          controller: _premiumController,
                          icon: Icons.workspace_premium,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _savePricing,
                            child: const Text('Save Pricing'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              _buildLearnerSubscriptions(),
            ],
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
        prefixIcon: Icon(icon),
        suffixText: '\$',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              Icons.check_circle,
              Theme.of(context).colorScheme.primary,
            ),
            if (active.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No active subscriptions.'),
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
              Icons.history,
              Theme.of(context).colorScheme.outlineVariant,
            ),
            if (cancelled.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No cancelled subscriptions.'),
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
    final tier = sub['tier'] ?? 'Standard';
    final eduUid = sub['educatorUid'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundImage: (eduData['photoUrl'] as String?)?.isNotEmpty == true
              ? NetworkImage(eduData['photoUrl'])
              : null,
          child: (eduData['photoUrl'] as String?)?.isEmpty ?? true
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(
          username,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text('Tier: $tier • ${isActive ? 'Active' : 'Cancelled'}'),
        trailing: isActive
            ? IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: Theme.of(context).colorScheme.error,
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
              foregroundColor: Theme.of(context).colorScheme.error,
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
