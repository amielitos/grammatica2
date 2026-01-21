import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../../services/database_service.dart';
import '../../widgets/glass_card.dart';

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
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Lessons'),
              Tab(text: 'Quizzes'),
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
              ],
            ),
          ),
        ],
      ),
    );
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
            final createdBy = item.createdByEmail ?? 'Unknown';
            final createdAtStr = item.createdAt != null
                ? formatDate(item.createdAt!)
                : 'N/A';

            return GlassCard(
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
                          Text(
                            'By: $createdBy',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Submitted: $createdAtStr',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
