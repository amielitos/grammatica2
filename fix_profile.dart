import 'dart:io';

void main() {
  final file = File('lib/pages/profile_page.dart');
  if (!file.existsSync()) return;
  String content = file.readAsStringSync();

  // 1. Add BackgroundWrapper around SingleChildScrollView
  content = content.replaceFirst(
    'body: SingleChildScrollView(',
    'body: BackgroundWrapper(\n            child: SingleChildScrollView(',
  );
  
  final scaffoldEnd = '''                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }''';
  
  final scaffoldEndReplace = '''                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }''';
  
  content = content.replaceFirst(scaffoldEnd, scaffoldEndReplace);

  file.writeAsStringSync(content);
}
