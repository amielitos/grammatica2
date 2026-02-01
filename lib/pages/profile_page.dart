import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../services/database_service.dart';

import 'manage_subscriptions_page.dart';
import 'educator_application_page.dart';

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
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  String? _info;
  String? _error;

  // Local state for profile data
  String _displayName = 'User';
  String _displayEmail = '';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _displayEmail = widget.user.email ?? 'no-email';
    _photoUrl = widget.user.photoURL;
    _displayName = widget.user.displayName ?? 'User';
    fetchProfile();
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

      if (mounted) {
        setState(() {
          _displayName = (fetchedUsername?.isNotEmpty == true)
              ? fetchedUsername!
              : (widget.user.displayName ?? 'User');
          _photoUrl = fetchedPhoto ?? widget.user.photoURL;
          _bioCtrl.text = fetchedBio;
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

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
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return Center(
                    child: Container(
                      width: isWide
                          ? constraints.maxWidth * 0.5
                          : double.infinity,
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text(
                              'Profile',
                              style: Theme.of(context).textTheme.displayLarge,
                            ),
                          ),
                          GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Colors.grey
                                              .withOpacity(0.2),
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
                                                            CupertinoIcons
                                                                .person_fill,
                                                            size: 50,
                                                          );
                                                        },
                                                  ),
                                                )
                                              : const Icon(
                                                  CupertinoIcons.person_fill,
                                                  size: 50,
                                                ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen,
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                CupertinoIcons.camera_fill,
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
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 32),
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
                                  FilledButton(
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
                                  FilledButton(
                                    onPressed: _updateBio,
                                    child: const Text('Update Bio'),
                                  ),
                                  if (roleSnap.data == UserRole.educator) ...[
                                    const Divider(height: 48),
                                    Text(
                                      'Subscription Settings',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Set your monthly subscription fee for learners:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 16),
                                    StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.user.uid)
                                          .snapshots(),
                                      builder: (context, userSnap) {
                                        final currentFee =
                                            userSnap.data
                                                ?.data()?['subscription_fee'] ??
                                            3;
                                        return CupertinoSlidingSegmentedControl<
                                          int
                                        >(
                                          groupValue: currentFee,
                                          children: const {
                                            3: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 20,
                                              ),
                                              child: Text('\$3'),
                                            ),
                                            5: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 20,
                                              ),
                                              child: Text('\$5'),
                                            ),
                                            7: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 20,
                                              ),
                                              child: Text('\$7'),
                                            ),
                                          },
                                          onValueChanged: (val) {
                                            if (val != null) {
                                              DatabaseService.instance
                                                  .updateSubscriptionFee(
                                                    widget.user.uid,
                                                    val,
                                                  );
                                              _showSnack(
                                                'Subscription fee updated to \$$val',
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                  const Divider(height: 48),
                                  Text(
                                    'Change Password',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _currentPasswordCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Current Password',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _newPasswordCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'New Password',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _confirmPasswordCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm New Password',
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _error!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                  if (_info != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _info!,
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
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
                                      OutlinedButton.icon(
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
                                        style: OutlinedButton.styleFrom(
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
                                  if (roleSnap.data == UserRole.learner) ...[
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Educator Role',
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
                                                  'View Application',
                                                ),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      application.status ==
                                                          'pending'
                                                      ? Colors.orange
                                                      : Colors.red,
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
                                                  _showBecomeEducatorDialog(),
                                              icon: const Icon(
                                                CupertinoIcons.briefcase_fill,
                                              ),
                                              label: const Text(
                                                'Become an Educator',
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.blue,
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
                                          return CupertinoSlidingSegmentedControl<
                                            ThemeMode
                                          >(
                                            groupValue: mode,
                                            onValueChanged: (newMode) {
                                              if (newMode != null) {
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
                                              }
                                            },
                                            children: const {
                                              ThemeMode.light: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.sun_max_fill,
                                                ),
                                              ),
                                              ThemeMode.dark: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.moon_fill,
                                                ),
                                              ),
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
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(
                                              color: Colors.red,
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
                                            backgroundColor:
                                                Colors.red.shade400,
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
                                                              Colors.red,
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBecomeEducatorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Become an Educator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock powerful features to teach and monetize your content:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• Monetize your lessons and quizzes'),
            const Text('• Create and manage learner groups'),
            const Text('• Detailed student progress tracking'),
            const Text('• Direct interaction with your students'),
            const SizedBox(height: 16),
            const Text(
              'Cost: \$5.00 / month',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.info_circle, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Applications are subject to approval. Note that you may lose your educator role if you violate our teaching guidelines.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EducatorApplicationPage(user: widget.user),
                ),
              );
            },
            child: const Text('Apply Now'),
          ),
        ],
      ),
    );
  }

  void _showApplicationStatusDialog(EducatorApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Application Status'),
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
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    application.status.toUpperCase(),
                    style: TextStyle(
                      color: application.status == 'pending'
                          ? Colors.orange
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              application.status == 'pending'
                  ? 'Your application for the Educator role is currently being reviewed by our super admins.'
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
              leading: const Icon(
                CupertinoIcons.videocam_fill,
                color: Colors.blue,
              ),
              title: const Text('Teaching Demo Video'),
              trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
              onTap: () {
                _showSnack('Opening video link...');
                // You could use url_launcher here if desired
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.doc_fill, color: Colors.red),
              title: const Text('Teaching Syllabus PDF'),
              trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
              onTap: () {
                _showSnack('Opening syllabus link...');
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
                    builder: (_) => EducatorApplicationPage(user: widget.user),
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
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          if (errText != null) ...[
            const SizedBox(height: 8),
            Text(errText!, style: const TextStyle(color: Colors.red)),
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
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: loading ? null : onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
