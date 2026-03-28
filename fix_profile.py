import sys
import re

def main():
    path = "lib/pages/profile_page.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Add BackgroundWrapper around SingleChildScrollView
    content = content.replace(
        "body: SingleChildScrollView(",
        "body: BackgroundWrapper(\n            child: SingleChildScrollView("
    )
    
    # We need to add an extra ");" to close the BackgroundWrapper at the end of Scaffold.
    # The Scaffold ends roughly at the "return Scaffold(...);"
    # It is right before:
    #   void _showJoinGrammaticaDialog(UserRole currentRole) {
    # Let's find the closing of the main build method:
    
    target_end = """                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJoinGrammaticaDialog"""
    
    replacement_end = """                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJoinGrammaticaDialog"""
    # Wait, the BackgroundWrapper needs to be closed. Let's see how many `),` or `);` there are.
    # We added `BackgroundWrapper( child: SingleChildScrollView( ...`
    # The original was:
    # Scaffold(
    #   body: SingleChildScrollView(
    #     child: Center(
    #       child: ConstrainedBox(
    #         child: Card(...) )))
    # So `SingleChildScrollView` is closed with `),`.
    # `BackgroundWrapper` takes `child: Widget`, so it needs `),` too.
    # Let's do it using regex: replace the closing of SingleChildScrollView.
    # Actually, easier: just find the matching parenthesis of BackgroundWrapper.
    
    
    # 2. Split cards at dividers.
    
    # Divider 1: before App Theme.
    # Actually, we can just replace the dividers with the split code!
    # The split code is:
    split_code = '''                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: ['''
    
    # The dividers to replace:
    
    # 1. Password
    content = content.replace(
        "                                  const Divider(height: 48),\n                                  const SizedBox(height: 16),\n                                  TextField(\n                                    controller: _currentPasswordCtrl,",
        split_code + "\n                                  const SizedBox(height: 16),\n                                  TextField(\n                                    controller: _currentPasswordCtrl,"
    )
    
    # 2. Subscriptions
    content = content.replace(
        "                                  const Divider(height: 48),\n                                  Column(\n                                    crossAxisAlignment:\n                                        CrossAxisAlignment.stretch,\n                                    children: [\n                                      Text(\n                                        'Subscriptions',",
        split_code + "\n                                  Column(\n                                    crossAxisAlignment:\n                                        CrossAxisAlignment.stretch,\n                                    children: [\n                                      Text(\n                                        'Subscriptions',"
    )
    
    # 3. Join Grammatica (After Subscriptions)
    content = content.replace(
        "                                      const Divider(height: 48),\n                                    ],\n                                  ),\n                                  if (roleSnap.data ==",
        "                                    ],\n                                  ),\n" + split_code + "\n                                  if (roleSnap.data =="
    )
    
    # 4. App Theme (After Join Grammatica)
    content = content.replace(
        "                                        const Divider(height: 48),\n                                      ],\n                                    ),\n                                  ],\n                                  Row(\n                                    children: [\n                                      Expanded(",
        "                                      ],\n                                    ),\n                                  ],\n" + split_code + "\n                                  Row(\n                                    children: [\n                                      Expanded("
    )
    
    # 5. Sign Out
    content = content.replace(
        "                                  const SizedBox(height: 40),\n                                  Row(\n                                    children: [\n                                      Expanded(\n                                        child: OutlinedButton(",
        split_code + "\n                                  Row(\n                                    children: [\n                                      Expanded(\n                                        child: OutlinedButton("
    )
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
