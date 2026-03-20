import 'dart:io';

void main() {
  final file = File('lib/pages/profile_page.dart');
  String content = file.readAsStringSync();

  // 1. Add BackgroundWrapper around SingleChildScrollView
  content = content.replaceFirst(
    'body: SingleChildScrollView(',
    'body: BackgroundWrapper(\n            child: SingleChildScrollView(',
  );
  
  // 2. Add closing bracket for BackgroundWrapper
  content = content.replaceFirst(
    '''                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJoinGrammaticaDialog''',
    '''                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJoinGrammaticaDialog'''
  ); // Wait, I need to add one more `),` before the `);` that closes Scaffold!
   // Actually, I can just find the end of the `return Scaffold` block.
   // Let's print out the content length before and after.
   
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

  final splitCode = '''                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [''';

  content = content.replaceFirst(
    "                                  const Divider(height: 48),\\n                                  const SizedBox(height: 16),\\n                                  TextField(\\n                                    controller: _currentPasswordCtrl,",
    "\$splitCode\\n                                  const SizedBox(height: 16),\\n                                  TextField(\\n                                    controller: _currentPasswordCtrl,"
  );

  content = content.replaceFirst(
    "                                  const Divider(height: 48),\\n                                  Column(\\n                                    crossAxisAlignment:\\n                                        CrossAxisAlignment.stretch,\\n                                    children: [\\n                                      Text(\\n                                        'Subscriptions',",
    "\$splitCode\\n                                  Column(\\n                                    crossAxisAlignment:\\n                                        CrossAxisAlignment.stretch,\\n                                    children: [\\n                                      Text(\\n                                        'Subscriptions',"
  );

  content = content.replaceFirst(
    "                                      const Divider(height: 48),\\n                                    ],\\n                                  ),\\n                                  if (roleSnap.data ==",
    "                                    ],\\n                                  ),\\n\$splitCode\\n                                  if (roleSnap.data =="
  );

  content = content.replaceFirst(
    "                                        const Divider(height: 48),\\n                                      ],\\n                                    ),\\n                                  ],\\n                                  Row(\\n                                    children: [\\n                                      Expanded(",
    "                                      ],\\n                                    ),\\n                                  ],\\n\$splitCode\\n                                  Row(\\n                                    children: [\\n                                      Expanded("
  );

  content = content.replaceFirst(
    "                                  const SizedBox(height: 40),\\n                                  Row(\\n                                    children: [\\n                                      Expanded(\\n                                        child: OutlinedButton(",
    "\$splitCode\\n                                  Row(\\n                                    children: [\\n                                      Expanded(\\n                                        child: OutlinedButton("
  );

  file.writeAsStringSync(content);
  print('Done applying profile fixes.');
}
