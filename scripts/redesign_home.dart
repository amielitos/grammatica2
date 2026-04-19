import 'dart:io';

void main() {
  final file = File('lib/pages/home_page.dart');
  final content = file.readAsStringSync();

  final startStr = '            return SingleChildScrollView(';
  final endStr = '  Widget _buildFolderCard(';

  final startIdx = content.indexOf(startStr);
  final rebuildFolderCardIdx = content.indexOf(endStr);
  final endClassIdx = content.lastIndexOf('}'); // file ends with `}`

  final firstReplacement = '''
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 64, top: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search lesson..',
                            hintStyle: const TextStyle(color: Colors.black87, fontSize: 16),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            suffixIcon: const Padding(
                              padding: EdgeInsets.only(right: 16.0),
                              child: Icon(Icons.search, color: Colors.black, size: 24),
                            ),
                          ),
                        ),
                      ),
                      
                      Wrap(
                        spacing: 48,
                        runSpacing: 48,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFolderCard(
                            context,
                            title: 'Grammatica',
                            description: 'Official Lessons',
                            iconColor: const Color(0xFFF3AF0D), // Exact Yellow mock
                            onTap: () {
                              setState(() {
                                _activeFolder = {
                                  'title': 'Grammatica Lessons',
                                  'pillLabel': 'From Grammatica',
                                  'lessons': grammaticaLessons,
                                };
                              });
                              widget.onFolderChanged?.call('Grammatica Lessons');
                            },
                          ),
                          _buildFolderCard(
                            context,
                            title: 'Public',
                            description: 'Community and Educators',
                            iconColor: const Color(0xFFDE372A), // Exact Red mock
                            onTap: () {
                              setState(() {
                                _activeFolder = {
                                  'title': 'Public Content',
                                  'pillLabel': 'Public',
                                  'lessons': publicLessons,
                                  'isPublicFolder': true,
                                };
                              });
                              widget.onFolderChanged?.call('Public');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

''';

  final buildFolderCard = '''
  Widget _buildFolderCard(
    BuildContext context, {
    required String title,
    required String description,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 320,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Icon(Icons.folder_rounded, size: 100, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Browse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
''';

  if (startIdx != -1 && rebuildFolderCardIdx != -1) {
    String newContent =
        content.substring(0, startIdx) + firstReplacement + buildFolderCard;
    file.writeAsStringSync(newContent);
    print('Replaced folder UI structure successfully');
  } else {
    print('Failed to find structure block limits');
  }
}
