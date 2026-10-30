import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_colors.dart';

class AdminFeedbackTab extends StatefulWidget {
  const AdminFeedbackTab({super.key});

  @override
  State<AdminFeedbackTab> createState() => _AdminFeedbackTabState();
}

class _AdminFeedbackTabState extends State<AdminFeedbackTab> {
  String _selectedCategory = 'All';
  String _activeSectionView = 'ALL'; // 'ALL', 'PENDING', 'REVIEWED', 'RESOLVED'
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _feedbackStream;

  // Independent pagination pages for each section
  int _pendingPage = 1;
  int _reviewedPage = 1;
  int _resolvedPage = 1;
  static const int _pageSize = 5;

  final List<String> _categories = [
    'All',
    'General Feedback',
    'Feature Request',
    'Bug Report',
    'Lesson / Content Quality',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _feedbackStream = FeedbackService.instance.streamFeedbacks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetPagination() {
    _pendingPage = 1;
    _reviewedPage = 1;
    _resolvedPage = 1;
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'bug report':
        return Colors.redAccent;
      case 'feature request':
        return Colors.blueAccent;
      case 'lesson / content quality':
        return Colors.purpleAccent;
      default:
        return const Color(0xFF81B655);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
        return const Color(0xFF10B981);
      case 'REVIEWED':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recent';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return 'Recent';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _feedbackStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFeedbacks = snapshot.data ?? [];

        // Global metrics
        final totalCount = allFeedbacks.length;
        final globalPendingCount = allFeedbacks
            .where((f) => (f['status'] ?? 'PENDING') == 'PENDING')
            .length;
        final globalReviewedCount = allFeedbacks
            .where((f) => (f['status'] ?? '') == 'REVIEWED')
            .length;
        final globalResolvedCount = allFeedbacks
            .where((f) => (f['status'] ?? '') == 'RESOLVED')
            .length;

        // Apply search query and category filter
        final query = _searchCtrl.text.trim().toLowerCase();
        final filteredFeedbacks = allFeedbacks.where((f) {
          final category = (f['category'] ?? '').toString();
          final subject = (f['subject'] ?? '').toString().toLowerCase();
          final message = (f['message'] ?? '').toString().toLowerCase();
          final userName = (f['userName'] ?? '').toString().toLowerCase();
          final userEmail = (f['userEmail'] ?? '').toString().toLowerCase();

          if (_selectedCategory != 'All' && category != _selectedCategory) {
            return false;
          }
          if (query.isNotEmpty) {
            final matches = subject.contains(query) ||
                message.contains(query) ||
                userName.contains(query) ||
                userEmail.contains(query);
            if (!matches) return false;
          }
          return true;
        }).toList();

        // Segregate into 3 distinct status sections
        final pendingItems = filteredFeedbacks
            .where((f) => (f['status'] ?? 'PENDING') == 'PENDING')
            .toList();
        final reviewedItems = filteredFeedbacks
            .where((f) => (f['status'] ?? '') == 'REVIEWED')
            .toList();
        final resolvedItems = filteredFeedbacks
            .where((f) => (f['status'] ?? '') == 'RESOLVED')
            .toList();

        return SingleChildScrollView(
          key: const PageStorageKey('admin_feedback_tab_scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Feedback & Inquiries',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time feedback grouped into Pending, Reviewed, and Resolved sections.',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Metrics Counter Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Total Feedback',
                          '$totalCount',
                          Icons.inbox_rounded,
                          Colors.blueGrey,
                          cardBg,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Pending',
                          '$globalPendingCount',
                          Icons.pending_actions_rounded,
                          const Color(0xFFF59E0B),
                          cardBg,
                          isDark,
                        ),
                      ),
                      if (isWide) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Reviewed',
                            '$globalReviewedCount',
                            Icons.rate_review_rounded,
                            const Color(0xFF3B82F6),
                            cardBg,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Resolved',
                            '$globalResolvedCount',
                            Icons.check_circle_rounded,
                            const Color(0xFF10B981),
                            cardBg,
                            isDark,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Search & Filter Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) {
                        _resetPagination();
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by keyword, subject, user, or email...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF81B655),
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _resetPagination();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Category:',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ..._categories.map((cat) {
                            final isSel = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  cat,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: const Color(0xFF81B655).withValues(
                                  alpha: 0.2,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _selectedCategory = cat;
                                      _resetPagination();
                                    });
                                  }
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Section view toggle tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Section View:',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSectionViewChip(
                            label: 'All Sections',
                            value: 'ALL',
                            badgeCount: filteredFeedbacks.length,
                            color: const Color(0xFF64748B),
                          ),
                          _buildSectionViewChip(
                            label: 'Pending',
                            value: 'PENDING',
                            badgeCount: pendingItems.length,
                            color: const Color(0xFFF59E0B),
                          ),
                          _buildSectionViewChip(
                            label: 'Reviewed',
                            value: 'REVIEWED',
                            badgeCount: reviewedItems.length,
                            color: const Color(0xFF3B82F6),
                          ),
                          _buildSectionViewChip(
                            label: 'Resolved',
                            value: 'RESOLVED',
                            badgeCount: resolvedItems.length,
                            color: const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // SECTION 1: PENDING FEEDBACK
              // ==========================================
              if (_activeSectionView == 'ALL' || _activeSectionView == 'PENDING') ...[
                _buildSectionContainer(
                  title: 'Pending Submissions',
                  subtitle: 'Newly submitted inquiries awaiting review and triage',
                  icon: Icons.pending_actions_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  items: pendingItems,
                  currentPage: _pendingPage,
                  onPageChanged: (newPage) => setState(() => _pendingPage = newPage),
                  emptyMessage: 'No pending feedbacks. All items have been reviewed!',
                  cardBg: cardBg,
                  isDark: isDark,
                ),
                const SizedBox(height: 28),
              ],

              // ==========================================
              // SECTION 2: REVIEWED FEEDBACK
              // ==========================================
              if (_activeSectionView == 'ALL' || _activeSectionView == 'REVIEWED') ...[
                _buildSectionContainer(
                  title: 'Reviewed Feedback',
                  subtitle: 'Items currently under active evaluation or in-progress',
                  icon: Icons.rate_review_rounded,
                  accentColor: const Color(0xFF3B82F6),
                  items: reviewedItems,
                  currentPage: _reviewedPage,
                  onPageChanged: (newPage) => setState(() => _reviewedPage = newPage),
                  emptyMessage: 'No feedback currently marked as Reviewed.',
                  cardBg: cardBg,
                  isDark: isDark,
                ),
                const SizedBox(height: 28),
              ],

              // ==========================================
              // SECTION 3: RESOLVED FEEDBACK
              // ==========================================
              if (_activeSectionView == 'ALL' || _activeSectionView == 'RESOLVED') ...[
                _buildSectionContainer(
                  title: 'Resolved Feedback',
                  subtitle: 'Completed issues, implemented requests, and answered questions',
                  icon: Icons.check_circle_rounded,
                  accentColor: const Color(0xFF10B981),
                  items: resolvedItems,
                  currentPage: _resolvedPage,
                  onPageChanged: (newPage) => setState(() => _resolvedPage = newPage),
                  emptyMessage: 'No feedback marked as Resolved yet.',
                  cardBg: cardBg,
                  isDark: isDark,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionViewChip({
    required String label,
    required String value,
    required int badgeCount,
    required Color color,
  }) {
    final isSel = _activeSectionView == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSel,
        selectedColor: color.withValues(alpha: 0.18),
        side: BorderSide(
          color: isSel ? color : Colors.grey.withValues(alpha: 0.3),
          width: isSel ? 1.5 : 1,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? color : null,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSel ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        onSelected: (_) {
          setState(() {
            _activeSectionView = value;
          });
        },
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Map<String, dynamic>> items,
    required int currentPage,
    required ValueChanged<int> onPageChanged,
    required String emptyMessage,
    required Color cardBg,
    required bool isDark,
  }) {
    final totalItems = items.length;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 999999);
    final safePage = currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalItems);
    final pagedItems = totalItems > 0
        ? items.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                bottom: BorderSide(
                  color: accentColor.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalItems',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalItems > 0)
                  Text(
                    'Page $safePage of $totalPages',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
              ],
            ),
          ),

          // Section Content / Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: totalItems == 0
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 42,
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptyMessage,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pagedItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = pagedItems[index];
                          return _buildFeedbackCard(
                            item: item,
                            cardBg: cardBg,
                            isDark: isDark,
                          );
                        },
                      ),

                      // Dedicated Pagination Bar for this section
                      if (totalItems > _pageSize) ...[
                        const SizedBox(height: 14),
                        _buildPaginationBar(
                          totalItems: totalItems,
                          currentPage: safePage,
                          totalPages: totalPages,
                          startIndex: startIndex,
                          endIndex: endIndex,
                          onPageChanged: onPageChanged,
                          isDark: isDark,
                          accentColor: accentColor,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard({
    required Map<String, dynamic> item,
    required Color cardBg,
    required bool isDark,
  }) {
    final id = item['id'] as String;
    final subject = (item['subject'] ?? 'No Subject').toString();
    final message = (item['message'] ?? '').toString();
    final category = (item['category'] ?? 'General').toString();
    final rating = (item['rating'] as num?)?.toInt() ?? 5;
    final userName = (item['userName'] ?? 'User').toString();
    final userEmail = (item['userEmail'] ?? '').toString();
    final userRole = (item['userRole'] ?? 'LEARNER').toString();
    final status = (item['status'] ?? 'PENDING').toString().toUpperCase();
    final createdAt = item['createdAt'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Rating, Category, Status menu
          Row(
            children: [
              // Rating Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '$rating/5',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _categoryColor(category).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: _categoryColor(category),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),

              // Status Dropdown Switcher
              PopupMenuButton<String>(
                tooltip: 'Change status',
                onSelected: (newStat) async {
                  await FeedbackService.instance.updateFeedbackStatus(id, newStat);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _statusColor(status).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: _statusColor(status),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'PENDING',
                    child: Text('Mark PENDING'),
                  ),
                  const PopupMenuItem(
                    value: 'REVIEWED',
                    child: Text('Mark REVIEWED'),
                  ),
                  const PopupMenuItem(
                    value: 'RESOLVED',
                    child: Text('Mark RESOLVED'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subject
          Text(
            subject,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Message Preview
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Bottom Row: Clean user info with bullet • (No middot!)
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF81B655).withValues(alpha: 0.2),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF81B655),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$userName • $userRole',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$userEmail • ${_formatDate(createdAt)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (userEmail.isNotEmpty)
                IconButton(
                  tooltip: 'Reply via email',
                  icon: const Icon(
                    Icons.email_outlined,
                    size: 19,
                    color: Color(0xFF3B82F6),
                  ),
                  onPressed: () async {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: userEmail,
                      query: 'subject=Re: [Grammatica Feedback] $subject',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              IconButton(
                tooltip: 'View details',
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 19,
                  color: Color(0xFF81B655),
                ),
                onPressed: () => _showDetailDialog(context, item, isDark),
              ),
              IconButton(
                tooltip: 'Delete feedback',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: Colors.redAccent,
                ),
                onPressed: () => _confirmDelete(context, id, subject),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int endIndex,
    required ValueChanged<int> onPageChanged,
    required bool isDark,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalItems',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Previous page',
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Next page',
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color cardBg,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final id = item['id'] as String;
    final subject = (item['subject'] ?? 'No Subject').toString();
    final message = (item['message'] ?? '').toString();
    final category = (item['category'] ?? 'General').toString();
    final rating = (item['rating'] as num?)?.toInt() ?? 5;
    final userName = (item['userName'] ?? 'User').toString();
    final userEmail = (item['userEmail'] ?? '').toString();
    final userRole = (item['userRole'] ?? 'LEARNER').toString();
    final status = (item['status'] ?? 'PENDING').toString().toUpperCase();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          subject,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _categoryColor(category).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: _categoryColor(category),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '★ $rating/5 Rating',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    message,
                    style: GoogleFonts.inter(fontSize: 14, height: 1.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'User Details',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text('• Name: $userName', style: GoogleFonts.inter(fontSize: 13)),
                Text(
                  '• Email: $userEmail',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                Text('• Role: $userRole', style: GoogleFonts.inter(fontSize: 13)),
                Text('• Status: $status', style: GoogleFonts.inter(fontSize: 13)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF81B655),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: Text(
              status == 'RESOLVED' ? 'Mark Pending' : 'Mark Resolved',
            ),
            onPressed: () async {
              final newStat = status == 'RESOLVED' ? 'PENDING' : 'RESOLVED';
              await FeedbackService.instance.updateFeedbackStatus(id, newStat);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String subject) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Feedback?'),
        content: Text('Are you sure you want to remove feedback "$subject"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FeedbackService.instance.deleteFeedback(id);
    }
  }
}
