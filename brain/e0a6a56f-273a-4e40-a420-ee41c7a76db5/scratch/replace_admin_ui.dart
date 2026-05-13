import 'dart:io';

void main() {
  final files = [
    r'c:\Users\bea\Downloads\grammatica2\lib\pages\admin\admin_quizzes_tab.dart',
    r'c:\Users\bea\Downloads\grammatica2\lib\pages\admin\admin_assessments_tab.dart'
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();

    // Check GoogleFonts
    if (!content.contains('package:google_fonts/google_fonts.dart')) {
      content = content.replaceFirst("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:google_fonts/google_fonts.dart';");
    }

    // Replace `_buildInputFields`
    final regex = RegExp(r'  Widget _buildInputFields\(\) \{.*?\n  \}\n', multiLine: true, dotAll: true);
    
    final newBuildInputFields = r'''  Widget _buildInputFields() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Details',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2A2A2A)),
          ),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _title,
            label: 'Title',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 16),
          _buildStyledTextField(
            controller: _description,
            label: 'Description',
            icon: Icons.description_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStyledTextField(
                  controller: _durationCtrl,
                  label: 'Duration (HH:MM:SS)',
                  hint: '00:30:00',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMaxAttemptsCounter(),
              ),
            ],
          ),
          if (!widget.isEmbedded) ...[
            const SizedBox(height: 32),
            StreamBuilder<UserRole>(
              stream: RoleService.instance.roleStream(
                AuthService.instance.currentUser?.uid ?? '',
              ),
              builder: (context, roleSnap) {
                final isEducator = roleSnap.data == UserRole.educator;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visibility Options',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2A2A2A)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SegmentedButton<ContentVisibility>(
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.white,
                          selectedBackgroundColor: const Color(0xFF88B342).withValues(alpha: 0.1),
                          selectedForegroundColor: const Color(0xFF88B342),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        segments: [
                          const ButtonSegment(
                            value: ContentVisibility.public,
                            label: Text('Public'),
                            icon: Icon(Icons.public),
                          ),
                          const ButtonSegment(
                            value: ContentVisibility.membersOnly,
                            label: Text('Standard'),
                            icon: Icon(Icons.people_outline),
                          ),
                          const ButtonSegment(
                            value: ContentVisibility.certainUsers,
                            label: Text('Premium'),
                            icon: Icon(Icons.star_rounded),
                          ),
                        ],
                        selected: {_visibility},
                        onSelectionChanged: (Set<ContentVisibility> newSelection) {
                          setState(() {
                            _visibility = newSelection.first;
                            if (_visibility == ContentVisibility.public) {
                              _isVisible = true;
                              _isMembersOnly = false;
                            } else if (_visibility == ContentVisibility.membersOnly) {
                              _isVisible = true;
                              _isMembersOnly = true;
                            } else if (_visibility == ContentVisibility.certainUsers) {
                              _isVisible = false;
                              _isMembersOnly = false;
                            }
                          });
                        },
                      ),
                    ),
                    if (_visibility == ContentVisibility.certainUsers) ...[
                      const SizedBox(height: 16),
                      UserVisibilitySelector(
                        selectedUserIds: _visibleTo,
                        educatorUid: isEducator ? AuthService.instance.currentUser?.uid : null,
                        onChanged: (users) {
                          setState(() => _visibleTo = users);
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
          if (!widget.isEmbedded) ...[
            const SizedBox(height: 24),
            StreamBuilder<UserRole>(
              stream: RoleService.instance.roleStream(
                AuthService.instance.currentUser?.uid ?? '',
              ),
              builder: (context, snapshot) {
                final role = snapshot.data;
                if (role == UserRole.admin || role == UserRole.superadmin) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF88B342).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF88B342).withValues(alpha: 0.3)),
                    ),
                    child: CheckboxListTile(
                      title: Text('Official Grammatica Content', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF2A2A2A))),
                      subtitle: Text('This will appear in the official folders', style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
                      activeColor: const Color(0xFF88B342),
                      value: _isGrammaticaQuiz,
                      onChanged: (val) {
                        setState(() {
                          _isGrammaticaQuiz = val ?? false;
                          if (_isGrammaticaQuiz) {
                            _maxAttemptsCtrl.text = '1000000';
                          } else {
                            _maxAttemptsCtrl.text = '1';
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int minLines = 1,
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFF88B342)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF88B342), width: 2),
        ),
      ),
    );
  }

  Widget _buildMaxAttemptsCounter() {
    int currentVal = int.tryParse(_maxAttemptsCtrl.text) ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              'Max Attempts',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _isGrammaticaQuiz || currentVal <= 1
                    ? null
                    : () {
                        setState(() {
                          currentVal--;
                          _maxAttemptsCtrl.text = currentVal.toString();
                        });
                      },
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
              Expanded(
                child: TextField(
                  controller: _maxAttemptsCtrl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF88B342)),
                  keyboardType: TextInputType.number,
                  enabled: !_isGrammaticaQuiz,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      int parsed = int.tryParse(val) ?? 1;
                      if (parsed < 1) {
                         _maxAttemptsCtrl.text = '1';
                      }
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: _isGrammaticaQuiz
                    ? null
                    : () {
                        setState(() {
                          currentVal++;
                          _maxAttemptsCtrl.text = currentVal.toString();
                        });
                      },
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF88B342)),
              ),
            ],
          ),
        ],
      ),
    );
  }
''';

    content = content.replaceFirst(regex, newBuildInputFields);

    file.writeAsStringSync(content);
    print('Updated $path');
  }
}
