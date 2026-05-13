import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:file_picker/file_picker.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'manage_subscriptions_page.dart';
import 'role_application_page.dart';
import '../widgets/video_player_modal.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({super.key, required this.user});
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  // Removed unused variable

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  String? _info;
  String? _error;
  final bool _obscureCurrentPassword = true;
  final bool _obscureNewPassword = true;
  final bool _obscureConfirmPassword = true;

  // Local state for profile data
  bool _isEditing = false;
  String _displayName = 'User';
  String _displayEmail = '';
  String? _photoUrl;
  Timestamp? _dob;
  String? _phoneNumber;
  String? _completePhoneNumber;

  @override
  void initState() {
    super.initState();
    _displayEmail = widget.user.email ?? 'no-email';
    _photoUrl = widget.user.photoURL;
    _displayName = widget.user.displayName ?? 'User';
    fetchProfile();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    if (!mounted) return;
    // Optional: set loading state or just fetch quietly
    // setState(() => _isLoadingProfile = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      if (!doc.exists) {
        // Fallback to auth data if no firestore doc
        if (mounted) {
          setState(() {
            _displayName = widget.user.displayName ?? 'User';
            _photoUrl = widget.user.photoURL;
          });
        }
        return;
      }

      final data = doc.data();
      final fetchedUsername = (data?['username'] as String?)?.trim();
      final fetchedPhoto = (data?['photoUrl'] as String?);
      final fetchedBio = (data?['bio'] as String?)?.trim() ?? '';
      final fetchedPhone = (data?['phone_number'] as String?);
      final fetchedDob = (data?['date_of_birth'] as Timestamp?);

      if (mounted) {
        setState(() {
          _displayName = (fetchedUsername?.isNotEmpty == true)
              ? fetchedUsername!
              : (widget.user.displayName ?? 'User');
          _photoUrl = fetchedPhoto ?? widget.user.photoURL;
          _bioCtrl.text = fetchedBio;
          _usernameCtrl.text = _displayName; // Set username field to current name
          _phoneNumber = fetchedPhone;
          _dob = fetchedDob;
          if (_phoneNumber != null) {
            String phoneText = _phoneNumber!;
            if (phoneText.startsWith('+63')) {
              phoneText = phoneText.substring(3);
            }
            _phoneCtrl.text = phoneText;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  // ... (keeping _updateUsername and _updateBio as is)

  Future<void> _updateUsername() async {
    final email = widget.user.email;
    if (email == null) {
      _showSnack('No email on account', error: true);
      return;
    }
    final newName = _usernameCtrl.text.trim();

    if (newName.isEmpty) {
      _showSnack('Please enter a username', error: true);
      return;
    }

    final password = await showDialog<String?>(
      context: context,
      builder: (context) {
        final pwdCtrl = TextEditingController();
        return _ReauthDialog(email: email, user: widget.user, pwdCtrl: pwdCtrl);
      },
    );
    if (password == null || password.isEmpty) return;

    try {
      if (newName != widget.user.displayName) {
        await widget.user.updateDisplayName(newName);
      }
      await RoleService.instance.updateUsername(
        uid: widget.user.uid,
        username: newName,
      );
      if (!mounted) return;
      setState(() {
        _displayName = newName;
      });
      _showSnack('Username updated');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to update username', error: true);
    } catch (_) {
      _showSnack('Failed to update username', error: true);
    }
  }

  Future<void> _updateBio() async {
    final newBio = _bioCtrl.text.trim();

    if (newBio.length > 300) {
      _showSnack('Bio cannot exceed 300 characters', error: true);
      return;
    }

    try {
      await RoleService.instance.updateBio(uid: widget.user.uid, bio: newBio);
      _showSnack('Bio updated');
    } catch (e) {
      _showSnack('Failed to update bio', error: true);
    }
  }

  Future<void> _updatePhone() async {
    // Use the complete number from IntlPhoneField if available, otherwise fallback to controller
    final phone = _completePhoneNumber ?? _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      _showSnack('Please enter a phone number', error: true);
      return;
    }

    try {
      await DatabaseService.instance.updateUserField(
        widget.user.uid,
        'phone_number',
        phone,
      );
      if (mounted) {
        fetchProfile(); // Refresh
        _showSnack('Phone number updated');
      }
    } catch (e) {
      _showSnack('Failed to update phone number', error: true);
    }
  }

  // Keeping the dialog version for the "warning" section if needed,
  // or we can remove it if the inline field is sufficient.
  // For now, I'll remove _showUpdatePhoneDialog as it's redundant with the inline field.

  Future<void> _updateDob() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 7)),
    );
    if (picked == null) return;

    // Validate Age >= 7
    final now = DateTime.now();
    final age =
        now.year -
        picked.year -
        ((now.month < picked.month ||
                (now.month == picked.month && now.day < picked.day))
            ? 1
            : 0);
    if (age < 7) {
      _showSnack('You must be at least 7 years old.', error: true);
      return;
    }

    try {
      await DatabaseService.instance.updateUserField(
        widget.user.uid,
        'date_of_birth',
        Timestamp.fromDate(picked),
      );
      if (mounted) {
        fetchProfile();
        _showSnack('Date of birth updated');
      }
    } catch (e) {
      _showSnack('Failed to update date of birth', error: true);
    }
  }

    InputDecoration _customInputDecoration({required String hint}) {
    // Inputs remain white even in dark mode based on the mock-up
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF81B655), width: 2),
      ),
    );
  }

  Widget _buildGreenButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81B655), // Exact Green Color
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }

  Widget _buildThemeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  themeNotifier.value = ThemeMode.light;
                  RoleService.instance.updateThemePreference(uid: widget.user.uid, theme: 'light');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: !isDark ? const Color(0xFF81B655) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.light_mode, size: 20, color: !isDark ? Colors.white : Colors.grey),
                ),
              ),
              GestureDetector(
                onTap: () {
                  themeNotifier.value = ThemeMode.dark;
                  RoleService.instance.updateThemePreference(uid: widget.user.uid, theme: 'dark');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF81B655) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.dark_mode, size: 20, color: isDark ? Colors.white : Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftColumn() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF81B655);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              if (!_isEditing)
                TextButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF81B655)),
                  label: const Text('Edit Profile', style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => setState(() => _isEditing = false),
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  label: const Text('Cancel Request', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 40),
          
          // Header Section
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 4),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                _photoUrl!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(Icons.person, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                              ),
                            )
                          : Icon(Icons.person, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            final pick = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (pick == null || pick.files.isEmpty || !mounted) return;
                            
                            final file = pick.files.first;
                            if (file.bytes == null) return;

                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => _PhotoAdjustmentDialog(imageBytes: file.bytes!),
                            );

                            if (confirmed == true && mounted) {
                              final url = await DatabaseService.instance.uploadProfilePhotoWithBytes(
                                widget.user, 
                                file.bytes!, 
                                file.name
                              );
                              if (url != null && mounted) {
                                setState(() => _photoUrl = url);
                                _showSnack('Profile photo updated');
                              }
                            }
                          } catch (e) {
                            _showSnack('Photo update failed', error: true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(_displayEmail, style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                    if (_phoneNumber != null && !_isEditing) ...[
                       const SizedBox(height: 8),
                       Text(_phoneNumber!, style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade500)),
                    ]
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),

          if (!_isEditing) ...[
            // Status Section when not editing
            if (_phoneNumber == null || _phoneNumber!.isEmpty || _dob == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1), // Light Amber
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profile Incomplete', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF795548))),
                    const SizedBox(height: 8),
                    const Text('Add phone number and date of birth to unlock educator and validator applications.', style: TextStyle(color: Color(0xFF795548), height: 1.4)),
                  ],
                ),
              ),
            
            if (_bioCtrl.text.isNotEmpty) ...[
               const SizedBox(height: 24),
               const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
               const SizedBox(height: 8),
               Text(_bioCtrl.text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.5, fontSize: 14)),
            ],
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.calendar_today_outlined, 'Birthday', _dob != null ? '${_dob!.toDate().day}/${_dob!.toDate().month}/${_dob!.toDate().year}' : 'Not set'),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.phone_android_outlined, 'Phone', _phoneNumber ?? 'Not set'),

          ] else ...[
            // Edit Mode Fields
            Text('Edit Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 24),
            
            _buildEditLabel('Username'),
            TextField(
              controller: _usernameCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: _customInputDecoration(hint: 'New Username'),
            ),
            const SizedBox(height: 24),
            
            _buildEditLabel('Bio'),
            TextField(
              controller: _bioCtrl,
              maxLength: 300,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: _customInputDecoration(hint: 'Tell us about yourself...'),
            ),
            const SizedBox(height: 24),
            
            _buildEditLabel('Phone Number'),
            IntlPhoneField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              initialCountryCode: 'PH',
              decoration: _customInputDecoration(hint: 'Phone Number'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (phone) => _completePhoneNumber = phone.completeNumber,
            ),
            const SizedBox(height: 24),
            
            _buildEditLabel('Date of Birth'),
            InkWell(
              onTap: _updateDob,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: _customInputDecoration(hint: ''),
                child: Text(
                  _dob != null ? '${_dob!.toDate().day}/${_dob!.toDate().month}/${_dob!.toDate().year}' : 'Select Date of Birth',
                  style: TextStyle(fontSize: 14, color: _dob != null ? Colors.black : Colors.black54),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            _buildGreenButton('Save Changes', () async {
               // Update all fields
               await _updateUsername();
               await _updateBio();
               await _updatePhone();
               setState(() => _isEditing = false);
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text('Cancel Request', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF81B655).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: const Color(0xFF81B655)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumn(UserRole role, {required bool isWide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildThemeToggle(),
            ),
          ),
          
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
              const SizedBox(height: 24),
              TextField(
                controller: _currentPasswordCtrl,
                obscureText: _obscureCurrentPassword,
                style: const TextStyle(fontSize: 14),
                decoration: _customInputDecoration(hint: 'Current Password'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordCtrl,
                obscureText: _obscureNewPassword,
                style: const TextStyle(fontSize: 14),
                decoration: _customInputDecoration(hint: 'New Password'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(fontSize: 14),
                decoration: _customInputDecoration(hint: 'Confirm New Password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!, style: const TextStyle(color: Color(0xFF81B655))),
              ],
              const SizedBox(height: 24),
              _buildGreenButton('Update Password', () async {
                setState(() { _info = null; _error = null; });
                final email = widget.user.email;
                final current = _currentPasswordCtrl.text;
                final newPass = _newPasswordCtrl.text;
                final confirm = _confirmPasswordCtrl.text;
                if (email == null) { setState(() => _error = 'No email on account.'); return; }
                if (newPass != confirm) { setState(() => _error = 'New passwords do not match.'); return; }
                try {
                  final cred = EmailAuthProvider.credential(email: email, password: current);
                  await widget.user.reauthenticateWithCredential(cred);
                  await widget.user.updatePassword(newPass);
                  setState(() => _info = 'Password updated');
                  _currentPasswordCtrl.clear(); _newPasswordCtrl.clear(); _confirmPasswordCtrl.clear();
                } catch (e) {
                  setState(() => _error = 'Failed to update password. Check current password.');
                }
              }),
            ],
          ),
        ),

        if (role != UserRole.educator && role != UserRole.validator)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subscription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                const SizedBox(height: 24),
                _buildGreenButton('Manage Subscription', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ManageSubscriptionsPage(user: widget.user)));
                }),
              ],
            ),
          ),

        if (role == UserRole.learner || role == UserRole.educator)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Role Application', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                const SizedBox(height: 24),
                StreamBuilder<EducatorApplication?>(
                  stream: DatabaseService.instance.streamUserApplication(widget.user.uid),
                  builder: (context, appSnap) {
                    if (appSnap.hasError) return Text('Error: ${appSnap.error}', style: TextStyle(color: Colors.red));
                    final application = appSnap.data;
                    if (application != null && (application.status == 'pending' || application.status == 'rejected')) {
                      return _buildGreenButton(
                        'View Application Status',
                        () => _showApplicationStatusDialog(application),
                      );
                    }
                    return _buildGreenButton(
                      role == UserRole.educator ? 'Apply as Validator' : 'Apply as an Educator',
                      () => _showJoinGrammaticaDialog(role),
                    );
                  },
                ),
              ],
            ),
          ),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDF3F32), // EXACT mockup Red
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => AuthService.instance.signOut(),
                  child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333333) : Colors.white,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.black, width: Theme.of(context).brightness == Brightness.dark ? 0 : 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete Account?'),
                        content: const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await AuthService.instance.deleteAccount();
                      } catch (e) {
                        _showSnack('Delete failed: $e', error: true);
                      }
                    }
                  },
                  child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(widget.user.uid),
      builder: (context, roleSnap) {
        if (roleSnap.connectionState == ConnectionState.waiting || !roleSnap.hasData) {
          return const Scaffold(backgroundColor: Colors.transparent, body: Center(child: CircularProgressIndicator()));
        }
        final role = roleSnap.data!;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: isWide 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildLeftColumn()),
                            const SizedBox(width: 32),
                            Expanded(flex: 6, child: _buildRightColumn(role, isWide: true)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildThemeToggle(),
                            const SizedBox(height: 24),
                            _buildLeftColumn(),
                            const SizedBox(height: 24),
                            _buildRightColumn(role, isWide: false),
                          ],
                        ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
