import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/author_name_widget.dart';
import '../../widgets/application_preview_widgets.dart';
import '../../widgets/design_ornaments.dart';
import '../../widgets/pagination_bar.dart';
import '../lesson_page.dart';

class ValidatorApprovedTab extends StatefulWidget {
  final int initialTabIndex;
  const ValidatorApprovedTab({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ValidatorApprovedTab> createState() => _ValidatorApprovedTabState();
}

class _ValidatorApprovedTabState extends State<ValidatorApprovedTab> {
  static const List<String> _tabLabels = [
    'Approved Lessons',
    'Approved Educators',
  ];

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, _tabLabels.length - 1);
  }

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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final amPm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $hour:$minute $amPm';
  }

  IconData _getTabIcon(int index) {
    return index == 0 ? Icons.auto_stories_rounded : Icons.verified_user_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackgroundWrapper(
      child: Column(
        children: [
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
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF81B655),
                  ),
                  items: List.generate(_tabLabels.length, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          Icon(
                            _getTabIcon(i),
                            size: 16,
                            color: const Color(0xFF81B655),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tabLabels[i],
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    const activeColor = Color(0xFF81B655);
                    final tabIcon = _getTabIcon(i);

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
                                tabIcon,
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
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _ApprovedLessonsList(formatDate: _formatTs),
                _ApprovedEducatorsList(formatDate: _formatTs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovedLessonsList extends StatefulWidget {
  final String Function(dynamic) formatDate;
  const _ApprovedLessonsList({required this.formatDate});

  @override
  State<_ApprovedLessonsList> createState() => _ApprovedLessonsListState();
}

class _ApprovedLessonsListState extends State<_ApprovedLessonsList> {
  int _currentPage = 1;
  static const int _pageSize = 8;

  void _previewLesson(BuildContext context, Lesson lesson) {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final approvedAtStr = (lesson.reviewedAt ?? lesson.createdAt) != null
        ? widget.formatDate(lesson.reviewedAt ?? lesson.createdAt)
        : 'N/A';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Container(
              color: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.center,
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Approved Lesson • Approved on: $approvedAtStr',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: LessonPage(
            user: user,
            lesson: lesson,
            previewMode: true,
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(ctx).brightness == Brightness.dark
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
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
                label: const Text('Close Preview'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamApprovedLessons(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No approved lessons found.',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          );
        }

        final totalItems = items.length;
        final maxPage = (totalItems / _pageSize).ceil().clamp(1, 9999);
        if (_currentPage > maxPage) _currentPage = maxPage;
        final startIndex = (_currentPage - 1) * _pageSize;
        final pageItems = items.skip(startIndex).take(_pageSize).toList();

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pageItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final lesson = pageItems[index];
                  final approvedTimestamp = lesson.reviewedAt ?? lesson.createdAt;
                  final approvedAtStr = approvedTimestamp != null
                      ? widget.formatDate(approvedTimestamp)
                      : 'N/A';
                  final submittedAtStr = lesson.createdAt != null
                      ? widget.formatDate(lesson.createdAt!)
                      : 'N/A';
                  final isOfficial = lesson.isGrammaticaLesson ||
                      (lesson.createdByEmail != null &&
                          lesson.createdByEmail!.toLowerCase().contains('admin'));

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
                      onTap: () => _previewLesson(context, lesson),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: Color(0xFF16A34A),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        lesson.title,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Approved',
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF16A34A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (isOfficial ? const Color(0xFFD97706) : const Color(0xFF3B82F6))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isOfficial ? 'Grammatica Official' : 'Community Hub',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: isOfficial ? const Color(0xFFD97706) : const Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AuthorName(
                                    uid: lesson.createdByUid,
                                    fallbackEmail: lesson.createdByEmail,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF16A34A)),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Approved: $approvedAtStr',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF16A34A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 13,
                                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Submitted: $submittedAtStr',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => _previewLesson(context, lesson),
                              icon: const Icon(Icons.visibility_rounded, size: 16),
                              label: const Text('View Lesson'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF81B655).withValues(alpha: 0.15),
                                foregroundColor: const Color(0xFF81B655),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (totalItems > _pageSize)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PaginationBar(
                  currentPage: _currentPage,
                  totalItems: totalItems,
                  pageSize: _pageSize,
                  itemName: 'approved lessons',
                  onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ApprovedEducatorsList extends StatefulWidget {
  final String Function(dynamic) formatDate;
  const _ApprovedEducatorsList({required this.formatDate});

  @override
  State<_ApprovedEducatorsList> createState() => _ApprovedEducatorsListState();
}

class _ApprovedEducatorsListState extends State<_ApprovedEducatorsList> {
  int _currentPage = 1;
  static const int _pageSize = 6;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<EducatorApplication>>(
      stream: DatabaseService.instance.streamApprovedEducatorApplications(type: 'educator'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (snapshot.data ?? [])
            .where((a) => a.applicationType != 'validator')
            .toList();

        if (items.isEmpty) {
          return Center(
            child: Text(
              'No approved educator applications found.',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          );
        }

        final totalItems = items.length;
        final maxPage = (totalItems / _pageSize).ceil().clamp(1, 9999);
        if (_currentPage > maxPage) _currentPage = maxPage;
        final startIndex = (_currentPage - 1) * _pageSize;
        final pageItems = items.skip(startIndex).take(_pageSize).toList();

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pageItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final app = pageItems[index];
                  final approvedTimestamp = app.reviewedAt ?? app.appliedAt;
                  final approvedAtStr = approvedTimestamp != null
                      ? widget.formatDate(approvedTimestamp)
                      : 'N/A';
                  final appliedAtStr = app.appliedAt != null
                      ? widget.formatDate(app.appliedAt!)
                      : 'N/A';

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: _ApprovedEducatorHeader(
                            applicantUid: app.applicantUid,
                            fallbackEmail: app.applicantEmail,
                            appliedAtStr: appliedAtStr,
                            approvedAtStr: approvedAtStr,
                          ),
                        ),
                        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: _ApprovedCredentialsSection(app: app),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (totalItems > _pageSize)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PaginationBar(
                  currentPage: _currentPage,
                  totalItems: totalItems,
                  pageSize: _pageSize,
                  itemName: 'approved educators',
                  onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ApprovedEducatorHeader extends StatelessWidget {
  final String applicantUid;
  final String fallbackEmail;
  final String appliedAtStr;
  final String approvedAtStr;

  const _ApprovedEducatorHeader({
    required this.applicantUid,
    required this.fallbackEmail,
    required this.appliedAtStr,
    required this.approvedAtStr,
  });

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
        final email = (data?['email'] as String?) ?? fallbackEmail;

        final displayName = fullName.isNotEmpty
            ? fullName
            : (username != null && username.isNotEmpty ? username : email);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.15),
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Approved Educator',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Approved on: $approvedAtStr',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Applied: $appliedAtStr',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
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

class _ApprovedCredentialsSection extends StatelessWidget {
  final EducatorApplication app;
  const _ApprovedCredentialsSection({required this.app});

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

  Widget _buildCredentialRow({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Map<String, String>> files,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: files.isNotEmpty
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  files.isNotEmpty ? '${files.length} Submitted' : 'None',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: files.isNotEmpty ? const Color(0xFF10B981) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...files.map((file) {
              final label = file['label'] ?? title;
              final url = file['url'] ?? '';
              final ext = file['ext'] ?? 'FILE';

              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        ext.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _preview(context, url, label),
                      icon: const Icon(Icons.visibility_rounded, size: 14),
                      label: const Text('View Credential', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor.withValues(alpha: 0.15),
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
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
        Row(
          children: [
            Text(
              'SUBMITTED EDUCATOR CREDENTIALS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'VERIFIED CREDENTIALS',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCredentialRow(
          context: context,
          isDark: isDark,
          title: 'Curriculum Vitae (CV / Résumé)',
          icon: Icons.description_rounded,
          accentColor: const Color(0xFF10B981),
          files: cvFiles,
        ),
        _buildCredentialRow(
          context: context,
          isDark: isDark,
          title: 'Teaching & Accreditation Certificates',
          icon: Icons.verified_rounded,
          accentColor: const Color(0xFF3B82F6),
          files: certFiles,
        ),
        _buildCredentialRow(
          context: context,
          isDark: isDark,
          title: 'Teaching Demonstration Video',
          icon: Icons.videocam_rounded,
          accentColor: const Color(0xFF8B5CF6),
          files: videoFiles,
        ),
        _buildCredentialRow(
          context: context,
          isDark: isDark,
          title: 'Course Syllabus / Instructional Plan',
          icon: Icons.menu_book_rounded,
          accentColor: const Color(0xFF0EA5E9),
          files: syllabusFiles,
        ),
      ],
    );
  }
}

