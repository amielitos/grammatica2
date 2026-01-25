import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/spelling_word.dart';
import '../../services/database_service.dart';

class AdminSpellingWordsTab extends StatefulWidget {
  const AdminSpellingWordsTab({super.key});

  @override
  State<AdminSpellingWordsTab> createState() => _AdminSpellingWordsTabState();
}

class _AdminSpellingWordsTabState extends State<AdminSpellingWordsTab> {
  SpellingDifficulty _filterDifficulty = SpellingDifficulty.novice;

  Future<void> _seedInitialWords() async {
    final words = {
      SpellingDifficulty.novice: [
        'Apple',
        'Banana',
        'Cat',
        'Dog',
        'Elephant',
        'Fish',
        'Giraffe',
        'House',
        'Ice',
        'Jump',
      ],
      SpellingDifficulty.amateur: [
        'Beautiful',
        'Calendar',
        'Definitely',
        'Experience',
        'Furniture',
        'Government',
        'History',
        'Island',
        'Journey',
        'Knowledge',
      ],
      SpellingDifficulty.professional: [
        'Accommodate',
        'Conscientious',
        'Entrepreneur',
        'Fluorescence',
        'Hierarchy',
        'Indispensable',
        'Liaison',
        'Millennium',
        'Questionnaire',
        'Rhythm',
      ],
    };

    for (var entry in words.entries) {
      for (var word in entry.value) {
        await DatabaseService.instance.createSpellingWord(
          word: word,
          difficulty: entry.key,
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Words seeded successfully!')),
      );
      setState(() {});
    }
  }

  Future<void> _showDeleteAllConfirmation() async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete All Words?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await DatabaseService.instance.deleteAllSpellingWords();
      if (mounted) setState(() {});
    }
  }

  Future<void> _cleanupDuplicates() async {
    final count = await DatabaseService.instance
        .cleanupDuplicateSpellingWords();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleanup complete. Removed $count duplicates.')),
      );
      setState(() {});
    }
  }

  void _showAddWordDialog() {
    final wordController = TextEditingController();
    SpellingDifficulty selectedDifficulty = _filterDifficulty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Spelling Word'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordController,
                decoration: const InputDecoration(labelText: 'Word'),
              ),
              const SizedBox(height: 16),
              DropdownButton<SpellingDifficulty>(
                value: selectedDifficulty,
                isExpanded: true,
                items: SpellingDifficulty.values.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null)
                    setDialogState(() => selectedDifficulty = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (wordController.text.isNotEmpty) {
                  await DatabaseService.instance.createSpellingWord(
                    word: wordController.text.trim(),
                    difficulty: selectedDifficulty,
                  );
                  if (mounted) Navigator.pop(context);
                  setState(() {}); // Refresh list
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Bank Management'),
        actions: [
          TextButton.icon(
            onPressed: _seedInitialWords,
            icon: const Icon(Icons.auto_awesome, color: Colors.amber),
            label: const Text(
              'Seed Words',
              style: TextStyle(color: Colors.amber),
            ),
          ),
          TextButton.icon(
            onPressed: _showDeleteAllConfirmation,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton.icon(
            onPressed: _cleanupDuplicates,
            icon: const Icon(Icons.cleaning_services, color: Colors.blue),
            label: const Text('Cleanup', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWordDialog,
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: CupertinoSlidingSegmentedControl<SpellingDifficulty>(
                  groupValue: _filterDifficulty,
                  children: {
                    SpellingDifficulty.novice: const Text('Novice'),
                    SpellingDifficulty.amateur: const Text('Amateur'),
                    SpellingDifficulty.professional: const Text('Pro'),
                  },
                  onValueChanged: (val) {
                    if (val != null) setState(() => _filterDifficulty = val);
                  },
                ),
              ),
              Expanded(
                child: FutureBuilder<List<SpellingWord>>(
                  future: DatabaseService.instance.fetchSpellingWords(
                    difficulty: _filterDifficulty,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text('Error loading words: ${snapshot.error}'),
                        ),
                      );
                    }
                    final words = snapshot.data ?? [];
                    if (words.isEmpty) {
                      return const Center(child: Text('No words added yet.'));
                    }

                    return ListView.builder(
                      itemCount: words.length,
                      itemBuilder: (context, index) {
                        final sw = words[index];
                        return ListTile(
                          title: Text(
                            sw.word,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(sw.difficultyLabel),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Word?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (confirm) {
                                await DatabaseService.instance
                                    .deleteSpellingWord(sw.id);
                                setState(() {}); // Refresh
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
