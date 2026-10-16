import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

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
import '../services/ai_rate_limit_service.dart';
import '../widgets/ai_quota_exceeded_dialog.dart';

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
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  // Local state for profile data
  bool _isEditing = false;
  String _displayName = 'User';
  String _roleStr = 'LEARNER';
  String? _photoUrl;
  Timestamp? _dob;
  String? _phoneNumber;
  String? _completePhoneNumber;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.user.photoURL;
    _displayName = widget.user.displayName ?? 'User';
    fetchProfile();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
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
      final fetchedRole = (data?['role'] as String?) ?? 'LEARNER';

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
          _roleStr = fetchedRole;
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

  InputDecoration _customInputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF22262B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF384350) : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF384350) : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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

  Widget _buildLeftColumn({bool isMobile = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleStr = _roleStr;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
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
              if (isMobile) _buildThemeToggle(),
            ],
          ),
          const SizedBox(height: 40),
          
          // STI ELMS Header Card Style
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Banner
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFF81B655), const Color(0xFF4A8A24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -45),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          _photoUrl!,
                                          width: 92,
                                          height: 92,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Icon(Icons.person, size: 46, color: isDark ? Colors.white24 : Colors.grey.shade400),
                                        ),
                                      )
                                    : Icon(Icons.person, size: 46, color: isDark ? Colors.white24 : Colors.grey.shade400),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
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

                                    final adjustedBytes = await showDialog<Uint8List>(
                                      context: context,
                                      builder: (context) => _PhotoAdjustmentDialog(imageBytes: file.bytes!),
                                    );

                                    if (adjustedBytes != null && mounted) {
                                      final url = await DatabaseService.instance.uploadProfilePhotoWithBytes(
                                        widget.user, 
                                        adjustedBytes, 
                                        'profile_${DateTime.now().millisecondsSinceEpoch}.png',
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
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF81B655), width: 1.5),
                                  ),
                                  child: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF81B655)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _displayName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            roleStr.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Grammatica Learning Platform',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF81B655),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _isEditing = !_isEditing),
                          icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined, size: 16),
                          label: Text(_isEditing ? 'Cancel Edit' : 'Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF81B655),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: _customInputDecoration(hint: 'New Username'),
            ),
            const SizedBox(height: 24),
            
            _buildEditLabel('Bio'),
            TextField(
              controller: _bioCtrl,
              maxLength: 300,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: _customInputDecoration(hint: 'Tell us about yourself...'),
            ),
            const SizedBox(height: 24),
            
            _buildEditLabel('Phone Number'),
            IntlPhoneField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              initialCountryCode: 'PH',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              dropdownTextStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
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
                  style: TextStyle(fontSize: 14, color: _dob != null ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white54 : Colors.black54)),
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

  Widget _buildAIUsageCard(UserRole role) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<AIRateLimitStatus>(
      stream: AIRateLimitService.instance.quotaStream(widget.user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildCard(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final status = snapshot.data!;
        final isUnlimited = status.isUnlimited;
        final used = status.used;
        final limit = status.limit;
        final remaining = status.remaining;
        final percentUsed = status.percentUsed;
        final isLow = !isUnlimited && remaining <= 2;
        final isExceeded = status.isExceeded;

        Color statusColor;
        if (isExceeded) {
          statusColor = const Color(0xFFEF4444); // Red
        } else if (isLow) {
          statusColor = const Color(0xFFF59E0B); // Amber
        } else {
          statusColor = const Color(0xFF81B655); // Grammatica Green
        }

        String roleTierLabel;
        if (role == UserRole.admin || role == UserRole.superadmin) {
          roleTierLabel = 'Admin • Unlimited';
        } else if (role == UserRole.educator) {
          roleTierLabel = 'Educator • 200/day';
        } else if (status.isSubscribed) {
          roleTierLabel = 'Premium Learner • 100/day';
        } else {
          roleTierLabel = 'Free Learner • 10/day';
        }

        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81B655).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 22,
                          color: Color(0xFF81B655),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily AI Usage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            'Today\'s generation quota & limits',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Text(
                      roleTierLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Progress Bar Section
              if (isUnlimited) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81B655).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF81B655).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.all_inclusive_rounded, color: Color(0xFF81B655), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unlimited Generations',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'You have generated $used requests today with no daily cap.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$used of $limit Used',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      '$remaining remaining',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentUsed,
                    minHeight: 10,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: isDark ? Colors.white54 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Resets in ${status.formattedTimeUntilReset}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => AIQuotaExceededDialog.showDetails(context, status),
                      child: const Text(
                        'Quota Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF81B655),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Upsell banner for free learners
              if (!isUnlimited && !status.isSubscribed && role == UserRole.learner) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unlock 100 daily generations with Premium',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageSubscriptionsPage(user: widget.user),
                            ),
                          );
                        },
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRightColumn(UserRole role, {required bool isWide}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        _ChangePasswordCard(user: widget.user),
        _buildAIUsageCard(role),

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

        if (isWide)
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
              if (role != UserRole.admin && role != UserRole.superadmin) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF333333) : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black,
                        side: BorderSide(color: isDark ? Colors.transparent : Colors.black, width: isDark ? 0 : 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmDeactivateAccount(),
                      child: const Text('Deactivate Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ],
          )
        else
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDF3F32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => AuthService.instance.signOut(),
                  child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              if (role != UserRole.admin && role != UserRole.superadmin) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF333333) : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      side: BorderSide(color: isDark ? Colors.transparent : Colors.black, width: isDark ? 0 : 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmDeactivateAccount(),
                    child: const Text('Deactivate Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),

        if (role != UserRole.admin && role != UserRole.superadmin) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A1515)
                    : const Color(0xFFFFF1F0),
                foregroundColor: const Color(0xFFDF3F32),
                side: const BorderSide(color: Color(0xFFDF3F32), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDF3F32), size: 22),
              label: const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: _confirmDeleteAccount,
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2416)
                  : const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.amber.shade700.withValues(alpha: 0.5)
                    : Colors.amber.shade400,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.amber.shade700,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Administrator accounts are protected and cannot be deleted or deactivated.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.amber.shade200
                          : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeactivateAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Deactivate Account?'),
        content: const Text(
            'Your account will be deactivated and you will be signed out.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDF3F32),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await AuthService.instance.deactivateAccount();
      } catch (e) {
        _showSnack('Deactivation failed: $e', error: true);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _DeleteAccountDialog(user: widget.user),
    );

    if (deleted == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted permanently.'),
          backgroundColor: Color(0xFF81B655),
        ),
      );
    }
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
                            _buildLeftColumn(isMobile: true),
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
  final GlobalKey _previewKey = GlobalKey();
  double _currentScale = 1.0;
  bool _isSaving = false;

  Future<Uint8List?> _renderAdjustedBytes() async {
    try {
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return widget.imageBytes;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error cropping photo: $e');
      return widget.imageBytes;
    }
  }

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
            child: RepaintBoundary(
              key: _previewKey,
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
          onPressed: _isSaving ? null : () => Navigator.pop(context, null),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  setState(() => _isSaving = true);
                  final bytes = await _renderAdjustedBytes();
                  if (mounted) nav.pop(bytes);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF81B655),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Set as Profile'),
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

