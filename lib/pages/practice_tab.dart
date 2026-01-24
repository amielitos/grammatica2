import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  int? _selectedSubTab; // null = Selection, 0 = Bee, 1 = Voice

  @override
  Widget build(BuildContext context) {
    if (_selectedSubTab == 0) {
      return _BeeView(onBack: () => setState(() => _selectedSubTab = null));
    }
    if (_selectedSubTab == 1) {
      return _VoiceView(onBack: () => setState(() => _selectedSubTab = null));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Practice Tools',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Master your grammar and pronunciation',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _PracticeCard(
            title: 'Spelling Bee',
            subtitle: 'Master spelling through fun challenges',
            icon: CupertinoIcons.ant,
            backgroundColor: Colors.yellow.shade700,
            onTap: () => setState(() => _selectedSubTab = 0),
          ),
          const SizedBox(height: 20),
          _PracticeCard(
            title: 'Pronunciation',
            subtitle: 'Practice speaking with voice feedback',
            icon: CupertinoIcons.mic,
            backgroundColor: Colors.pink.shade300,
            onTap: () => setState(() => _selectedSubTab = 1),
          ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: backgroundColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: backgroundColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _BeeView extends StatelessWidget {
  final VoidCallback onBack;
  const _BeeView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: onBack,
          ),
          title: const Text('Spelling Bee'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.ant, size: 80, color: Colors.amber),
                SizedBox(height: 24),
                Text(
                  'Spelling Bee',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Coming Soon', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceView extends StatelessWidget {
  final VoidCallback onBack;
  const _VoiceView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: onBack,
          ),
          title: const Text('Pronunciation'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.mic, size: 80, color: Colors.pink),
                SizedBox(height: 24),
                Text(
                  'Pronunciation',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Coming Soon', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
