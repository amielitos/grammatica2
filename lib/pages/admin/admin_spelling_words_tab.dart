import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../models/spelling_word.dart';
import '../../services/database_service.dart';
import '../../widgets/audio_player_widget.dart';

class AdminSpellingWordsTab extends StatefulWidget {
  const AdminSpellingWordsTab({super.key});

  @override
  State<AdminSpellingWordsTab> createState() => _AdminSpellingWordsTabState();
}

class _AdminSpellingWordsTabState extends State<AdminSpellingWordsTab> {
  SpellingDifficulty _filterDifficulty = SpellingDifficulty.novice;
  final AudioRecorder _recorder = AudioRecorder();

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddWordBottomSheet(
        recorder: _recorder,
        initialDifficulty: _filterDifficulty,
        onWordAdded: () {
          setState(() {});
        },
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
                          leading: sw.audioUrl != null
                              ? AudioPlayerWidget(
                                  url: sw.audioUrl!,
                                  activeColor: Colors.blue,
                                )
                              : const Icon(
                                  Icons.volume_off,
                                  color: Colors.grey,
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
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
                                    setState(() {}); // Refresh list
                                  }
                                },
                              ),
                            ],
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

class _AddWordBottomSheet extends StatefulWidget {
  final AudioRecorder recorder;
  final SpellingDifficulty initialDifficulty;
  final VoidCallback onWordAdded;

  const _AddWordBottomSheet({
    required this.recorder,
    required this.initialDifficulty,
    required this.onWordAdded,
  });

  @override
  State<_AddWordBottomSheet> createState() => _AddWordBottomSheetState();
}

class _AddWordBottomSheetState extends State<_AddWordBottomSheet> {
  final TextEditingController _wordController = TextEditingController();
  late SpellingDifficulty _difficulty;
  bool _isRecording = false;
  String? _audioPath;
  Uint8List? _audioBytes;
  bool _isUploading = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.initialDifficulty;
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // On web, record package might throw MissingPluginException for hasPermission
      // because browser handles this through start() or native APIs.
      bool hasPermission = true;
      if (!kIsWeb) {
        hasPermission = await widget.recorder.hasPermission();
      }

      if (hasPermission) {
        String? path;

        if (!kIsWeb) {
          try {
            final directory = await getTemporaryDirectory();
            path =
                '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
          } catch (e) {
            debugPrint('Failed to get temp directory: $e');
          }
        }

        // On web, we should NOT pass a path, even an empty one can sometimes cause issues
        // with the web implementation if it expects null for blob recording.
        if (kIsWeb) {
          await widget.recorder.start(const RecordConfig(), path: '');
        } else {
          await widget.recorder.start(const RecordConfig(), path: path ?? '');
        }

        setState(() {
          _isRecording = true;
          _audioPath = path;
          _recordingDuration = 0;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
          if (_recordingDuration >= 10) {
            _stopRecording();
          }
        });
      }
    } catch (e, stack) {
      debugPrint('Recording error: $e');
      debugPrint('Stack trace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording failed. Please check microphone permissions: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await widget.recorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPath = path;
        }
      });

      if (path != null) {
        if (kIsWeb) {
          // On web, we might need to fetch the blob
          try {
            final response = await web.window.fetch(path.toJS).toDart;
            final blob = await response.blob().toDart;
            final arrayBuffer = await blob.arrayBuffer().toDart;
            setState(() {
              _audioBytes = arrayBuffer.toDart.asUint8List();
            });
          } catch (e) {
            debugPrint('Web blob fetch error: $e');
          }
        } else {
          setState(() {
            _audioBytes = File(path).readAsBytesSync();
          });
        }
      }
    } catch (e, stack) {
      debugPrint('Stop recording error: $e');
      debugPrint('Stack trace: $stack');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav'],
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      if (file.size > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size exceeds 2MB limit.')),
          );
        }
        return;
      }
      setState(() {
        _audioBytes = file.bytes;
        _audioPath = null;
      });
    } else if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (await file.length() > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size exceeds 2MB limit.')),
          );
        }
        return;
      }
      setState(() {
        _audioBytes = file.readAsBytesSync();
        _audioPath = result.files.single.path;
      });
    }
  }

  Future<void> _saveWord() async {
    if (_wordController.text.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      String? audioUrl;
      if (_audioBytes != null) {
        // Determine extension
        String extension = 'mp3';
        if (_audioPath != null) {
          extension = _audioPath!.split('.').last;
        } else if (kIsWeb && _isRecording) {
          extension = 'm4a'; // Default for record_web
        }

        audioUrl = await DatabaseService.instance.uploadSpellingAudio(
          fileBytes: _audioBytes!,
          fileName: '${_wordController.text.trim().toLowerCase()}.$extension',
        );
      }

      await DatabaseService.instance.createSpellingWord(
        word: _wordController.text.trim(),
        difficulty: _difficulty,
        audioUrl: audioUrl,
      );

      widget.onWordAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving word: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save word: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Word',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _wordController,
              decoration: InputDecoration(
                labelText: 'Word',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.abc),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<SpellingDifficulty>(
              initialValue: _difficulty,
              decoration: InputDecoration(
                labelText: 'Difficulty',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.trending_up),
              ),
              items: SpellingDifficulty.values.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(
                    d.name.substring(0, 1).toUpperCase() + d.name.substring(1),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _difficulty = val);
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Audio Support (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording ? Colors.red : Colors.blue,
                    ),
                    label: Text(
                      _isRecording
                          ? 'Stop (${10 - _recordingDuration}s)'
                          : 'Record',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
            if (_audioBytes != null || _audioPath != null) ...[
              const SizedBox(height: 12),
              AudioPlayerWidget(
                bytes: _audioBytes,
                path: _audioPath,
                activeColor: Colors.green,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text('Audio ready'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() {
                      _audioBytes = null;
                      _audioPath = null;
                    }),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isUploading ? null : _saveWord,
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'SAVE WORD',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
