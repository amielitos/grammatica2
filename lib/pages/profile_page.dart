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

      if (mounted) {
        setState(() {
          _displayName = (fetchedUsername?.isNotEmpty == true)
              ? fetchedUsername!
              : (widget.user.displayName ?? 'User');
          _photoUrl = fetchedPhoto ?? widget.user.photoURL;
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

  Future<void> _promptAndUpdateUsername() async {
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
      await widget.user.updateDisplayName(newName);
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
                                    onPressed: _promptAndUpdateUsername,
                                    child: const Text('Update Username'),
                                  ),
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
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(widget.user.uid)
                                                    .delete();
                                                await widget.user.delete();
                                              } catch (e) {
                                                _showSnack('Delete failed: $e');
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
