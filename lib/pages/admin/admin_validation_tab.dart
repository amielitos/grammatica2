import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../../services/database_service.dart';
import '../../widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../widgets/author_name_widget.dart';
import '../quiz_detail_page.dart';
import '../lesson_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/role_service.dart';

class AdminValidationTab extends StatefulWidget {
  const AdminValidationTab({super.key});

  @override
  State<AdminValidationTab> createState() => _AdminValidationTabState();
}

class _AdminValidationTabState extends State<AdminValidationTab> {
  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Lessons'),
              Tab(text: 'Quizzes'),
              Tab(text: 'Educators'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ValidationList(
                  stream: DatabaseService.instance
                      .streamAwaitingApprovalLessons(),
                  collection: 'lessons',
                  formatDate: _fmt,
                ),
                _ValidationList(
                  stream: DatabaseService.instance
                      .streamAwaitingApprovalQuizzes(),
                  collection: 'quizzes',
                  formatDate: _fmt,
                ),
                _EducatorApplicationsList(formatDate: _fmt),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EducatorApplicationsList extends StatelessWidget {
  final String Function(Timestamp) formatDate;

  const _EducatorApplicationsList({required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EducatorApplication>>(
      stream: DatabaseService.instance.streamEducatorApplications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading applications: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No educator applications pending.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final app = items[index];
            final email = app.applicantEmail;
            final appliedAtStr = app.appliedAt != null
                ? formatDate(app.appliedAt!)
                : 'N/A';

            return GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_crop_circle_fill,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Applied: $appliedAtStr',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                CupertinoIcons.checkmark_circle,
                                color: Colors.green,
                              ),
                              onPressed: () =>
                                  _approveApplication(context, app),
                            ),
                            IconButton(
                              icon: const Icon(
                                CupertinoIcons.xmark_circle,
                                color: Colors.red,
                              ),
                              onPressed: () => _rejectApplication(context, app),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Credentials:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _launchURL(app.videoUrl),
                          icon: const Icon(CupertinoIcons.play_circle),
                          label: const Text('View Video Demo'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            foregroundColor: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _launchURL(app.syllabusUrl),
                          icon: const Icon(CupertinoIcons.doc_text),
                          label: const Text('View Syllabus'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            foregroundColor: Colors.orange,
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
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _approveApplication(
    BuildContext context,
    EducatorApplication app,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Educator'),
        content: Text(
          'Are you sure you want to approve ${app.applicantEmail} as an educator?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Update user role
        await RoleService.instance.setUserRole(
          uid: app.applicantUid,
          role: UserRole.educator,
        );
        // Update application status
        await DatabaseService.instance.updateApplicationStatus(
          app.id,
          'approved',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Educator approved successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error approving educator: $e')),
          );
        }
      }
    }
  }

  Future<void> _rejectApplication(
    BuildContext context,
    EducatorApplication app,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: const Text(
          'Are you sure you want to reject this educator application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseService.instance.rejectEducatorApplication(app);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Application rejected')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting application: $e')),
          );
        }
      }
    }
  }
}

class _ValidationList extends StatelessWidget {
  final Stream<List<dynamic>> stream;
  final String collection;
  final String Function(Timestamp) formatDate;

  const _ValidationList({
    required this.stream,
    required this.collection,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading items: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No items awaiting approval.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final title = item.title;
            final createdAtStr = item.createdAt != null
                ? formatDate(item.createdAt!)
                : 'N/A';

            return GlassCard(
              onTap: () {
                final user = AuthService.instance.currentUser;
                if (user == null) return;

                if (collection == 'lessons') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonPage(
                        user: user,
                        lesson: item as Lesson,
                        previewMode: true,
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizDetailPage(
                        user: user,
                        quiz: item as Quiz,
                        previewMode: true,
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AuthorName(
                            uid: item.createdByUid,
                            fallbackEmail: item.createdByEmail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (item.isMembersOnly
                                              ? Colors.amber
                                              : Colors.blue)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        (item.isMembersOnly
                                                ? Colors.amber
                                                : Colors.blue)
                                            .withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  item.isMembersOnly
                                      ? 'Members Only'
                                      : 'Public',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.isMembersOnly
                                        ? Colors.amber.shade900
                                        : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted: $createdAtStr',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.eye, color: Colors.blue),
                      tooltip: 'Preview',
                      onPressed: () {
                        final user = AuthService.instance.currentUser;
                        if (user == null) return;

                        if (collection == 'lessons') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LessonPage(
                                user: user,
                                lesson: item as Lesson,
                                previewMode: true,
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuizDetailPage(
                                user: user,
                                quiz: item as Quiz,
                                previewMode: true,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.checkmark_circle,
                        color: Colors.green,
                      ),
                      onPressed: () => _approve(context, item.id),
                    ),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.xmark_circle,
                        color: Colors.red,
                      ),
                      onPressed: () => _reject(context, item.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, String id) async {
    try {
      await DatabaseService.instance.updateContentStatus(
        collection,
        id,
        'approved',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Approved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Content'),
        content: const Text(
          'Are you sure you want to reject (delete) this content?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (collection == 'lessons') {
          await DatabaseService.instance.deleteLesson(id);
        } else {
          await DatabaseService.instance.deleteQuiz(id);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Rejected and Deleted')));
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
