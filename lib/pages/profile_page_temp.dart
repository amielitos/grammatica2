import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import '../services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'manage_subscriptions_page.dart';
import 'role_application_page.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';

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
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Local state for profile data
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
          _phoneNumber = fetchedPhone;
          _dob = fetchedDob;
          if (_phoneNumber != null) {
            // NOTE: IntlPhoneField might struggle to parse this back into CC + Number key without parsing logic.
            // For now we just set the text, but the country code might default to PH if not parsed.
            // A robust solution parses the number. passing it to initialValue of IntlPhoneField is better if supported.
            // Fix: Strip +63 if present to avoid duplication in the text field
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(widget.user.uid),
      builder: (context, roleSnap) {
        if (roleSnap.connectionState == ConnectionState.waiting ||
            !roleSnap.hasData) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                                  Center(
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          child:
                                              (_photoUrl != null &&
                                                  _photoUrl!.isNotEmpty)
                                              ? ClipOval(
                                                  child: Image.network(
                                                    _photoUrl!,
                                                    width: 100,
                                                    height: 100,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return const Icon(
                                                            Icons.person,
                                                            size: 50,
                                                          );
                                                        },
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  size: 50,
                                                ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.camera_alt,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                              onPressed: () async {
                                                try {
                                                  final pick = await FilePicker
                                                      .platform
                                                      .pickFiles(
                                                        type: FileType.custom,
                                                        allowedExtensions: [
                                                          'jpg',
                                                          'jpeg',
                                                          'png',
                                                        ],
                                                        withData: true,
                                                      );
                                                  if (pick == null ||
                                                      pick.files.isEmpty) {
                                                    return;
                                                  }

                                                  final file = pick.files.first;
                                                  final bytes = file.bytes;
                                                  if (bytes == null) return;

                                                  if (bytes.lengthInBytes >
                                                      2097152) {
                                                    _showSnack(
                                                      'Image exceeds 2MB limit',
                                                      error: true,
                                                    );
                                                    return;
                                                  }

                                                  final fileExtension = file
                                                      .name
                                                      .toLowerCase()
                                                      .split('.')
                                                      .last;
                                                  final contentType =
                                                      fileExtension == 'png'
                                                      ? 'image/png'
                                                      : 'image/jpeg';

                                                  final ref = FirebaseStorage
                                                      .instance
                                                      .ref()
                                                      .child('users')
                                                      .child(widget.user.uid)
                                                      .child(
                                                        'profile_pic.$fileExtension',
                                                      );

                                                  await ref.putData(
                                                    bytes,
                                                    SettableMetadata(
                                                      contentType: contentType,
                                                    ),
                                                  );
                                                  final url = await ref
                                                      .getDownloadURL();
                                                  await widget.user
                                                      .updatePhotoURL(url);
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(widget.user.uid)
                                                      .set(
                                                        {'photoUrl': url},
                                                        SetOptions(merge: true),
                                                      );

                                                  if (mounted) {
                                                    setState(
                                                      () => _photoUrl = url,
                                                    );
                                                    _showSnack(
                                                      'Profile photo updated',
                                                    );
                                                  }
                                                } catch (e) {
                                                  _showSnack(
                                                    'Photo update failed: $e',
                                                    error: true,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _displayName,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _displayEmail,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 24),
                                  // WARNING FOR MISSING INFO
                                  if (_phoneNumber == null ||
                                      _phoneNumber!.isEmpty ||
                                      _dob == null) ...[
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondaryContainer,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSecondaryContainer,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Profile Incomplete',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSecondaryContainer,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'To unlock all features, please add the following information to your account:',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSecondaryContainer,
                                                  ),
                                            ),
                                            const SizedBox(height: 20),
                                            if (_phoneNumber == null ||
                                                _phoneNumber!.isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _phoneFocus
                                                      .requestFocus(),
                                                  icon: const Icon(Icons.phone),
                                                  label: const Text(
                                                    'Add Phone Number',
                                                  ),
                                                ),
                                              ),
                                            if (_dob == null)
                                              ElevatedButton.icon(
                                                onPressed: _updateDob,
                                                icon: const Icon(
                                                  Icons.calendar_today,
                                                ),
                                                label: const Text(
                                                  'Add Date of Birth',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                  ],

                                  Text(
                                    'Update Details',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _usernameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'New Username',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _updateUsername,
                                    child: const Text('Update Username'),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _bioCtrl,
                                    maxLength: 300,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      labelText: 'Bio',
                                      hintText: 'Tell us about yourself...',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _updateBio,
                                    child: const Text('Update Bio'),
                                  ),
                                  const SizedBox(height: 16),
                                  IntlPhoneField(
                                    controller: _phoneCtrl,
                                    focusNode: _phoneFocus,
                                    initialCountryCode:
                                        'PH', // Default to Philippines
                                    decoration: const InputDecoration(
                                      labelText: 'Phone Number',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    onChanged: (phone) {
                                      _completePhoneNumber =
                                          phone.completeNumber;
                                    },
                                    onCountryChanged: (country) {
                                      // print('Country changed to: ' + country.name);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _updatePhone,
                                    child: const Text('Update Phone Number'),
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: _updateDob,
                                    borderRadius: BorderRadius.circular(4),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date of Birth',
                                        prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                      child: Text(
                                        _dob != null
                                            ? '${_dob!.toDate().day}/${_dob!.toDate().month}/${_dob!.toDate().year}'
                                            : 'Select Date of Birth',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 48),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _currentPasswordCtrl,
                                    obscureText: _obscureCurrentPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Current Password',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureCurrentPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureCurrentPassword =
                                              !_obscureCurrentPassword,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _newPasswordCtrl,
                                    obscureText: _obscureNewPassword,
                                    decoration: InputDecoration(
                                      labelText: 'New Password',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureNewPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureNewPassword =
                                              !_obscureNewPassword,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _confirmPasswordCtrl,
                                    obscureText: _obscureConfirmPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm New Password',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureConfirmPassword =
                                              !_obscureConfirmPassword,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                  if (_info != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _info!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    style: FilledButton.styleFrom(
                                      // No explicit color set to follow theme
                                    ),
                                    onPressed: () async {
                                      setState(() {
                                        _info = null;
                                        _error = null;
                                      });
                                      final email = widget.user.email;
                                      final current = _currentPasswordCtrl.text;
                                      final newPass = _newPasswordCtrl.text;
                                      final confirm = _confirmPasswordCtrl.text;

                                      if (email == null) {
                                        setState(
                                          () => _error = 'No email on account.',
                                        );
                                        return;
                                      }
                                      if (newPass != confirm) {
                                        setState(
                                          () => _error =
                                              'New passwords do not match.',
                                        );
                                        return;
                                      }

                                      try {
                                        final cred =
                                            EmailAuthProvider.credential(
                                              email: email,
                                              password: current,
                                            );
                                        await widget.user
                                            .reauthenticateWithCredential(cred);
                                        await widget.user.updatePassword(
                                          newPass,
                                        );
                                        setState(
                                          () => _info = 'Password updated',
                                        );
                                        _currentPasswordCtrl.clear();
                                        _newPasswordCtrl.clear();
                                        _confirmPasswordCtrl.clear();
                                      } catch (e) {
                                        setState(
                                          () => _error =
                                              'Failed to update password. Check current password.',
                                        );
                                      }
                                    },
                                    child: const Text('Update Password'),
                                  ),
                                  const Divider(height: 48),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Subscriptions',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ManageSubscriptionsPage(
                                                    user: widget.user,
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          CupertinoIcons.creditcard_fill,
                                        ),
                                        label: const Text(
                                          'Manage Subscriptions',
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Divider(height: 48),
                                    ],
                                  ),
                                  if (roleSnap.data == UserRole.learner ||
                                      roleSnap.data == UserRole.educator ||
                                      roleSnap.data == UserRole.validator) ...[
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Want to join Grammatica?',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 16),
                                        StreamBuilder<EducatorApplication?>(
                                          stream: DatabaseService.instance
                                              .streamUserApplication(
                                                widget.user.uid,
                                              ),
                                          builder: (context, appSnap) {
                                            if (appSnap.hasError) {
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                  ),
                                                ),
                                                child: Text(
                                                  'Error loading application: ${appSnap.error}',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            }
                                            final application = appSnap.data;
                                            if (application != null &&
                                                (application.status ==
                                                        'pending' ||
                                                    application.status ==
                                                        'rejected')) {
                                              return FilledButton.icon(
                                                onPressed: () =>
                                                    _showApplicationStatusDialog(
                                                      application,
                                                    ),
                                                icon: const Icon(
                                                  CupertinoIcons.doc_text_fill,
                                                ),
                                                label: const Text(
                                                  'View Application Status',
                                                ),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      application.status ==
                                                          'pending'
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 16,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }

                                            return FilledButton.icon(
                                              onPressed: () =>
                                                  _showJoinGrammaticaDialog(
                                                    roleSnap.data!,
                                                  ),
                                              icon: const Icon(
                                                CupertinoIcons.sparkles,
                                              ),
                                              label: const Text(
                                                'Join Grammatica',
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const Divider(height: 48),
                                      ],
                                    ),
                                  ],
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'App Theme',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      ValueListenableBuilder<ThemeMode>(
                                        valueListenable: themeNotifier,
                                        builder: (context, mode, _) {
                                          return SegmentedButton<ThemeMode>(
                                            segments: const [
                                              ButtonSegment(
                                                value: ThemeMode.light,
                                                icon: Icon(Icons.light_mode),
                                              ),
                                              ButtonSegment(
                                                value: ThemeMode.dark,
                                                icon: Icon(Icons.dark_mode),
                                              ),
                                            ],
                                            selected: {mode},
                                            onSelectionChanged:
                                                (Set<ThemeMode> newSelection) {
                                                  final newMode =
                                                      newSelection.first;
                                                  themeNotifier.value = newMode;
                                                  RoleService.instance
                                                      .updateThemePreference(
                                                        uid: widget.user.uid,
                                                        theme:
                                                            newMode ==
                                                                ThemeMode.dark
                                                            ? 'dark'
                                                            : 'light',
                                                      );
                                                },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            side: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          onPressed: () async {
                                            await AuthService.instance
                                                .signOut();
                                          },
                                          child: const Text('Sign Out'),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: const Text(
                                                  'Delete Account?',
                                                ),
                                                content: const Text(
                                                  'This action cannot be undone.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(c, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .error,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.pop(c, true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                await AuthService.instance
                                                    .deleteAccount();
                                                // Auth changes will trigger navigation to login/onboarding automatically via main.dart
                                              } catch (e) {
                                                _showSnack(
                                                  'Delete failed: $e',
                                                  error: true,
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Delete Account'),
                                        ),
                                      ),
                                    ],
                                    ],
                                  ),
                                ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
    );
  }
}

