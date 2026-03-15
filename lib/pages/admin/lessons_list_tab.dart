import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../lesson_page.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/author_name_widget.dart';

class LessonsListTab extends StatefulWidget {
  final Function(Lesson)? onEdit;
  const LessonsListTab({super.key, this.onEdit});
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
              Text(
                'All Lessons',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

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
                      AppSearchBar(
                        hintText: 'Search lessons by title or author...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onFilterPressed: () {
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
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  ..._filterOptions.map((option) {
                                    return ListTile(
                                      title: Text(
                                        option,
                                        style: TextStyle(
                                          color: _selectedFilter == option
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
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
                                    title: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    onTap: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (lessons.isEmpty)
                        const Center(child: Text('No lessons found'))
                      else
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: lessons.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final l = lessons[index];
                            final currentUser =
                                AuthService.instance.currentUser;
                            final color = Theme.of(context).colorScheme.primary;
                            final isPending =
                                l.validationStatus == 'awaiting_approval';

                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  if (currentUser != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => LessonPage(
                                          user: currentUser,
                                          lesson: l,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 60,
                                        color: isPending ? Colors.teal : color,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              l.prompt,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              children: [
                                                if (l.attachmentName != null &&
                                                    l
                                                        .attachmentName!
                                                        .isNotEmpty)
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.attach_file,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        l.attachmentName!,
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                Text(
                                                  'Created: ${_formatTs(l.createdAt ?? Timestamp.now())} • ',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (l.isMembersOnly
                                                                ? Colors.amber
                                                                : Colors.blue)
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          (l.isMembersOnly
                                                                  ? Colors.amber
                                                                  : Colors.blue)
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    l.isMembersOnly
                                                        ? 'Members Only'
                                                        : 'Public',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                AuthorName(
                                                  uid: l.createdByUid,
                                                  fallbackEmail:
                                                      l.createdByEmail,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isPending) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(),
                                          ),
                                          child: const Text(
                                            'Waiting for approval',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      // Actions for Admins/Educators
                                      if (role == UserRole.admin ||
                                          role == UserRole.superadmin ||
                                          role == UserRole.educator)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              tooltip: 'Edit Lesson',
                                              onPressed: () =>
                                                  widget.onEdit?.call(l),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              tooltip: 'Delete Lesson',
                                              onPressed: () =>
                                                  _confirmDelete(context, l),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
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