void _showJoinGrammaticaDialog(UserRole currentRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Grammatica'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentRole != UserRole.educator)
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Apply as Educator'),
                subtitle: const Text('Teach and monetize your content'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoleApplicationPage(
                        user: widget.user,
                        applicationType: 'educator',
                      ),
                    ),
                  );
                },
              ),
            if (currentRole == UserRole.educator)
              ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('Apply as Validator'),
                subtitle: const Text('Verify expertise in the English field'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoleApplicationPage(
                        user: widget.user,
                        applicationType: 'validator',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showApplicationStatusDialog(EducatorApplication application) {
    final isValidator = application.applicationType == 'validator';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isValidator ? 'Validator Application' : 'Educator Application',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: application.status == 'pending'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    application.status.toUpperCase(),
                    style: TextStyle(
                      color: application.status == 'pending'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              application.status == 'pending'
                  ? 'Your application for the ${isValidator ? 'Validator' : 'Educator'} role is currently being reviewed by our super admins.'
                  : 'Unfortunately, your application was not approved at this time. You can try applying again with updated credentials.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Text(
              'Submitted Credentials:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment_ind, color: Color(0xFF81B655)),
              title: const Text('CV Document'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                final uri = Uri.parse(application.cvUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            ...application.certificateUrls.asMap().entries.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified, color: Colors.indigo),
              title: Text('Certificate Document ${e.key + 1}'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                final uri = Uri.parse(e.value);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            )),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.videocam, color: Theme.of(context).colorScheme.primary),
              title: const Text('Teaching Demo Video'),
              trailing: const Icon(Icons.play_circle_outline, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => VideoPlayerModal(
                    videoUrl: application.videoUrl,
                    title: 'Teaching Demo',
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file, color: Colors.teal),
              title: const Text('Teaching Syllabus PDF'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                final uri = Uri.parse(application.syllabusUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (application.status == 'rejected')
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoleApplicationPage(
                      user: widget.user,
                      applicationType: application.applicationType,
                    ),
                  ),
                );
              },
              child: const Text('Re-apply'),
            ),
        ],
      ),
    );
  }
}

