import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../lesson_page.dart';


class LessonsListTab extends StatefulWidget {
  final Function(Lesson)? onEdit;
  final Function(Lesson)? onEditQuiz;
  const LessonsListTab({super.key, this.onEdit, this.onEditQuiz});
  @override
  State<LessonsListTab> createState() => _LessonsListTabState();
}

class _LessonsListTabState extends State<LessonsListTab> {
  String _formatTs(dynamic ts) {
    if (ts == null) return 'N/A';
    DateTime d;
    if (ts is Timestamp) {
      d = ts.toDate().toLocal();
    } else if (ts is DateTime) {
      d = ts.toLocal();
    } else {
      return 'N/A';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _searchQuery = '';
  String _selectedFilter = 'Status'; // Default
  final List<String> _filterOptions = ['Name', 'Status', 'Create Date'];

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return StreamBuilder<UserRole>(
      stream: user != null ? RoleService.instance.roleStream(user.uid) : null,
      builder: (context, roleSnap) {
        final role = roleSnap.data ?? UserRole.learner;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // List of Lessons
              StreamBuilder<List<Lesson>>(
                stream: DatabaseService.instance.streamLessons(
                  approvedOnly: false,
                  userRole: role,
                  userId: user?.uid,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var lessons = snapshot.data!.toList();
                  
                  // Educators should only see and manage their own lessons
                  if (role == UserRole.educator && user != null) {
                    lessons = lessons.where((l) => l.createdByUid == user.uid).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    lessons = lessons.where((l) {
                      final title = l.title.toLowerCase();
                      final author = (l.createdByEmail ?? 'Unknown')
                          .toLowerCase();
                      return title.contains(query) || author.contains(query);
                    }).toList();
                  }

                  // Apply sorting based on filter
                  lessons.sort((a, b) {
                    int cmp = 0;
                    if (_selectedFilter == 'Name') {
                      cmp = a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      );
                    } else if (_selectedFilter == 'Status') {
                      if (a.validationStatus == 'awaiting_approval' &&
                          b.validationStatus != 'awaiting_approval') {
                        cmp = -1;
                      } else if (a.validationStatus != 'awaiting_approval' &&
                          b.validationStatus == 'awaiting_approval') {
                        cmp = 1;
                      } else {
                        cmp = 0;
                      }
                    } else if (_selectedFilter == 'Create Date') {
                      final tsA = a.createdAt;
                      final tsB = b.createdAt;
                      if (tsA == null && tsB == null) {
                        cmp = 0;
                      } else if (tsA == null) {
                        cmp = 1;
                      } else if (tsB == null) {
                        cmp = -1;
                      } else {
                        cmp = tsB.compareTo(tsA);
                      }
                    }

                    if (cmp == 0) {
                      return a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      );
                    }
                    return cmp;
                  });

                  return Column(
                    children: [
                      // Search Bar styled to match mock up
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.tune, color: Colors.grey),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            'Filter Lessons By',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                        ..._filterOptions.map((option) {
                                          return ListTile(
                                            title: Text(
                                              option,
                                              style: TextStyle(
                                                color: _selectedFilter == option
                                                    ? Theme.of(context).colorScheme.primary
                                                    : null,
                                                fontWeight: _selectedFilter == option
                                                    ? FontWeight.bold
                                                    : null,
                                              ),
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedFilter = option;
                                              });
                                              Navigator.pop(context);
                                            },
                                          );
                                        }),
                                        const Divider(),
                                        ListTile(
                                          title: const Text('Cancel', style: TextStyle(color: Colors.red)),
                                          onTap: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Expanded(
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Search lesson by title or author..',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                            const Icon(Icons.search, color: Colors.grey),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (lessons.isEmpty)
                        const Center(child: Text('No lessons found'))
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 700;
                            return GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWide ? 2 : 1,
                                childAspectRatio: isWide ? 2.3 : 1.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: lessons.length,
                              itemBuilder: (context, index) {
                                final l = lessons[index];
                                final currentUser = AuthService.instance.currentUser;
                                final isPending = l.validationStatus == 'awaiting_approval';
                                final isDark = Theme.of(context).brightness == Brightness.dark;

                                return InkWell(
                                  onTap: () {
                                    if (currentUser != null) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => LessonPage(user: currentUser, lesson: l),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF333333) : Colors.white,
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Title + Status + Action Buttons
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                l.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (isPending ? Colors.orange : (l.isMembersOnly ? Colors.amber : Colors.blue)).withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: (isPending ? Colors.orange : (l.isMembersOnly ? Colors.amber : Colors.blue)).withValues(alpha: 0.6),
                                                ),
                                              ),
                                              child: Text(
                                                isPending ? 'Pending' : (l.isMembersOnly ? 'Members Only' : 'Public'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            if (role == UserRole.admin || role == UserRole.superadmin || role == UserRole.educator) ...[
                                              if (l.quizId != null) ...[
                                                GestureDetector(
                                                  onTap: () => widget.onEditQuiz?.call(l),
                                                  child: const Icon(Icons.quiz, size: 20, color: Colors.blueGrey),
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              GestureDetector(
                                                onTap: () => widget.onEdit?.call(l),
                                                child: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                              ),
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () => _confirmDelete(context, l),
                                                child: const Icon(Icons.delete, size: 20, color: Colors.red),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Header 2 & 3 (Subtitles/Prompt preview)
                                        Text(
                                          l.prompt,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const Spacer(),
                                        // Bottom Row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'By: ${l.createdByEmail ?? 'Unknown'}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              'Date Created: ${_formatTs(l.createdAt ?? Timestamp.now())}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Lesson lesson) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson?'),
        content: Text(
          'Are you sure you want to delete "${lesson.title}" and its integrated quiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await DatabaseService.instance.deleteLesson(lesson.id);
        if (lesson.quizId != null) {
          await DatabaseService.instance.deleteQuiz(lesson.quizId!);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson and Quiz deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
