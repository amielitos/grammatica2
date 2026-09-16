import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/author_name_widget.dart';
import '../quiz_detail_page.dart';
import '../../services/navigation_service.dart';

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
      length: 5,
      initialIndex: widget.initialTabIndex,
      child: BackgroundWrapper(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 15),
                tabs: const [
                  Tab(text: 'Lessons'),
                  Tab(text: 'Quizzes'),
                  Tab(text: 'Assessments'),
                  Tab(text: 'Applications'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block_rounded, size: 14, color: Color(0xFFE05050)),
                        SizedBox(width: 6),
                        Text('Rejected'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ── Pending ──────────────────────────────────────────────
                  _ValidationList(
                    stream: DatabaseService.instance.streamAwaitingApprovalLessons(),
                    collection: 'lessons',
                    formatDate: _formatTs,
                  ),
                  _ValidationList(
                    stream: DatabaseService.instance.streamAwaitingApprovalQuizzes(),
                    collection: 'quizzes',
                    formatDate: _formatTs,
                  ),
                  _ValidationList(
                    stream: DatabaseService.instance.streamAwaitingApprovalAssessments(),
                    collection: 'quizzes',
                    formatDate: _formatTs,
                  ),
                  _EducatorApplicationsList(
                    formatDate: _formatTs,
                    type: 'educator',
                    showRejected: false,
                  ),
                  // ── All Rejected ──────────────────────────────────────────
                  _AllRejectedTab(formatDate: _formatTs),
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
  final bool showRejected;

  const _EducatorApplicationsList({
    required this.formatDate,
    this.type,
    this.showRejected = false,
  });

  @override
  Widget build(BuildContext context) {
    final stream = showRejected
        ? DatabaseService.instance.streamRejectedApplications()
        : DatabaseService.instance.streamEducatorApplications(type: type);

    return StreamBuilder<List<EducatorApplication>>(
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
          final msg = showRejected
              ? 'No rejected $typeStr applications.'
              : 'No $typeStr applications pending.';
          return Center(child: Text(msg));
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
                  // ── Credentials section with thumbnails ─────────────
                  if (!showRejected) ...[  
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CREDENTIALS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (app.cvUrl.isNotEmpty)
                                  _ValidationCredentialThumb(
                                    label: 'CV / Résumé',
                                    url: app.cvUrl,
                                    fallbackIcon: Icons.description_rounded,
                                  ),
                                ...app.certificateUrls.asMap().entries.where((e) => e.value.isNotEmpty).map(
                                  (e) => _ValidationCredentialThumb(
                                    label: 'Certificate ${e.key + 1}',
                                    url: e.value,
                                    fallbackIcon: Icons.verified_rounded,
                                  ),
                                ),
                                if (app.videoUrl.isNotEmpty)
                                  _ValidationCredentialThumb(
                                    label: 'Teaching Demo',
                                    url: app.videoUrl,
                                    fallbackIcon: Icons.videocam_rounded,
                                  ),
                                if (app.syllabusUrl.isNotEmpty)
                                  _ValidationCredentialThumb(
                                    label: 'Syllabus',
                                    url: app.syllabusUrl,
                                    fallbackIcon: Icons.book_rounded,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[  
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 15, color: Colors.orange.shade400),
                          const SizedBox(width: 8),
                          Text(
                            'Credential files were removed after rejection.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
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
                  if (collection == 'lessons') {
                    NavigationService.instance.goToLesson(
                      context,
                      item as Lesson,
                      previewMode: true,
                    );
                  } else {
                    NavigationService.instance.goToQuiz(
                      context,
                      item as Quiz,
                      previewMode: true,
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isReasonEmpty = reasonController.text.trim().isEmpty;
            return AlertDialog(
              title: const Text('Reject Content'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Are you sure you want to reject (delete) this content?'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason for rejection (Required)',
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
                  onPressed: isReasonEmpty ? null : () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Deny & Notify Educator'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      try {
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

        // Mark as rejected — preserves content for audit trail
        await DatabaseService.instance.updateContentStatus(
          collection,
          item.id,
          'rejected',
          rejectionReason: reasonController.text.trim(),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content rejected. Educator has been notified.'),
              backgroundColor: Color(0xFFE05050),
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

// ═══════════════════════════════════════════════════════
//  _AllRejectedTab — unified view of ALL rejected content with reasons
// ═══════════════════════════════════════════════════════
class _AllRejectedTab extends StatelessWidget {
  final String Function(dynamic) formatDate;
  const _AllRejectedTab({required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamRejectedLessons(),
      builder: (ctx, lessonSnap) {
        return StreamBuilder<List<Quiz>>(
          stream: DatabaseService.instance.streamRejectedQuizzes(),
          builder: (ctx, quizSnap) {
            return StreamBuilder<List<Quiz>>(
              stream: DatabaseService.instance.streamRejectedAssessments(),
              builder: (ctx, assessSnap) {
                return StreamBuilder<List<EducatorApplication>>(
                  stream: DatabaseService.instance.streamRejectedApplications(),
                  builder: (ctx, appSnap) {
                    if (lessonSnap.connectionState == ConnectionState.waiting ||
                        quizSnap.connectionState == ConnectionState.waiting ||
                        assessSnap.connectionState == ConnectionState.waiting ||
                        appSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final lessons = lessonSnap.data ?? [];
                    final quizzes = quizSnap.data ?? [];
                    final assessments = assessSnap.data ?? [];
                    final applications = appSnap.data ?? [];

                    final bool isEmpty = lessons.isEmpty && quizzes.isEmpty &&
                        assessments.isEmpty && applications.isEmpty;

                    if (isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_circle_rounded, size: 56, color: Colors.green.shade400),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Rejected Content',
                              style: GoogleFonts.outfit(
                                fontSize: 22, fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All submitted content is clean.',
                              style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (lessons.isNotEmpty) ..._buildSection(
                          context, 'Lessons', Icons.auto_stories_rounded,
                          lessons.map((l) => _RejectedItem(
                            title: l.title,
                            subtitle: 'Lesson',
                            icon: Icons.description_rounded,
                            reason: l.rejectionReason,
                            createdAtStr: l.createdAt != null ? formatDate(l.createdAt!) : 'N/A',
                            createdByUid: l.createdByUid,
                            createdByEmail: l.createdByEmail,
                          )).toList(),
                        ),
                        if (quizzes.isNotEmpty) ..._buildSection(
                          context, 'Quizzes', Icons.quiz_rounded,
                          quizzes.map((q) => _RejectedItem(
                            title: q.title,
                            subtitle: 'Quiz',
                            icon: Icons.quiz_rounded,
                            reason: q.rejectionReason,
                            createdAtStr: q.createdAt != null ? formatDate(q.createdAt!) : 'N/A',
                            createdByUid: q.createdByUid,
                            createdByEmail: q.createdByEmail,
                          )).toList(),
                        ),
                        if (assessments.isNotEmpty) ..._buildSection(
                          context, 'Assessments', Icons.assignment_turned_in_rounded,
                          assessments.map((a) => _RejectedItem(
                            title: a.title,
                            subtitle: 'Assessment',
                            icon: Icons.assignment_rounded,
                            reason: a.rejectionReason,
                            createdAtStr: a.createdAt != null ? formatDate(a.createdAt!) : 'N/A',
                            createdByUid: a.createdByUid,
                            createdByEmail: a.createdByEmail,
                          )).toList(),
                        ),
                        if (applications.isNotEmpty) ..._buildSection(
                          context, 'Applications', Icons.person_off_rounded,
                          applications.map((a) => _RejectedItem(
                            title: a.applicantEmail,
                            subtitle: 'Educator Application',
                            icon: Icons.person_rounded,
                            reason: a.rejectionReason,
                            createdAtStr: a.appliedAt != null ? formatDate(a.appliedAt!) : 'N/A',
                            createdByUid: null,
                            createdByEmail: a.applicantEmail,
                          )).toList(),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildSection(BuildContext ctx, String title, IconData icon, List<Widget> cards) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE05050).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFE05050), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE05050).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cards.length}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE05050), fontSize: 11, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      ...cards,
      const SizedBox(height: 16),
    ];
  }
}

// A single rejected item card
class _RejectedItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? reason;
  final String createdAtStr;
  final String? createdByUid;
  final String? createdByEmail;

  const _RejectedItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.createdAtStr,
    this.reason,
    this.createdByUid,
    this.createdByEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE05050).withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05050).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: const Color(0xFFE05050), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700, fontSize: 15,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AuthorName(
                        uid: createdByUid,
                        fallbackEmail: createdByEmail,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05050).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE05050).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel_rounded, size: 11, color: Color(0xFFE05050)),
                      const SizedBox(width: 4),
                      Text(
                        'Rejected',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE05050), fontSize: 10, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reason != null && reason!.isNotEmpty) ...([
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE05050).withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: const Color(0xFFE05050).withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REJECTION REASON',
                            style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: const Color(0xFFE05050).withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reason!,
                            style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF7A2020), height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Submitted: $createdAtStr',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
//  _ValidationCredentialThumb — thumbnail tile for credentials
// ═══════════════════════════════════════════════════════════
class _ValidationCredentialThumb extends StatelessWidget {
  final String label;
  final String url;
  final IconData fallbackIcon;

  const _ValidationCredentialThumb({
    required this.label,
    required this.url,
    required this.fallbackIcon,
  });

  bool get _isImage {
    final lower = url.toLowerCase();
    final clean = lower.split('?').first;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].any(
      (ext) => clean.endsWith('.$ext') || lower.contains('.$ext?') || lower.contains('format=$ext'),
    );
  }

  bool get _isVideo {
    final lower = url.toLowerCase();
    final clean = lower.split('?').first;
    return ['mp4', 'mov', 'avi', 'webm', 'm4v', 'mkv', 'ogv'].any(
      (ext) => clean.endsWith('.$ext') || lower.contains('.$ext?') || lower.contains('/video'),
    );
  }

  bool get _isPdf {
    final lower = url.toLowerCase();
    final clean = lower.split('?').first;
    return clean.endsWith('.pdf') || lower.contains('.pdf?') || lower.contains('pdf');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _preview(context),
      child: Container(
        width: 170,
        height: 150,
        margin: const EdgeInsets.only(right: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.2),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildContentTile(),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.12)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.open_in_full_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: Colors.white,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTile() {
    if (_isImage) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : _placeholder(),
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    if (_isVideo) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill, size: 46, color: Color(0xFF81B655)),
              SizedBox(height: 6),
              Text('VIDEO DEMO', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ],
          ),
        ),
      );
    }
    if (_isPdf) {
      return Container(
        color: const Color(0xFFFEF2F2),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_rounded, size: 46, color: Color(0xFFDC2626)),
              SizedBox(height: 6),
              Text('PDF DOC', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ],
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(fallbackIcon, size: 46, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text('DOCUMENT', style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade100,
        child: Center(
          child: Icon(fallbackIcon, size: 36, color: Colors.grey.shade300),
        ),
      );

  void _preview(BuildContext context) {
    String ext = 'pdf';
    if (_isImage) {
      ext = 'png';
    } else if (_isVideo) {
      ext = 'mp4';
    } else if (_isPdf) {
      ext = 'pdf';
    }
    final fileName = '${label.toLowerCase().replaceAll(' ', '_')}.$ext';
    showFilePreviewModal(context, url, fileName);
  }
}
