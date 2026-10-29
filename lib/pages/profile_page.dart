import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../widgets/learner_badges_card.dart';

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

  String _capitalizeWords(String input) {
    if (input.trim().isEmpty) return '';
    return input.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  final _usernameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Cached streams to prevent StreamBuilder rebuilds from resetting scroll position
  late Stream<UserRole> _roleStream;
  late Stream<AIRateLimitStatus> _quotaStream;
  late Stream<EducatorApplication?> _applicationStream;

  // Local state for profile data
  bool _isEditing = false;
  bool _editSubmitted = false;
  String _displayName = 'User';
  String _roleStr = 'LEARNER';
  String? _photoUrl;
  Timestamp? _dob;
  Timestamp? _createdAt;

  int? get _userAge {
    if (_dob == null) return null;
    final birthDate = _dob!.toDate();
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  int get _accountAgeDays {
    final created = _createdAt?.toDate() ?? widget.user.metadata.creationTime ?? DateTime.now();
    return DateTime.now().difference(created).inDays;
  }

  void _initStreams() {
    _roleStream = RoleService.instance.roleStream(widget.user.uid);
    _quotaStream = AIRateLimitService.instance.quotaStream(widget.user.uid);
    _applicationStream = DatabaseService.instance.streamUserApplication(widget.user.uid);
  }

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.user.photoURL;
    _displayName = widget.user.displayName ?? 'User';
    _initStreams();
    fetchProfile();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _initStreams();
      fetchProfile();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _bioCtrl.dispose();
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
      final fetchedFirstName = (data?['first_name'] as String?)?.trim() ?? '';
      final fetchedMiddleName = (data?['middle_name'] as String?)?.trim() ?? '';
      final fetchedLastName = (data?['last_name'] as String?)?.trim() ?? '';
      final fetchedPhoto = (data?['photoUrl'] as String?);
      final fetchedBio = (data?['bio'] as String?)?.trim() ?? '';
      final fetchedDob = (data?['date_of_birth'] as Timestamp?);
      final fetchedCreatedAt = (data?['createdAt'] as Timestamp?);
      final fetchedRole = (data?['role'] as String?) ?? 'LEARNER';

      if (mounted) {
        setState(() {
          final computedFullName = [fetchedFirstName, fetchedMiddleName, fetchedLastName]
              .where((s) => s.isNotEmpty)
              .join(' ');
          _displayName = (computedFullName.isNotEmpty)
              ? computedFullName
              : ((data?['full_name'] as String?)?.trim().isNotEmpty == true)
                  ? (data?['full_name'] as String).trim()
                  : ((fetchedUsername?.isNotEmpty == true)
                      ? fetchedUsername!
                      : (widget.user.displayName ?? 'User'));
          _photoUrl = fetchedPhoto ?? widget.user.photoURL;
          _bioCtrl.text = fetchedBio;
          _usernameCtrl.text = (fetchedUsername?.isNotEmpty == true) ? fetchedUsername! : _displayName;
          _firstNameCtrl.text = fetchedFirstName;
          _middleNameCtrl.text = fetchedMiddleName;
          _lastNameCtrl.text = fetchedLastName;
          _dob = fetchedDob;
          _createdAt = fetchedCreatedAt;
          _roleStr = fetchedRole;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  // ... (keeping _updateUsername and _updateBio as is)


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

  Future<void> _confirmCancelEdit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Discard Changes?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to cancel? Any unsaved edits will be discarded.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep Editing', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Discard', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      fetchProfile();
      setState(() {
        _editSubmitted = false;
        _isEditing = false;
      });
    }
  }

  InputDecoration _customInputDecoration({
    required String hint,
    Widget? suffixIcon,
    String? errorText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRequired = hint.trim().endsWith('*');
    final String cleanHint = isRequired
        ? hint.replaceAll(RegExp(r'\s*\*'), '').trim()
        : hint;

    return InputDecoration(
      hintText: isRequired ? null : hint,
      errorText: errorText,
      label: isRequired
          ? Text.rich(
              TextSpan(
                text: cleanHint,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : null,
      floatingLabelBehavior: FloatingLabelBehavior.never,
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
                          onPressed: () {
                            if (_isEditing) {
                              _confirmCancelEdit();
                            } else {
                              setState(() {
                                _editSubmitted = false;
                                _isEditing = true;
                              });
                            }
                          },
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
            if (_dob == null)
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
                    const Text('Add date of birth to unlock educator and validator applications.', style: TextStyle(color: Color(0xFF795548), height: 1.4)),
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

          ] else ...[
            // Edit Mode Fields
            Text('Edit Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 24),

            // First Name and Middle Name (Responsive layout)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final firstNameWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditLabel('First Name *'),
                    TextField(
                      controller: _firstNameCtrl,
                      onChanged: (_) {
                        if (_editSubmitted) setState(() {});
                      },
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
                        _ProfileCapitalizerFormatter(),
                      ],
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      decoration: _customInputDecoration(
                        hint: 'First Name',
                        errorText: _editSubmitted && _firstNameCtrl.text.trim().isEmpty
                            ? 'First Name is required'
                            : null,
                      ),
                    ),
                  ],
                );

                final middleNameWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditLabel('Middle Name'),
                    TextField(
                      controller: _middleNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
                        _ProfileCapitalizerFormatter(),
                      ],
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      decoration: _customInputDecoration(hint: 'Middle Name (Optional)'),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      firstNameWidget,
                      const SizedBox(height: 18),
                      middleNameWidget,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: firstNameWidget),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: middleNameWidget),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Last Name
            _buildEditLabel('Last Name *'),
            TextField(
              controller: _lastNameCtrl,
              onChanged: (_) {
                if (_editSubmitted) setState(() {});
              },
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
                _ProfileCapitalizerFormatter(),
              ],
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: _customInputDecoration(
                hint: 'Last Name',
                errorText: _editSubmitted && _lastNameCtrl.text.trim().isEmpty
                    ? 'Last Name is required'
                    : null,
              ),
            ),
            const SizedBox(height: 18),

            _buildEditLabel('Bio'),
            TextField(
              controller: _bioCtrl,
              maxLength: 300,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: _customInputDecoration(hint: 'Tell us about yourself...'),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                _buildEditLabel('Date of Birth'),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Date of birth cannot be modified.',
                  child: Icon(Icons.lock_outline_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                ),
              ],
            ),
            InputDecorator(
              decoration: _customInputDecoration(hint: '').copyWith(
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dob != null
                        ? '${_dob!.toDate().day}/${_dob!.toDate().month}/${_dob!.toDate().year}'
                        : 'Not specified',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  Icon(Icons.lock_rounded, size: 16, color: isDark ? Colors.white24 : Colors.grey.shade400),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Date of birth is set during registration and cannot be edited.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 48),
            _buildGreenButton('Save Changes', () async {
               setState(() => _editSubmitted = true);
               final first = _capitalizeWords(_firstNameCtrl.text);
               final middle = _capitalizeWords(_middleNameCtrl.text);
               final last = _capitalizeWords(_lastNameCtrl.text);

               _firstNameCtrl.text = first;
               _middleNameCtrl.text = middle;
               _lastNameCtrl.text = last;

               if (first.isEmpty || last.isEmpty) {
                 _showSnack('Please fill in all required fields', error: true);
                 return;
               }

               // Confirmation dialog before saving changes
               final confirm = await showDialog<bool>(
                 context: context,
                 builder: (ctx) => AlertDialog(
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                   title: Row(
                     children: [
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: const Color(0xFF81B655).withValues(alpha: 0.15),
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.help_outline_rounded, color: Color(0xFF81B655), size: 24),
                       ),
                       const SizedBox(width: 12),
                       Text('Save Changes?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                     ],
                   ),
                   content: Text(
                     'Are you sure you want to save the changes to your profile information?',
                     style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                   ),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.pop(ctx, false),
                       child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                     ),
                     FilledButton(
                       style: FilledButton.styleFrom(
                         backgroundColor: const Color(0xFF81B655),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       ),
                       onPressed: () => Navigator.pop(ctx, true),
                       child: Text('Yes, Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                     ),
                   ],
                 ),
               );
               if (confirm != true) return;

               String fullName = first;
               if (middle.isNotEmpty) fullName += ' $middle';
               fullName += ' $last';

               try {
                 await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({
                   'first_name': first,
                   'middle_name': middle,
                   'last_name': last,
                   'full_name': fullName,
                   'name': fullName,
                   'displayName': fullName,
                   'username': fullName,
                   'updatedAt': FieldValue.serverTimestamp(),
                 }, SetOptions(merge: true));

                 await widget.user.updateDisplayName(fullName);
                 await widget.user.reload();
               } catch (e) {
                 debugPrint('Error updating name fields: $e');
               }

               await _updateBio();
               await fetchProfile();

               if (mounted) {
                 setState(() {
                   _displayName = fullName;
                   _editSubmitted = false;
                   _isEditing = false;
                 });
                 _showSnack('Profile information updated successfully');
               }
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _confirmCancelEdit,
                child: const Text('Cancel Request', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditLabel(String text) {
    final bool isRequired = text.trim().endsWith('*');
    final String cleanText = isRequired
        ? text.replaceAll(RegExp(r'\s*\*'), '').trim()
        : text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: isRequired
          ? Text.rich(
              TextSpan(
                text: cleanText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey,
                ),
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
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
      stream: _quotaStream,
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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  Expanded(
                    child: Column(
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
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
        if (role != UserRole.validator) _buildAIUsageCard(role),

        if (role == UserRole.learner) ...[
          LearnerBadgesCard(uid: widget.user.uid),
          const SizedBox(height: 24),
        ],

        if (role == UserRole.learner)
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
                  stream: _applicationStream,
                  builder: (context, appSnap) {
                    if (appSnap.hasError) return Text('Error: ${appSnap.error}', style: const TextStyle(color: Colors.red));
                    final application = appSnap.data;
                    
                    // If user is already approved as educator or current role is educator
                    final isApprovedEducator = role == UserRole.educator || application?.status == 'approved';

                    if (isApprovedEducator) {
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: null, // Greyed out / disabled
                          icon: const Icon(Icons.verified_rounded, color: Colors.grey),
                          label: const Text(
                            'Educator Status: Approved',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155).withValues(alpha: 0.5)
                                : const Color(0xFFE2E8F0),
                            disabledBackgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155).withValues(alpha: 0.5)
                                : const Color(0xFFE2E8F0),
                            disabledForegroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      );
                    }

                    // If user has applied and it's pending or rejected, show status button (no re-application)
                    if (application != null && (application.status == 'pending' || application.status == 'rejected')) {
                      final isPending = application.status == 'pending';
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _showApplicationStatusDialog(application),
                          icon: Icon(
                            isPending ? Icons.hourglass_top_rounded : Icons.info_outline_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            isPending ? 'View Application Status (Pending)' : 'View Application Status (Rejected)',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      );
                    }

                    return _buildGreenButton(
                      'Apply as an Educator',
                      () => _startEducatorApplication(),
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
                    onPressed: () => AuthService.instance.confirmAndSignOut(context),
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
                  onPressed: () => AuthService.instance.confirmAndSignOut(context),
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
      stream: _roleStream,
      builder: (context, roleSnap) {
        if (roleSnap.connectionState == ConnectionState.waiting && !roleSnap.hasData) {
          return const Scaffold(backgroundColor: Colors.transparent, body: Center(child: CircularProgressIndicator()));
        }
        final role = roleSnap.data ?? roleFromString(_roleStr);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return SingleChildScrollView(
                controller: _scrollController,
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
  void _startEducatorApplication() {
    final age = _userAge;
    final accountDays = _accountAgeDays;
    final isAgeValid = age != null && age >= 21;
    final isAccountAgeValid = accountDays >= 7;

    if (!isAgeValid || !isAccountAgeValid) {
      showDialog(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Application Requirements',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To ensure quality instruction on Grammatica, applicants must meet the following criteria before applying:',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAgeValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isAgeValid ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                children: [
                                  const TextSpan(text: 'Age 21 or older: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(
                                    text: age != null ? '$age years old' : 'Date of birth not provided',
                                    style: TextStyle(
                                      color: isAgeValid ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Icon(
                            isAccountAgeValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isAccountAgeValid ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                children: [
                                  const TextSpan(text: 'Joined 7+ days: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(
                                    text: '$accountDays days as member',
                                    style: TextStyle(
                                      color: isAccountAgeValid ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Understood'),
              ),
            ],
          );
        },
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleApplicationPage(
          user: widget.user,
          applicationType: 'educator',
        ),
      ),
    );
  }


  void _showApplicationStatusDialog(EducatorApplication application) {
    final isValidator = application.applicationType == 'validator';
    final isPending = application.status == 'pending';
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isValidator ? 'Validator Application' : 'Educator Application',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
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
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? (isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7))
                            : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPending
                              ? (isDark ? const Color(0xFF22C55E) : const Color(0xFF86EFAC))
                              : (isDark ? const Color(0xFFEF4444) : const Color(0xFFFCA5A5)),
                        ),
                      ),
                      child: Text(
                        application.status.toUpperCase(),
                        style: TextStyle(
                          color: isPending
                              ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                              : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isPending
                      ? 'Your application for the ${isValidator ? 'Validator' : 'Educator'} role is currently being reviewed by our super admins.'
                      : 'Unfortunately, your application was not approved at this time. Please review the reason below or contact support.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                if (!isPending) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Text(
                              'Reason for Rejection:',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (application.rejectionReason != null && application.rejectionReason!.trim().isNotEmpty)
                              ? application.rejectionReason!
                              : (application.rejectionDescription != null && application.rejectionDescription!.trim().isNotEmpty)
                                  ? application.rejectionDescription!
                                  : 'Credentials did not satisfy platform verification requirements.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF7F1D1D),
                          ),
                        ),
                        if (application.rejectionDescription != null &&
                            application.rejectionDescription!.trim().isNotEmpty &&
                            application.rejectionReason != null &&
                            application.rejectionReason!.trim().isNotEmpty &&
                            application.rejectionDescription!.trim() != application.rejectionReason!.trim()) ...[
                          const SizedBox(height: 6),
                          Text(
                            application.rejectionDescription!,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              height: 1.4,
                              color: isDark ? Colors.white70 : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Submitted Credentials:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                _buildCredentialCard(
                  icon: Icons.assignment_ind_rounded,
                  iconColor: const Color(0xFF81B655),
                  title: 'CV Document',
                  actionIcon: Icons.open_in_new_rounded,
                  isDark: isDark,
                  onTap: () async {
                    final uri = Uri.parse(application.cvUrl);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
                ...application.certificateUrls.asMap().entries.map((e) => _buildCredentialCard(
                  icon: Icons.verified_rounded,
                  iconColor: Colors.indigo,
                  title: 'Certificate Document ${e.key + 1}',
                  actionIcon: Icons.open_in_new_rounded,
                  isDark: isDark,
                  onTap: () async {
                    final uri = Uri.parse(e.value);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                )),
                _buildCredentialCard(
                  icon: Icons.videocam_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: 'Teaching Demo Video',
                  actionIcon: Icons.play_circle_outline_rounded,
                  isDark: isDark,
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
                _buildCredentialCard(
                  icon: Icons.insert_drive_file_rounded,
                  iconColor: Colors.teal,
                  title: 'Teaching Syllabus PDF',
                  actionIcon: Icons.open_in_new_rounded,
                  isDark: isDark,
                  onTap: () async {
                    final uri = Uri.parse(application.syllabusUrl);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCredentialCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required IconData actionIcon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E281C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        trailing: Icon(actionIcon, size: 18, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
        onTap: onTap,
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
  String? _fieldError;
  bool _obscurePassword = true;
  Future<void> onConfirm() async {
    if (widget.pwdCtrl.text.isEmpty) {
      setState(() {
        _fieldError = 'Password is required';
      });
      return;
    }
    setState(() {
      loading = true;
      errText = null;
      _fieldError = null;
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
            onChanged: (_) {
              if (_fieldError != null) setState(() => _fieldError = null);
            },
            decoration: InputDecoration(
              errorText: _fieldError,
              label: const Text.rich(
                TextSpan(
                  text: 'Password',
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
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
  String? _passwordFieldError;

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
      _passwordFieldError = null;
    });

    try {
      // 1. Re-authenticate if password user
      if (isPasswordUser) {
        final pwd = _passwordCtrl.text.trim();
        if (pwd.isEmpty) {
          setState(() {
            _isLoading = false;
            _passwordFieldError = 'Password is required';
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
                onChanged: (_) {
                  if (_passwordFieldError != null) {
                    setState(() => _passwordFieldError = null);
                  }
                },
                decoration: InputDecoration(
                  errorText: _passwordFieldError,
                  label: const Text.rich(
                    TextSpan(
                      text: 'Enter your password',
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
  bool _submitted = false;

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
    String? errorText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRequired = hint.trim().endsWith('*');
    final String cleanHint = isRequired
        ? hint.replaceAll(RegExp(r'\s*\*'), '').trim()
        : hint;

    return InputDecoration(
      hintText: isRequired ? null : hint,
      errorText: errorText,
      label: isRequired
          ? Text.rich(
              TextSpan(
                text: cleanHint,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : null,
      floatingLabelBehavior: FloatingLabelBehavior.never,
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
      _submitted = true;
      _info = null;
      _error = null;
    });
    final email = widget.user.email;
    final current = _currentPasswordCtrl.text;
    final newPass = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      return;
    }

    if (email == null) {
      setState(() => _error = 'No email on account.');
      return;
    }
    if (!_hasMinLength(newPass)) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (!_isPasswordValid(newPass)) {
      setState(() => _error = 'Password must meet all 5 security requirements below.');
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
          _submitted = false;
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

  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUppercase(String p) => RegExp(r'[A-Z]').hasMatch(p);
  bool _hasLowercase(String p) => RegExp(r'[a-z]').hasMatch(p);
  bool _hasDigit(String p) => RegExp(r'[0-9]').hasMatch(p);
  bool _hasSpecial(String p) => RegExp(r'[!@#\$%^&*(),.?":{}|<>~_\-+=\\/\[\]]').hasMatch(p);

  bool _isPasswordValid(String p) =>
      _hasMinLength(p) &&
      _hasUppercase(p) &&
      _hasLowercase(p) &&
      _hasDigit(p) &&
      _hasSpecial(p);

  String _getPasswordStrength(String pass) {
    if (pass.isEmpty) return '';
    int score = 0;
    if (_hasMinLength(pass)) score++;
    if (_hasUppercase(pass)) score++;
    if (_hasLowercase(pass)) score++;
    if (_hasDigit(pass)) score++;
    if (_hasSpecial(pass)) score++;
    if (score <= 2) return 'Weak';
    if (score <= 4) return 'Medium';
    return 'Strong';
  }

  Color _getStrengthColor(String pass) {
    final s = _getPasswordStrength(pass);
    if (s == 'Weak') return Colors.red;
    if (s == 'Medium') return Colors.orange;
    if (s == 'Strong') return const Color(0xFF81B655);
    return Colors.transparent;
  }

  Widget _buildReqRow(String label, bool met, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: met ? const Color(0xFF81B655) : (isDark ? Colors.white38 : Colors.grey.shade400),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                color: met
                    ? (isDark ? const Color(0xFF98D468) : const Color(0xFF2E7D32))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newPass = _newPasswordCtrl.text;
    final hasNewPass = newPass.isNotEmpty;
    final hasConfirmPass = _confirmPasswordCtrl.text.isNotEmpty;
    final bool passwordsMatch = hasNewPass &&
        hasConfirmPass &&
        (newPass == _confirmPasswordCtrl.text);

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
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: _inputDecoration(
              context: context,
              hint: 'Current Password *',
              errorText: _submitted && _currentPasswordCtrl.text.isEmpty
                  ? 'Current password is required'
                  : null,
              suffixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
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
              hint: 'New Password *',
              errorText: _submitted && _newPasswordCtrl.text.isEmpty
                  ? 'New password is required'
                  : null,
              suffixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
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
          ),
          if (hasNewPass) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            color: _getStrengthColor(newPass),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 4,
                            color: (_getPasswordStrength(newPass) == 'Medium' ||
                                    _getPasswordStrength(newPass) == 'Strong')
                                ? _getStrengthColor(newPass)
                                : (isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 4,
                            color: _getPasswordStrength(newPass) == 'Strong'
                                ? _getStrengthColor(newPass)
                                : (isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _getPasswordStrength(newPass),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStrengthColor(newPass),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Persistent Password Requirements Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22262B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF384350) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 15, color: Color(0xFF81B655)),
                    const SizedBox(width: 8),
                    Text(
                      'Password Security Restrictions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildReqRow('At least 8 characters', _hasMinLength(newPass), isDark),
                _buildReqRow('At least 1 uppercase letter (A-Z)', _hasUppercase(newPass), isDark),
                _buildReqRow('At least 1 lowercase letter (a-z)', _hasLowercase(newPass), isDark),
                _buildReqRow('At least 1 number (0-9)', _hasDigit(newPass), isDark),
                _buildReqRow('At least 1 special character', _hasSpecial(newPass), isDark),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Allowed special characters: ! @ # \$ % ^ & * ( ) , . ? " : { } | < > ~ _ - + =',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              hint: 'Confirm New Password *',
              errorText: _submitted && _confirmPasswordCtrl.text.isEmpty
                  ? 'Confirm new password is required'
                  : null,
              suffixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
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
                disabledBackgroundColor: isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.5)
                    : const Color(0xFFCBD5E1),
                disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCapitalizerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text;
    final words = text.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).join(' ');

    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}