class _DeleteAccountDialog extends StatefulWidget {
  final User user;
  const _DeleteAccountDialog({required this.user});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final isGoogleUser = widget.user.providerData.any(
      (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
    );
    final isPasswordUser = widget.user.providerData.any(
      (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
    );

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Re-authenticate if password user
      if (isPasswordUser) {
        final pwd = _passwordCtrl.text.trim();
        if (pwd.isEmpty) {
          setState(() {
            _isLoading = false;
            _error = 'Please enter your password to confirm.';
          });
          return;
        }
        await AuthService.instance.reauthenticateWithPassword(pwd);
      }

      // 2. Perform account deletion
      try {
        await AuthService.instance.deleteAccount();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login' && isGoogleUser) {
          await AuthService.instance.reauthenticateWithGoogle();
          await AuthService.instance.deleteAccount();
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.message ?? 'Failed to delete account (${e.code}).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to delete account: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPasswordUser = widget.user.providerData.any(
      (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    final isGoogleUser = widget.user.providerData.any(
      (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF262626) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDF3F32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDF3F32), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDF3F32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDF3F32).withValues(alpha: 0.2)),
              ),
              child: const Text(
                'All your progress, quizzes, notes, subscriptions, and profile data will be permanently removed.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFDF3F32),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isPasswordUser) ...[
              const SizedBox(height: 16),
              Text(
                'Enter your password to confirm:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF333333) : const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ] else if (isGoogleUser) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are signed in with Google. You may be prompted to re-authenticate with Google.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFDF3F32), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDF3F32),
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _handleDelete,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete Account'),
        ),
      ],
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  final User user;
  const _ChangePasswordCard({required this.user});

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  String? _info;
  String? _error;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hint,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF22262B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF384350) : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF384350) : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF81B655), width: 2),
      ),
    );
  }

  Future<void> _updatePassword() async {
    setState(() {
      _info = null;
      _error = null;
    });
    final email = widget.user.email;
    final current = _currentPasswordCtrl.text;
    final newPass = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (email == null) {
      setState(() => _error = 'No email on account.');
      return;
    }
    if (current.isEmpty) {
      setState(() => _error = 'Please enter your current password.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = EmailAuthProvider.credential(email: email, password: current);
      await widget.user.reauthenticateWithCredential(cred);
      await widget.user.updatePassword(newPass);
      if (mounted) {
        setState(() {
          _info = 'Password updated successfully!';
          _isLoading = false;
        });
        _currentPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to update password. Check current password.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasNewPass = _newPasswordCtrl.text.isNotEmpty;
    final hasConfirmPass = _confirmPasswordCtrl.text.isNotEmpty;
    final bool passwordsMatch = hasNewPass &&
        hasConfirmPass &&
        (_newPasswordCtrl.text == _confirmPasswordCtrl.text);
    final bool hasMinLength = _newPasswordCtrl.text.length >= 6;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change Password',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _currentPasswordCtrl,
            obscureText: _obscureCurrentPassword,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: _inputDecoration(
              context: context,
              hint: 'Current Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrentPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureCurrentPassword = !_obscureCurrentPassword,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordCtrl,
            obscureText: _obscureNewPassword,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: _inputDecoration(
              context: context,
              hint: 'New Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureNewPassword = !_obscureNewPassword,
                ),
              ),
            ),
          ),
          if (hasNewPass) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  hasMinLength
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 15,
                  color: hasMinLength
                      ? const Color(0xFF81B655)
                      : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  hasMinLength
                      ? 'At least 6 characters met'
                      : 'Password must be at least 6 characters',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasMinLength
                        ? const Color(0xFF81B655)
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordCtrl,
            obscureText: _obscureConfirmPassword,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: _inputDecoration(
              context: context,
              hint: 'Confirm New Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ),
          ),
          if (hasConfirmPass) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  passwordsMatch
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 15,
                  color: passwordsMatch
                      ? const Color(0xFF81B655)
                      : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  passwordsMatch
                      ? 'Passwords match'
                      : 'Passwords do not match',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: passwordsMatch
                        ? const Color(0xFF81B655)
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!, style: const TextStyle(color: Color(0xFF81B655))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

