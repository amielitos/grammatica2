import 'dart:io';

void main() {
  final file = File('lib/pages/profile_page.dart');
  if (!file.existsSync()) return;
  final content = file.readAsStringSync();

  final startStr = '@override\n  Widget build(BuildContext context) {';
  final endStr = '  void _showJoinGrammaticaDialog(UserRole currentRole) {';

  final startIndex = content.indexOf(startStr);
  final endIndex = content.indexOf(endStr);

  if (startIndex != -1 && endIndex != -1) {
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
          backgroundColor: const Color(0xFF81B655),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
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

  @override
  Widget build(BuildContext context) {
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
                  ? const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left
                        // Right
                      ],
                    )
                  : const Column(
                      children: [
                        // UI
                      ],
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
  $endStr''';
    
    final finalContent = '${content.substring(0, startIndex)}$newBuild${content.substring(endIndex + endStr.length)}';
    file.writeAsStringSync(finalContent);
    stdout.writeln('Successfully modified layout!');
  } else {
    stdout.writeln('Failed to find markers.');
    stdout.writeln('Found Start: ${startIndex != -1}');
    stdout.writeln('Found End: ${endIndex != -1}');
  }
}
