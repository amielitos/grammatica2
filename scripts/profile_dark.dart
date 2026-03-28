import 'dart:io';

void main() {
  final file = File('lib/pages/profile_page.dart');
  String content = file.readAsStringSync();

  // 1. Update _customInputDecoration
  final oldInputDec = '''  InputDecoration _customInputDecoration({required String hint}) {
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
  }''';

  final newInputDec = '''  InputDecoration _customInputDecoration({required String hint}) {
    // Inputs remain white even in dark mode based on the mock-up
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF81B655), width: 2),
      ),
    );
  }''';

  content = content.replaceAll(oldInputDec, newInputDec);

  // 2. Update _buildCard
  final oldCard = '''  Widget _buildCard({required Widget child}) {
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
  }''';

  final newCard = '''  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }''';

  content = content.replaceAll(oldCard, newCard);

  // 3. Update texts in _buildLeftColumn
  content = content.replaceAll(
    "Text(\n              'Profile',\n              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),\n            )",
    "Text(\n              'Profile',\n              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),\n            )"
  );
  
  content = content.replaceAll(
    "Text(_displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black))",
    "Text(_displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))"
  );

  content = content.replaceAll(
    "Text('Edit Profile', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))",
    "Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))"
  );
  
  // Update texts in _buildRightColumn
  content = content.replaceAll(
    "Text('Change Password', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black))",
    "Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))"
  );
  
  content = content.replaceAll(
    "Text('Subscription', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))",
    "Text('Subscription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))"
  );

  content = content.replaceAll(
    "Text('Educator Role', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))",
    "Text('Educator Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))"
  );

  final oldOutlinedBtn = '''                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 2), // Exact mockup thickness
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),''';
  final newOutlinedBtn = '''                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333333) : Colors.white,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.black, width: Theme.of(context).brightness == Brightness.dark ? 0 : 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),''';
  content = content.replaceAll(oldOutlinedBtn, newOutlinedBtn);

  file.writeAsStringSync(content);
}
