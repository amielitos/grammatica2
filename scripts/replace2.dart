import 'dart:io';

void main() {
  final file = File('lib/pages/profile_page.dart');
  final content = file.readAsStringSync();

  final startStr = 'Widget build(BuildContext context) {';
  final endStr = 'void _showJoinGrammaticaDialog(UserRole currentRole) {';

  final startIndex = content.indexOf(startStr);
  final endIndex = content.indexOf(endStr);

  if (startIndex != -1 && endIndex != -1) {
    print('Found markers!');
    // Rewind back to @override
    final overrideIndex = content.lastIndexOf('@override', startIndex);
    final realStart = overrideIndex != -1 ? overrideIndex : startIndex;

    // Also rewind endStr a bit if needed, but endStr starts without spaces here.
    final realEnd = content.lastIndexOf('  ', endIndex); // Find the indent

    final newBuild = '''
  InputDecoration _customInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5))],
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
                color: Colors.black.withOpacity(0.05),
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
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Profile',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              _photoUrl!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey.shade600, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        onPressed: () async {
                          try {
                            final pick = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png'], withData: true);
                            if (pick == null || pick.files.isEmpty) return;
                            final file = pick.files.first;
                            final bytes = file.bytes;
                            if (bytes == null) return;
                            if (bytes.lengthInBytes > 2097152) {
                              _showSnack('Image exceeds 2MB limit', error: true);
                              return;
                            }
                            final ext = file.name.toLowerCase().split('.').last;
                            final path = 'users/\${widget.user.uid}/profile_pic.\$ext';
                            final ref = FirebaseStorage.instance.ref().child(path);
                            await ref.putData(bytes, SettableMetadata(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
                            final url = await ref.getDownloadURL();
                            await widget.user.updatePhotoURL(url);
                            await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({'photoUrl': url}, SetOptions(merge: true));
                            if (mounted) {
                              setState(() => _photoUrl = url);
                              _showSnack('Profile photo updated');
                            }
                          } catch (e) {
                            _showSnack('Photo update failed: \$e', error: true);
                          }
                        },
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
                    Text(_displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 4),
                    Text(_displayEmail, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          
          if (_phoneNumber == null || _phoneNumber!.isEmpty || _dob == null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profile Incomplete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                  const SizedBox(height: 8),
                  const Text('Add phone number and date of birth to unlock all features.', style: TextStyle(color: Colors.brown)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          Text('Edit Profile', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: _customInputDecoration(hint: 'New Username'),
          ),
          const SizedBox(height: 16),
          _buildGreenButton('Update Username', _updateUsername),
          
          const SizedBox(height: 24),
          TextField(
            controller: _bioCtrl,
            maxLength: 300,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: _customInputDecoration(hint: 'Bio'),
          ),
          const SizedBox(height: 8),
          _buildGreenButton('Update Bio', _updateBio),
          
          const SizedBox(height: 24),
          IntlPhoneField(
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            initialCountryCode: 'PH',
            decoration: _customInputDecoration(hint: 'Phone Number'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            onChanged: (phone) => _completePhoneNumber = phone.completeNumber,
          ),
          const SizedBox(height: 8),
          _buildGreenButton('Update Phone Number', _updatePhone),
          
          const SizedBox(height: 24),
          InkWell(
            onTap: _updateDob,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: _customInputDecoration(hint: '').copyWith(
                hintText: _dob != null ? '\${_dob!.toDate().day}/\${_dob!.toDate().month}/\${_dob!.toDate().year}' : 'Select Date of Birth',
              ),
              child: Text(
                _dob != null ? '\${_dob!.toDate().day}/\${_dob!.toDate().month}/\${_dob!.toDate().year}' : 'Select Date of Birth',
                style: TextStyle(fontSize: 14, color: _dob != null ? Colors.black : Colors.black54),
              ),
            ),
          ),
        ],
      ),
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
              Text('Change Password', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
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

        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subscription', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 24),
              _buildGreenButton('Manage Subscription', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ManageSubscriptionsPage(user: widget.user)));
              }),
            ],
          ),
        ),

        if (role == UserRole.learner || role == UserRole.educator || role == UserRole.validator)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Educator Role', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 24),
                StreamBuilder<EducatorApplication?>(
                  stream: DatabaseService.instance.streamUserApplication(widget.user.uid),
                  builder: (context, appSnap) {
                    if (appSnap.hasError) return Text('Error: \${appSnap.error}', style: TextStyle(color: Colors.red));
                    final application = appSnap.data;
                    if (application != null && (application.status == 'pending' || application.status == 'rejected')) {
                      return _buildGreenButton(
                        'View Application Status',
                        () => _showApplicationStatusDialog(application),
                      );
                    }
                    return _buildGreenButton(
                      'Apply as an Educator',
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
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 2), // Exact mockup thickness
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
                        _showSnack('Delete failed: \$e', error: true);
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
                    constraints: const BoxConstraints(maxWidth: 1000),
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
''';

    final finalContent =
        content.substring(0, realStart) +
        newBuild +
        content.substring(endIndex);
    file.writeAsStringSync(finalContent);
    print('Updated Profile layout completely.');
  } else {
    print('Found markers failed');
  }
}
