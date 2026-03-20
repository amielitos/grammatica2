import 'dart:io';

void main() {
  final file = File('lib/pages/profile_page.dart');
  String content = file.readAsStringSync();

  content = content.replaceFirst(
    'body: SingleChildScrollView(',
    'body: BackgroundWrapper(\\n            child: SingleChildScrollView(',
  );
  
  // To close BackgroundWrapper, we insert `),` right before `);` that closes the Scaffold.
  // The Scaffold is closed like this:
  //                 ),
  //               );
  //             },
  //           );
  
  content = content.replaceFirst(
    '                  );\\n                },\\n              ),\\n            ),\\n          ),\\n        );\\n      },\\n    );\\n  }',
    '                    ),\\n                  );\\n                },\\n              ),\\n            ),\\n          ),\\n        );\\n      },\\n    );\\n  }'
  );
  
  // also add import if missing
  if (!content.contains('import \\'../widgets/design_ornaments.dart\\';')) {
      content = content.replaceFirst(
          'import \\'package:flutter/material.dart\\';',
          'import \\'package:flutter/material.dart\\';\\nimport \\'../widgets/design_ornaments.dart\\';'
      );
  }

  file.writeAsStringSync(content);
  print('Done adding BackgroundWrapper.');
}
