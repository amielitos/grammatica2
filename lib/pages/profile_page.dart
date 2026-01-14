import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';
import '../utils/responsive_layout.dart';

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
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = roleSnap.data;
        final isLearner = role == UserRole.learner;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ResponsiveContainer(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Theme.of(context).dividerColor,
                          child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                              ? ClipOval(
                                  child: Image.network(
                                    _photoUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Profile image load error: $error');
                                      return const Icon(Icons.person, size: 40);
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        },
                                  ),
                                )
                              : const Icon(Icons.person, size: 40),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _displayName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _displayEmail,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final pick = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png'],
                                withData: true,
                              );
                              if (pick == null || pick.files.isEmpty) {
                                return;
                              }
                              final file = pick.files.first;
                              final bytes = file.bytes;
                              if (bytes == null) return;

                              // Check file size (max 2MB)
                              if (bytes.lengthInBytes > 2097152) {
                                // 2MB in bytes
                                _showSnack(
                                  'Image size exceeds 2MB limit',
                                  error: true,
                                );
                                return;
                              }

                              // Check file extension for allowed formats
                              final fileExtension = file.name
                                  .toLowerCase()
                                  .split('.')
                                  .last;
                              if (![
                                'jpg',
                                'jpeg',
                                'png',
                              ].contains(fileExtension)) {
                                _showSnack(
                                  'Only JPG and PNG files are allowed',
                                  error: true,
                                );
                                return;
                              }

                              // Determine content type based on file extension
                              final contentType = fileExtension == 'png'
                                  ? 'image/png'
                                  : 'image/jpeg';

                              // Delete old profile picture if exists
                              // We use the local state _photoUrl instead of fetching again
                              final oldPhotoUrl = _photoUrl;

                              if (oldPhotoUrl != null &&
                                  oldPhotoUrl.isNotEmpty) {
                                try {
                                  // Extract file path from URL to delete old image
                                  final RegExp regExp = RegExp(
                                    r'/(.+)/o/(.+)\?alt=',
                                  );
                                  final Match? match = regExp.firstMatch(
                                    oldPhotoUrl,
                                  );
                                  if (match != null) {
                                    final filePath = match.group(2);
                                    if (filePath != null) {
                                      await FirebaseStorage.instance
                                          .ref()
                                          .child(Uri.decodeComponent(filePath))
                                          .delete();
                                    }
                                  }
                                } catch (e) {
                                  // If we can't extract and delete the old image, just continue
                                  print(
                                    'Could not delete old profile picture: $e',
                                  );
                                }
                              }

                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('users')
                                  .child(widget.user.uid)
                                  .child('profile_pic.$fileExtension');
                              await ref.putData(
                                bytes,
                                SettableMetadata(contentType: contentType),
                              );
                              final url = await ref.getDownloadURL();
                              await widget.user.updatePhotoURL(url);
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.user.uid)
                                  .set({
                                    'photoUrl': url,
                                  }, SetOptions(merge: true));

                              if (mounted) {
                                setState(() {
                                  _photoUrl = url;
                                });
                                _showSnack('Profile photo updated');
                              }
                            } catch (e) {
                              _showSnack(
                                'Photo update failed: $e',
                                error: true,
                              );
                            }
                          },
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Change Photo'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),

                  // Editing controls
                  ResponsiveLayout.isMobile(context)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _usernameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _promptAndUpdateUsername,
                              child: const Text('Update Username'),
                            ),
                            const Divider(height: 32),
                            TextField(
                              controller: _currentPasswordCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Current Password',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newPasswordCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New Password',
                              ),
                            ),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 8),
                            FilledButton(
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
                                    () =>
                                        _error = 'New passwords do not match.',
                                  );
                                  return;
                                }
                                if (newPass.length < 6) {
                                  setState(
                                    () => _error =
                                        'Password must be at least 6 characters.',
                                  );
                                  return;
                                }
                                try {
                                  final cred = EmailAuthProvider.credential(
                                    email: email,
                                    password: current,
                                  );
                                  await widget.user
                                      .reauthenticateWithCredential(cred);
                                  await widget.user.updatePassword(newPass);
                                  setState(() => _info = 'Password updated');
                                  _currentPasswordCtrl.clear();
                                  _newPasswordCtrl.clear();
                                  _confirmPasswordCtrl.clear();
                                } on FirebaseAuthException catch (e) {
                                  setState(
                                    () => _error =
                                        e.message ??
                                        'Failed to update password',
                                  );
                                } catch (e) {
                                  setState(
                                    () => _error = 'Failed to update password',
                                  );
                                }
                              },
                              child: const Text('Update Password'),
                            ),
                            const Divider(height: 32),
                            FilledButton.tonal(
                              onPressed: () async {
                                try {
                                  await AuthService.instance.signOut();
                                  // The auth state listener in main.dart will automatically
                                  // redirect to LoginPage when user becomes null
                                } catch (e) {
                                  _showSnack(
                                    'Sign out failed: $e',
                                    error: true,
                                  );
                                }
                              },
                              child: const Text('Sign Out'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  await FirebaseAuth.instance.currentUser
                                      ?.reload();
                                  await FirebaseAuth.instance.currentUser
                                      ?.delete();
                                } catch (_) {}
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.user.uid)
                                      .delete();
                                } catch (_) {}
                                if (mounted) Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete Account'),
                            ),
                            if (_info != null) ...[
                              const SizedBox(height: 8),
                              Text(_info!),
                            ],
                          ],
                        )
                      : Align(
                          alignment: isLearner
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _usernameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: _promptAndUpdateUsername,
                                  child: const Text('Update Username'),
                                ),
                                const Divider(height: 32),
                                TextField(
                                  controller: _currentPasswordCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Current Password',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _newPasswordCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'New Password',
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                                const SizedBox(height: 8),
                                FilledButton(
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
                                    if (newPass.length < 6) {
                                      setState(
                                        () => _error =
                                            'Password must be at least 6 characters.',
                                      );
                                      return;
                                    }
                                    try {
                                      final cred = EmailAuthProvider.credential(
                                        email: email,
                                        password: current,
                                      );
                                      await widget.user
                                          .reauthenticateWithCredential(cred);
                                      await widget.user.updatePassword(newPass);
                                      setState(
                                        () => _info = 'Password updated',
                                      );
                                      _currentPasswordCtrl.clear();
                                      _newPasswordCtrl.clear();
                                      _confirmPasswordCtrl.clear();
                                    } on FirebaseAuthException catch (e) {
                                      setState(
                                        () => _error =
                                            e.message ??
                                            'Failed to update password',
                                      );
                                    } catch (e) {
                                      setState(
                                        () => _error =
                                            'Failed to update password',
                                      );
                                    }
                                  },
                                  child: const Text('Update Password'),
                                ),
                                const Divider(height: 32),
                                FilledButton.tonal(
                                  onPressed: () async {
                                    try {
                                      await AuthService.instance.signOut();
                                      // The auth state listener in main.dart will automatically
                                      // redirect to LoginPage when user becomes null
                                    } catch (e) {
                                      _showSnack(
                                        'Sign out failed: $e',
                                        error: true,
                                      );
                                    }
                                  },
                                  child: const Text('Sign Out'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await FirebaseAuth.instance.currentUser
                                          ?.reload();
                                      await FirebaseAuth.instance.currentUser
                                          ?.delete();
                                    } catch (_) {}
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.user.uid)
                                          .delete();
                                    } catch (_) {}
                                    if (mounted) Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete Account'),
                                ),
                                if (_info != null) ...[
                                  const SizedBox(height: 8),
                                  Text(_info!),
                                ],
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: null,
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
          onPressed: loading ? null : onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
