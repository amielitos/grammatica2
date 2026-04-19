import 'dart:io';

void main() {
  final file = File('lib/pages/profile_page.dart');
  final content = file.readAsStringSync();

  final startStr = '@override\n  Widget build(BuildContext context) {';
  final endStr = 'void _showJoinGrammaticaDialog(UserRole currentRole) {';

  final startIndex = content.indexOf(startStr);
  final endIndex = content.indexOf(endStr);

  if (startIndex != -1 && endIndex != -1) {
    print('Found markers!');
    final finalContent =
        content.substring(0, startIndex) +
        "/* REPLACED */\n  " +
        content.substring(endIndex);
    File('lib/pages/profile_page_temp.dart').writeAsStringSync(finalContent);
  } else {
    print('start: ' + startIndex.toString());
    print('end: ' + endIndex.toString());
  }
}
