import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/role_service.dart';
import '../main.dart';
import '../theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  final User user;
  const SettingsPage({super.key, required this.user});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _emailNotifications = true;
  double _voiceVolume = 0.8;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Appearance'),
                _buildSettingsCard([
                  _buildThemeToggle(isDark),
                ]),
                const SizedBox(height: 32),
                _buildSectionHeader('Preferences'),
                _buildSettingsCard([
                  _buildSwitchTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Email Notifications',
                    subtitle: 'Receive updates about your subscription',
                    value: _emailNotifications,
                    onChanged: (val) => setState(() => _emailNotifications = val),
                  ),
                  const Divider(indent: 56),
                  _buildSliderTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Voice Volume',
                    subtitle: 'Adjust text-to-speech volume',
                    value: _voiceVolume,
                    onChanged: (val) => setState(() => _voiceVolume = val),
                  ),
                ]),
                const SizedBox(height: 32),
                _buildSectionHeader('Legal & About'),
                _buildSettingsCard([
                   _buildLinkTile(Icons.description_outlined, 'Terms of Service'),
                   const Divider(indent: 56),
                   _buildLinkTile(Icons.privacy_tip_outlined, 'Privacy Policy'),
                   const Divider(indent: 56),
                   _buildLinkTile(Icons.info_outline, 'App Version', trailing: 'v1.2.0'),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeToggle(bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
      ),
      title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(isDark ? 'Turn on for better viewing at night' : 'Switch to dark theme'),
      trailing: Switch.adaptive(
        value: isDark,
        activeColor: AppColors.primary,
        onChanged: (val) {
          final newMode = val ? ThemeMode.dark : ThemeMode.light;
          themeNotifier.value = newMode;
          RoleService.instance.updateThemePreference(
            uid: widget.user.uid,
            theme: val ? 'dark' : 'light',
          );
        },
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.orange),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(IconData icon, String title, {String? trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.grey),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: trailing != null 
          ? Text(trailing, style: const TextStyle(color: Colors.grey))
          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {},
    );
  }
}
