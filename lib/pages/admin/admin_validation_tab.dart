import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/author_name_widget.dart';
import '../quiz_detail_page.dart';

import '../../widgets/application_preview_widgets.dart';

import '../lesson_page.dart';

import '../../services/role_service.dart';
import '../../services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_ornaments.dart';

class AdminValidationTab extends StatefulWidget {
  final UserRole role;
  final int initialTabIndex;
  const AdminValidationTab({
    super.key,
    required this.role,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminValidationTab> createState() => _AdminValidationTabState();
}

class _AdminValidationTabState extends State<AdminValidationTab> {
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

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.role == UserRole.superadmin;

    if (isSuperAdmin) {
      return _EducatorApplicationsList(
        formatDate: _formatTs,
        type: 'validator',
      );
    }

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex,
      child: BackgroundWrapper(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: TabBar(
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 16),
                tabs: const [
                  Tab(text: 'Lessons'),
                  Tab(text: 'Quizzes'),
                  Tab(text: 'Assessments'),
                  Tab(text: 'Educators'),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              children: [
                _ValidationList(
                  stream: DatabaseService.instance
                      .streamAwaitingApprovalLessons(),
                  collection: 'lessons',
                  formatDate: _formatTs,
                ),
                _ValidationList(
                  stream: DatabaseService.instance
                      .streamAwaitingApprovalQuizzes(),
                  collection: 'quizzes',
                  formatDate: _formatTs,
                ),
                _ValidationList(
                  stream: DatabaseService.instance
                      .streamAwaitingApprovalAssessments(),
                  collection: 'quizzes',
                  formatDate: _formatTs,
                ),
                _EducatorApplicationsList(
                  formatDate: _formatTs,
                  type: 'educator',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _EducatorApplicationsList extends StatelessWidget {
  final String Function(dynamic) formatDate;
  final String? type;

  const _EducatorApplicationsList({required this.formatDate, this.type});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EducatorApplication>>(
      stream: DatabaseService.instance.streamEducatorApplications(type: type),
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
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          final typeStr = type == 'validator' ? 'validator' : 'educator';
          return Center(child: Text('No $typeStr applications pending.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final app = items[index];
            final email = app.applicantEmail;
            final appliedAtStr = app.appliedAt != null
                ? formatDate(app.appliedAt!)
                : 'N/A';

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey.shade200,
                              child: const Icon(Icons.person, color: Colors.grey, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Applied: $appliedAtStr',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _approveApplication(context, app),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Color(0xFF81B655), size: 20),
                                    SizedBox(width: 8),
                                    Text("Approve", style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => _rejectApplication(context, app),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.highlight_off, color: Colors.redAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text("Reject", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  // Credentials section
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credentials Review:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50)),
                        ),
                        const SizedBox(height: 16),
                        // Professional Grid for Review
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 1.2,
                          children: [
                            _buildAdminReviewCard(context, "Curriculum Vitae", app.cvUrl, Icons.description, "cv.pdf"),
                            ...app.certificateUrls.asMap().entries.map(
                                  (e) => _buildAdminReviewCard(context, "Certificate ${e.key + 1}", e.value, Icons.verified, "certificate_${e.key + 1}.pdf")
                            ),
                            _buildAdminReviewCard(context, "Teaching Demo", app.videoUrl, Icons.videocam, "demo.mp4"),
                            _buildAdminReviewCard(context, "Syllabus", app.syllabusUrl, Icons.book, "syllabus.pdf"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminReviewCard(BuildContext context, String title, String url, IconData icon, String fileName) {
    if (url.isEmpty) return const SizedBox();
    
    // Extract extension from Firebase Storage URL (ignoring tokens)
    final bool isImage = ['jpg', 'jpeg', 'png'].contains(url.toLowerCase().split('?').first.split('.').last);
    final bool isVideo = ['mp4', 'mov', 'avi', 'webm', 'm4v'].contains(url.toLowerCase().split('?').first.split('.').last);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50)),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => showFilePreviewModal(context, url, fileName),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isImage)
                      Image.network(url, fit: BoxFit.cover)
                    else if (isVideo)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_fill, size: 48, color: Color(0xFF81B655)),
                            SizedBox(height: 8),
                            Text("Review Video", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text("Review PDF", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _approveApplication(
    BuildContext context,
    EducatorApplication app,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          app.applicationType == 'validator'
              ? 'Approve Validator'
              : 'Approve Educator',
        ),
        content: Text(
          'Are you sure you want to approve ${app.applicantEmail} as a ${app.applicationType}?',
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
          role: app.applicationType == 'validator'
              ? UserRole.validator
              : UserRole.educator,
        );
        // Update application status
        await DatabaseService.instance.updateApplicationStatus(
          app.id,
          'approved',
        );

        // Notify the applicant
        await NotificationService.instance.sendApprovalNotification(
          app.applicantUid,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${app.applicationType} approved successfully'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error approving ${app.applicationType}: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectApplication(
    BuildContext context,
    EducatorApplication app,
  ) async {
    final reasonController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please provide a reason for rejecting this application.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g., Incomplete documentation',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Provide more details...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseService.instance.rejectEducatorApplication(
          app,
          reason: reasonController.text,
          description: descController.text,
        );
        // Send notification to the user
        await NotificationService.instance.sendRejectionNotification(
          uid: app.applicantUid,
          reason: reasonController.text,
          description: descController.text,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application rejected and user notified'),
            ),
          );
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
  final String Function(dynamic) formatDate;

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
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No items awaiting approval.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final title = item.title;
            final createdAtStr = item.createdAt != null
                ? formatDate(item.createdAt!)
                : 'N/A';

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
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
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 200,
                        ),
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
                                Text(
                                  item.isMembersOnly
                                      ? 'Members Only'
                                      : 'Public',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.blue,
                            ),
                            tooltip: 'Review Content',
                            onPressed: () => _showReviewModal(context, item, collection),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            onPressed: () => _approve(context, item),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.highlight_off,
                              color: Colors.red,
                            ),
                            onPressed: () => _reject(context, item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showReviewModal(BuildContext context, dynamic item, String collection) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            Scaffold(
              body: collection == 'lessons'
                  ? LessonPage(user: user, lesson: item as Lesson, previewMode: true)
                  : QuizDetailPage(user: user, quiz: item as Quiz, previewMode: true),
              bottomNavigationBar: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _reject(context, item);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Deny Content'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _approve(context, item);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Approve Content'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, dynamic item) async {
    try {
      await DatabaseService.instance.updateContentStatus(
        collection,
        item.id,
        'approved',
      );
      
      // Notify the creator
      if (item.createdByUid != null && item.createdByUid!.isNotEmpty) {
        await NotificationService.instance.sendContentValidationNotification(
          uid: item.createdByUid!,
          title: item.title,
          approved: true,
        );
      } else {
        debugPrint('CANNOT NOTIFY: createdByUid is null for item ${item.id}');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved! Notification sent to creator (ID: ${item.createdByUid})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving/notifying: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context, dynamic item) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject (delete) this content?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deny & Notify Educator'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Notify before deleting (so we still have item data)
        if (item.createdByUid != null && item.createdByUid!.isNotEmpty) {
          await NotificationService.instance.sendContentValidationNotification(
            uid: item.createdByUid!,
            title: item.title,
            approved: false,
            reason: reasonController.text,
          );
        } else {
          debugPrint('CANNOT NOTIFY: createdByUid is null for item ${item.id}');
        }

        if (collection == 'lessons') {
          await DatabaseService.instance.deleteLesson(item.id);
        } else {
          await DatabaseService.instance.deleteQuiz(item.id);
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rejected! Notification sent to creator (ID: ${item.createdByUid})'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting/notifying: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
