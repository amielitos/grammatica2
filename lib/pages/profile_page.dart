import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';
import '../services/navigation.dart';
import '../services/database_service.dart';
import 'sign_in_page.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({super.key, required this.user});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _signingOut = false;
  final int _learnerTabIndex = 2; // default to Profile tab

  void _showSnack(String message, {bool error = false}) {
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
        bool loading = false;
        String? errText;
        final pwdCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> onConfirm() async {
              setStateDialog(() {
                loading = true;
                errText = null;
              });
              try {
                final cred = EmailAuthProvider.credential(
                  email: email,
                  password: pwdCtrl.text,
                );
                await widget.user.reauthenticateWithCredential(cred);
                if (!mounted) return;
                Navigator.pop(context, pwdCtrl.text);
              } on FirebaseAuthException catch (e) {
                setStateDialog(() {
                  loading = false;
                  errText = e.message ?? 'Reauthentication failed';
                });
              } catch (_) {
                setStateDialog(() {
                  loading = false;
                  errText = 'Reauthentication failed';
                });
              }
            }

            return AlertDialog(
              title: const Text('Confirm Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pwdCtrl,
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
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: loading ? null : onConfirm,
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
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

        return Stack(
          fit: StackFit.expand,
          children: [
            Scaffold(
              appBar: AppBar(title: const Text('Profile')),
              // No bottomNavigationBar here to avoid duplication; HomePage owns it via IndexedStack
              bottomNavigationBar: null,
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.user.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final data = snap.data?.data();
                        final username =
                            (data?['username'] as String?)?.trim() ??
                            widget.user.displayName ??
                            'User';
                        final email = widget.user.email ?? 'no-email';
                        final photoUrl =
                            (data?['photoUrl'] as String?) ??
                            widget.user.photoURL;
                        return Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage:
                                    (photoUrl != null && photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? const Icon(Icons.person, size: 40)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                username,
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                email,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    final pick = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: [
                                            'jpg',
                                            'jpeg',
                                            'png',
                                          ],
                                          withData: true,
                                        );
                                    if (pick == null || pick.files.isEmpty) {
                                      return;
                                    }
                                    final file = pick.files.first;
                                    final bytes = file.bytes;
                                    if (bytes == null) return;
                                    final ref = FirebaseStorage.instance.ref(
                                      'profile_pics/${widget.user.uid}.jpg',
                                    );
                                    await ref.putData(
                                      bytes,
                                      SettableMetadata(
                                        contentType: 'image/jpeg',
                                      ),
                                    );
                                    final url = await ref.getDownloadURL();
                                    await widget.user.updatePhotoURL(url);
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.user.uid)
                                        .set({
                                          'photoUrl': url,
                                        }, SetOptions(merge: true));
                                    if (!mounted) return;
                                    _showSnack('Profile photo updated');
                                    setState(() {});
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
                        );
                      },
                    ),
                    const Divider(height: 32),

                    // Editing controls (kept per request)
                    Align(
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
                                setState(() => _signingOut = true);
                                try {
                                  await AuthService.instance.signOut();
                                  _showSnack('Signed out');
                                } finally {
                                  if (!mounted) return;
                                  setState(() => _signingOut = false);
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  } else {
                                    rootNavigatorKey.currentState
                                        ?.pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (_) => const SignInPage(),
                                          ),
                                          (route) => false,
                                        );
                                  }
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
            if (_signingOut) ...[
              const ModalBarrier(dismissible: false, color: Colors.black26),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        );
      },
    );
  }
}
