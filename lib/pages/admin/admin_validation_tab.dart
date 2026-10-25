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
import '../../widgets/content_denial_dialog.dart';

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

class _AdminValidationTabState extends State<AdminValidationTab> with SingleTickerProviderStateMixin {
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
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static const _tabLabels = ['Lessons & Packages', 'Educator Applications', 'Rejected'];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, _tabLabels.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.role == UserRole.superadmin;
    if (isSuperAdmin) {
      return _EducatorApplicationsList(formatDate: _formatTs, type: 'validator');
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackgroundWrapper(
      child: Column(
        children: [
          // ── Navigation: Dropdown on mobile, Tabs on desktop ──────────
          if (isMobile)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedTab,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary),
                  items: List.generate(_tabLabels.length, (i) {
                    final isRejected = i == 2;
                    return DropdownMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          if (isRejected) ...[
                            const Icon(Icons.block_rounded,
                                size: 14, color: Color(0xFFE05050)),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _tabLabels[i],
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isRejected
                                  ? const Color(0xFFE05050)
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedTab = val);
                  },
                ),
              ),
            )
          else
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_tabLabels.length, (i) {
                    final isSelected = _selectedTab == i;
                    final isRejected = i == 2;
                    final activeColor = isRejected ? const Color(0xFFE05050) : const Color(0xFF81B655);

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? activeColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                i == 0
                                    ? Icons.auto_stories_rounded
                                    : (i == 1 ? Icons.badge_rounded : Icons.block_rounded),
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _tabLabels[i],
                                style: GoogleFonts.outfit(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14.5,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

          // ── Tab Content ──────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _ValidationList(stream: DatabaseService.instance.streamAwaitingApprovalLessons(), collection: 'lessons', formatDate: _formatTs),
                _EducatorApplicationsList(formatDate: _formatTs, type: 'educator', showRejected: false),
                _AllRejectedTab(formatDate: _formatTs),
              ],
            ),
          ),
        ],
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final typeStr = type == 'validator' ? 'validator' : 'educator';
          final msg = showRejected
              ? 'No rejected $typeStr applications.'
              : 'No $typeStr applications pending.';
          return Center(
            child: Text(
              msg,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section with applicant details (Full Name, Age, Member Since)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        final profileWidget = _ApplicantProfileHeader(
                          applicantUid: app.applicantUid,
                          fallbackEmail: email,
                          appliedAtStr: appliedAtStr,
                        );

                        final actions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InkWell(
                              onTap: () => _approveApplication(context, app),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Color(0xFF81B655), size: 18),
                                    SizedBox(width: 6),
                                    Text('Approve', style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _rejectApplication(context, app),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.highlight_off, color: Colors.redAccent, size: 18),
                                    SizedBox(width: 6),
                                    Text('Reject', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );

                        return isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  profileWidget,
                                  const SizedBox(height: 14),
                                  actions,
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: profileWidget),
                                  const SizedBox(width: 16),
                                  actions,
                                ],
                              );
                      },
                    ),
                  ),
                  Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                  // ── Credentials section in clean List View (not grid) ──
                  if (!showRejected) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'APPLICATION REQUIREMENTS & CREDENTIALS',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'REQUIREMENTS VIEW',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF81B655)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ValidationCredentialListView(app: app),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 15,
                            color: Colors.orange.shade400,
                          ),
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
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(app.applicantUid).get();
    final uData = userDoc.data();
    final fName = (uData?['first_name'] as String?)?.trim() ?? '';
    final lName = (uData?['last_name'] as String?)?.trim() ?? '';
    final fullName = '$fName $lName'.trim();
    final username = (uData?['username'] as String?)?.trim() ?? '';
    final applicantDisplayName = fullName.isNotEmpty
        ? fullName
        : (username.isNotEmpty ? username : 'Applicant');

    if (!context.mounted) return;

    final result = await showContentDenialDialog(
      context,
      contentTitle: '${app.applicationType == 'validator' ? 'Validator' : 'Educator'} Application - $applicantDisplayName',
      authorName: applicantDisplayName,
      isPermanentDeletion: false,
    );

    if (result != null) {
      try {
        await DatabaseService.instance.rejectEducatorApplication(
          app,
          reason: result.category,
          description: result.explanation,
        );
        // Send notification to the user
        await NotificationService.instance.sendRejectionNotification(
          uid: app.applicantUid,
          reason: result.category,
          description: result.explanation,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application rejected and applicant notified.'),
              backgroundColor: Color(0xFFE05050),
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Text(
              'No items awaiting approval.',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          );
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
            final isMobile = MediaQuery.of(context).size.width < 600;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final actionRow = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.blue),
                  tooltip: 'Review Content',
                  onPressed: () => _showReviewModal(context, item, collection),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  onPressed: () => _approve(context, item),
                ),
                IconButton(
                  icon: const Icon(Icons.highlight_off, color: Colors.red),
                  onPressed: () => _reject(context, item),
                ),
              ],
            );

            final infoBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                AuthorName(
                  uid: item.createdByUid,
                  fallbackEmail: item.createdByEmail,
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isMembersOnly
                            ? Colors.amber.withValues(alpha: 0.12)
                            : const Color(0xFF81B655).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.isMembersOnly ? 'Members Only' : 'Public',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: item.isMembersOnly ? Colors.amber.shade700 : const Color(0xFF81B655),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Submitted: $createdAtStr',
                      style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            );

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  if (collection == 'lessons') {
                    NavigationService.instance.goToLesson(context, item as Lesson, previewMode: true);
                  } else {
                    NavigationService.instance.goToQuiz(context, item as Quiz, previewMode: true);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            infoBlock,
                            const SizedBox(height: 10),
                            Align(alignment: Alignment.centerRight, child: actionRow),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: infoBlock),
                            actionRow,
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

  Future<void> _showReviewModal(
    BuildContext context,
    dynamic item,
    String collection,
  ) async {
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
                  ? LessonPage(
                      user: user,
                      lesson: item as Lesson,
                      previewMode: true,
                    )
                  : QuizDetailPage(
                      user: user,
                      quiz: item as Quiz,
                      previewMode: true,
                    ),
              bottomNavigationBar: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Approval'),
        content: Text('Are you sure you want to approve "${item.title}"? It will be published for learners to access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Approve & Publish'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (item is Lesson) {
        await DatabaseService.instance.updateLessonPackageStatus(
          lesson: item,
          status: 'approved',
        );
      } else {
        await DatabaseService.instance.updateContentStatus(
          collection,
          item.id,
          'approved',
        );
      }

      // Notify the creator
      if (item.createdByUid != null && item.createdByUid!.isNotEmpty) {
        await NotificationService.instance.sendContentValidationNotification(
          uid: item.createdByUid!,
          title: item.title,
          approved: true,
        );

        // Notify subscribers of the educator's new lesson upload
        if (item is Lesson) {
          await NotificationService.instance.notifySubscribersOfLesson(
            educatorUid: item.createdByUid!,
            lessonTitle: item.title,
            lessonId: item.id,
          );
        }
      } else {
        debugPrint('CANNOT NOTIFY: createdByUid is null for item ${item.id}');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Approved! Notification sent to creator (ID: ${item.createdByUid})',
            ),
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
    final String contentTitle = (item.title as String?) ?? 'Untitled Content';
    final String? authorEmail = (item is Lesson) ? item.createdByEmail : null;

    final result = await showContentDenialDialog(
      context,
      contentTitle: contentTitle,
      authorName: authorEmail,
      isPermanentDeletion: false,
    );

    if (result != null) {
      try {
        if (item.createdByUid != null && (item.createdByUid as String).isNotEmpty) {
          await NotificationService.instance.sendContentValidationNotification(
            uid: item.createdByUid!,
            title: contentTitle,
            approved: false,
            reason: result.category,
            description: result.explanation,
          );
        } else {
          debugPrint('CANNOT NOTIFY: createdByUid is null for item ${item.id}');
        }

        if (item is Lesson) {
          await DatabaseService.instance.updateLessonPackageStatus(
            lesson: item,
            status: 'rejected',
            rejectionReason: result.category,
            rejectionDescription: result.explanation,
          );
        } else {
          // Mark as rejected — preserves content for audit trail
          await DatabaseService.instance.updateContentStatus(
            collection,
            item.id,
            'rejected',
            rejectionReason: result.category,
            rejectionDescription: result.explanation,
          );
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content rejected. Author has been notified with the specified reason.'),
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
        return StreamBuilder<List<EducatorApplication>>(
          stream: DatabaseService.instance.streamRejectedApplications(),
          builder: (ctx, appSnap) {
            if (lessonSnap.connectionState == ConnectionState.waiting ||
                appSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final lessons = lessonSnap.data ?? [];
            final applications = appSnap.data ?? [];

            final bool isEmpty = lessons.isEmpty && applications.isEmpty;

            if (isEmpty) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.green.shade900.withValues(alpha: 0.3)
                            : Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 56,
                        color: isDark ? const Color(0xFF81B655) : Colors.green.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Rejected Content',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All submitted content is clean.',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white60 : Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (lessons.isNotEmpty)
                  ..._buildSection(
                    context,
                    'Lessons & Packages',
                    Icons.auto_stories_rounded,
                    lessons
                        .map(
                          (l) => _RejectedItem(
                            title: l.title,
                            subtitle: 'Lesson Package',
                            icon: Icons.description_rounded,
                            reason: l.rejectionReason,
                            description: l.rejectionDescription,
                            createdAtStr: l.createdAt != null
                                ? formatDate(l.createdAt!)
                                : 'N/A',
                            createdByUid: l.createdByUid,
                            createdByEmail: l.createdByEmail,
                          ),
                        )
                        .toList(),
                  ),
                if (applications.isNotEmpty)
                  ..._buildSection(
                    context,
                    'Applications',
                    Icons.person_off_rounded,
                    applications
                        .map(
                          (a) => _RejectedItem(
                            title: a.applicantEmail,
                            subtitle: 'Educator Application',
                            icon: Icons.person_rounded,
                            reason: a.rejectionReason,
                            description: a.rejectionDescription,
                            createdAtStr: a.appliedAt != null
                                ? formatDate(a.appliedAt!)
                                : 'N/A',
                            createdByUid: null,
                            createdByEmail: a.applicantEmail,
                          ),
                        )
                        .toList(),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildSection(
    BuildContext ctx,
    String title,
    IconData icon,
    List<Widget> cards,
  ) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE05050).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFE05050), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE05050).withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cards.length}',
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFE05050),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
  final String? description;
  final String createdAtStr;
  final String? createdByUid;
  final String? createdByEmail;

  const _RejectedItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.createdAtStr,
    this.reason,
    this.description,
    this.createdByUid,
    this.createdByEmail,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final reasonBg = isDark ? const Color(0xFF2E1717) : const Color(0xFFFFF3F3);
    final reasonBorder = const Color(0xFFE05050).withValues(alpha: isDark ? 0.35 : 0.15);
    final textTitleColor = isDark ? Colors.white : const Color(0xFF2C3E50);
    final textSubColor = isDark ? Colors.white60 : Colors.grey.shade500;
    final categoryTextColor = isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C);
    final descTextColor = isDark ? const Color(0xFFFFCDD2) : const Color(0xFF7A2020);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE05050).withValues(alpha: isDark ? 0.25 : 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                    color: const Color(0xFFE05050).withValues(alpha: isDark ? 0.15 : 0.08),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textTitleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AuthorName(
                        uid: createdByUid,
                        fallbackEmail: createdByEmail,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textSubColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05050).withValues(alpha: isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE05050).withValues(alpha: isDark ? 0.4 : 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cancel_rounded,
                        size: 11,
                        color: Color(0xFFE05050),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Rejected',
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFE05050),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((reason != null && reason!.isNotEmpty) ||
                (description != null && description!.isNotEmpty))
              ...([
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: reasonBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: reasonBorder,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFE05050).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (reason != null && reason!.isNotEmpty) ...[
                              Text(
                                'REASON CATEGORY: ${reason!.toUpperCase()}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: categoryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (description != null && description!.isNotEmpty)
                              Text(
                                description!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: descTextColor,
                                  height: 1.4,
                                ),
                              )
                            else if (reason != null && reason!.isNotEmpty)
                              Text(
                                reason!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: descTextColor,
                                  height: 1.4,
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
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _ApplicantProfileHeader extends StatelessWidget {
  final String applicantUid;
  final String fallbackEmail;
  final String appliedAtStr;

  const _ApplicantProfileHeader({
    required this.applicantUid,
    required this.fallbackEmail,
    required this.appliedAtStr,
  });

  int? _calcAge(Timestamp? dob) {
    if (dob == null) return null;
    final birthDate = dob.toDate();
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final d = ts.toDate();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(applicantUid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final firstName = (data?['first_name'] as String?)?.trim() ?? '';
        final lastName = (data?['last_name'] as String?)?.trim() ?? '';
        final fullName = '$firstName $lastName'.trim();
        final username = (data?['username'] as String?)?.trim();
        final photoUrl = data?['photoUrl'] as String?;
        final dob = data?['date_of_birth'] as Timestamp?;
        final createdAt = data?['createdAt'] as Timestamp?;
        final email = (data?['email'] as String?) ?? fallbackEmail;

        final displayName = fullName.isNotEmpty
            ? fullName
            : (username != null && username.isNotEmpty ? username : email);

        final age = _calcAge(dob);
        final joinedStr = _formatDate(createdAt);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF81B655).withValues(alpha: 0.15),
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF81B655), fontSize: 16),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cake_outlined, size: 12, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              age != null ? 'Age: $age yrs old' : 'Age: Not set',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 12, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 4),
                            Text(
                              'Joined: $joinedStr',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Applied: $appliedAtStr',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ValidationCredentialListView extends StatelessWidget {
  final EducatorApplication app;

  const _ValidationCredentialListView({required this.app});

  void _preview(BuildContext context, String url, String label) {
    String ext = 'pdf';
    final lower = url.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].any((e) => lower.contains('.$e'))) {
      ext = 'png';
    } else if (['mp4', 'mov', 'avi', 'webm', 'mkv'].any((e) => lower.contains('.$e'))) {
      ext = 'mp4';
    }
    final fileName = '${label.toLowerCase().replaceAll(' ', '_')}.$ext';
    showFilePreviewModal(context, url, fileName);
  }

  Widget _buildRequirementItem({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Map<String, String>> files,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: files.isNotEmpty
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  files.isNotEmpty ? '${files.length} Submitted' : 'Missing',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: files.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (files.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'No document submitted for this requirement.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            ...files.map((file) {
              final label = file['label'] ?? title;
              final url = file['url'] ?? '';
              final ext = file['ext'] ?? 'DOCUMENT';

              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ext.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Click preview to review applicant submission',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _preview(context, url, label),
                        icon: const Icon(Icons.visibility_rounded, size: 14),
                        label: const Text('Preview File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor.withValues(alpha: 0.15),
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static String _extractFileName(String url, String? savedName, String fallback) {
    if (savedName != null && savedName.trim().isNotEmpty) {
      return savedName.trim();
    }
    if (url.isEmpty) return fallback;
    try {
      final uri = Uri.parse(url);
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      var decoded = Uri.decodeComponent(segment);
      if (decoded.contains('/')) decoded = decoded.split('/').last;
      final regex = RegExp(r'^\d{10,14}_(.+)$');
      final match = regex.firstMatch(decoded);
      if (match != null && match.group(1) != null) {
        decoded = match.group(1)!;
      }
      return decoded.isNotEmpty ? decoded : fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String _getFileExt(String fileName, String fallback) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'PDF';
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'IMG';
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') || lower.endsWith('.webm')) return 'VIDEO';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'DOC';
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cvLabel = _extractFileName(app.cvUrl, app.cvFileName, 'Applicant_CV_Resume.pdf');
    final cvFiles = <Map<String, String>>[
      if (app.cvUrl.isNotEmpty) {
        'label': cvLabel,
        'url': app.cvUrl,
        'ext': _getFileExt(cvLabel, 'PDF'),
      },
    ];

    final certFiles = app.certificateUrls
        .asMap()
        .entries
        .where((e) => e.value.isNotEmpty)
        .map((e) {
          final saved = (app.certificateFileNames != null && e.key < app.certificateFileNames!.length)
              ? app.certificateFileNames![e.key]
              : null;
          final certLabel = _extractFileName(e.value, saved, 'Teaching_Certificate_${e.key + 1}');
          return {
            'label': certLabel,
            'url': e.value,
            'ext': _getFileExt(certLabel, 'CERT'),
          };
        }).toList();

    final videoLabel = _extractFileName(app.videoUrl, app.videoFileName, 'Teaching_Demonstration.mp4');
    final videoFiles = <Map<String, String>>[
      if (app.videoUrl.isNotEmpty) {
        'label': videoLabel,
        'url': app.videoUrl,
        'ext': _getFileExt(videoLabel, 'VIDEO'),
      },
    ];

    final syllabusLabel = _extractFileName(app.syllabusUrl, app.syllabusFileName, 'Course_Syllabus.pdf');
    final syllabusFiles = <Map<String, String>>[
      if (app.syllabusUrl.isNotEmpty) {
        'label': syllabusLabel,
        'url': app.syllabusUrl,
        'ext': _getFileExt(syllabusLabel, 'SYLLABUS'),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Curriculum Vitae
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Curriculum Vitae (CV / Résumé)',
          subtitle: 'Educational background, employment history, and teaching experience',
          icon: Icons.description_rounded,
          accentColor: const Color(0xFF10B981),
          files: cvFiles,
        ),

        // 2. Teaching Certificates
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Teaching & Accreditation Certificates',
          subtitle: 'Accreditation certificates, teaching licenses, and academic diplomas',
          icon: Icons.verified_rounded,
          accentColor: const Color(0xFF3B82F6),
          files: certFiles,
        ),

        // 3. Teaching Demo Video
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Teaching Demonstration Video',
          subtitle: 'Recorded teaching demonstration showcasing instruction methodology',
          icon: Icons.videocam_rounded,
          accentColor: const Color(0xFF8B5CF6),
          files: videoFiles,
        ),

        // 4. Course Syllabus
        _buildRequirementItem(
          context: context,
          isDark: isDark,
          title: 'Course Syllabus / Instructional Plan',
          subtitle: 'Structured curriculum plan, lesson topics, and learning objectives',
          icon: Icons.menu_book_rounded,
          accentColor: const Color(0xFF0EA5E9),
          files: syllabusFiles,
        ),
      ],
    );
  }
}