class _PhotoAdjustmentDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _PhotoAdjustmentDialog({required this.imageBytes});

  @override
  State<_PhotoAdjustmentDialog> createState() => _PhotoAdjustmentDialogState();
}

class _PhotoAdjustmentDialogState extends State<_PhotoAdjustmentDialog> {
  final TransformationController _controller = TransformationController();
  double _currentScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Adjust Photo', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pinch to zoom or drag to move. This is a preview of how your photo will appear.', 
            style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: InteractiveViewer(
                transformationController: _controller,
                boundaryMargin: const EdgeInsets.all(100),
                minScale: 0.5,
                maxScale: 4.0,
                onInteractionUpdate: (details) {
                   setState(() {
                     _currentScale = _controller.value.getMaxScaleOnAxis();
                   });
                },
                child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.zoom_out, size: 18, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: _currentScale.clamp(0.5, 4.0),
                  min: 0.5,
                  max: 4.0,
                  activeColor: const Color(0xFF81B655),
                  onChanged: (val) {
                    setState(() {
                      _currentScale = val;
                      _controller.value = Matrix4.diagonal3Values(val, val, 1.0);
                    });
                  },
                ),
              ),
              const Icon(Icons.zoom_in, size: 18, color: Colors.grey),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF81B655),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Set as Profile'),
        ),
      ],
    );
  }
}

class _ReauthDialog extends StatefulWidget {
  final String email;
  final User user;
  final TextEditingController pwdCtrl;

  const _ReauthDialog({
    required this.email,
    required this.user,
    required this.pwdCtrl,
  });

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  bool loading = false;
  String? errText;
  bool _obscurePassword = true;
  Future<void> onConfirm() async {
    setState(() {
      loading = true;
      errText = null;
    });
    try {
      final cred = EmailAuthProvider.credential(
        email: widget.email,
        password: widget.pwdCtrl.text,
      );
      await widget.user.reauthenticateWithCredential(cred);
      if (!mounted) return;
      Navigator.pop(context, widget.pwdCtrl.text);
    } on FirebaseAuthException catch (e) {
      setState(() {
        loading = false;
        errText = e.message ?? 'Reauthentication failed';
      });
    } catch (_) {
      setState(() {
        loading = false;
        errText = 'Reauthentication failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.pwdCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          if (errText != null) ...[
            const SizedBox(height: 8),
            Text(
              errText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(foregroundColor: Colors.white),
          onPressed: loading ? null : onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
