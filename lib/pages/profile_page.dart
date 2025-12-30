import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({super.key, required this.user});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null),
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
    final pwdCtrl = TextEditingController();
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
              setStateDialog(() { loading = true; errText = null; });
              try {
                final cred = EmailAuthProvider.credential(email: email, password: pwdCtrl.text);
                await widget.user.reauthenticateWithCredential(cred);
                if (!Navigator.of(context).mounted) return;
                Navigator.pop(context, pwdCtrl.text);
              } on FirebaseAuthException catch (e) {
                setStateDialog(() { loading = false; errText = e.message ?? 'Reauthentication failed'; });
              } catch (_) {
                setStateDialog(() { loading = false; errText = 'Reauthentication failed'; });
              }
            }
            return AlertDialog(
              title: const Text('Confirm Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: pwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                  if (errText != null) ...[
                    const SizedBox(height: 8),
                    Text(errText!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: CircularProgressIndicator()),
                ],
              ),
              actions: [
                TextButton(onPressed: loading ? null : () => Navigator.pop(context, null), child: const Text('Cancel')),
                FilledButton(onPressed: loading ? null : onConfirm, child: const Text('Confirm')),
              ],
            );
          },
        );
      },
    );
    if (password == null || password.isEmpty) return;

    try {
      await widget.user.updateDisplayName(newName);
      await RoleService.instance.updateUsername(uid: widget.user.uid, username: newName);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
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
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
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
              Text(_error!, style: const TextStyle(color: Colors.red)),
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
                  setState(() => _error = 'No email on account.');
                  return;
                }
                if (newPass != confirm) {
                  setState(() => _error = 'New passwords do not match.');
                  return;
                }
                if (newPass.length < 6) {
                  setState(
                    () => _error = 'Password must be at least 6 characters.',
                  );
                  return;
                }
                try {
                  final cred = EmailAuthProvider.credential(
                    email: email,
                    password: current,
                  );
                  await widget.user.reauthenticateWithCredential(cred);
                  await widget.user.updatePassword(newPass);
                  setState(() => _info = 'Password updated');
                  _currentPasswordCtrl.clear();
                  _newPasswordCtrl.clear();
                  _confirmPasswordCtrl.clear();
                } on FirebaseAuthException catch (e) {
                  setState(
                    () => _error = e.message ?? 'Failed to update password',
                  );
                } catch (e) {
                  setState(() => _error = 'Failed to update password');
                }
              },
              child: const Text('Update Password'),
            ),
            const Divider(height: 32),
            FilledButton.tonal(
              onPressed: () async {
                await AuthService.instance.signOut();
                _showSnack('Signed out');
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Sign Out'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.currentUser?.reload();
                  await FirebaseAuth.instance.currentUser?.delete();
                } catch (_) {}
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.user.uid)
                      .delete();
                } catch (_) {}
                if (mounted) Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Account'),
            ),
            if (_info != null) ...[const SizedBox(height: 8), Text(_info!)],
          ],
        ),
      ),
    );
  }
}
