import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../models/playlist.dart';
import 'educator_profile_page.dart';

class BrowseEducatorsTab extends StatefulWidget {
  const BrowseEducatorsTab({super.key, required this.user});
  final User user;

  @override
  State<BrowseEducatorsTab> createState() => _BrowseEducatorsTabState();
}

class _BrowseEducatorsTabState extends State<BrowseEducatorsTab> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  late final Stream<List<Map<String, dynamic>>> _educatorsStream;
  late final Stream<Set<String>> _subscriptionsStream;
  String _activeTab = 'discover'; // 'enrolled', 'discover'

  @override
  void initState() {
    super.initState();
    _educatorsStream = DatabaseService.instance.streamEducators();
    _subscriptionsStream = DatabaseService.instance.streamActiveSubscribedEducatorIds(widget.user.uid);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
      child: StreamBuilder<Set<String>>(
        stream: _subscriptionsStream,
        builder: (context, subSnapshot) {
          final subscribedUids = subSnapshot.data ?? <String>{};

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _educatorsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allEducators = snapshot.data ?? [];
              final query = _searchQuery.trim().toLowerCase();
              final filtered = allEducators.where((e) {
                final uid = e['uid'] as String? ?? '';
                if (uid == widget.user.uid) return false;
                if (query.isEmpty) return true;
                final username = (e['username'] as String? ?? '').toLowerCase();
                final displayName = (e['displayName'] as String? ?? '').toLowerCase();
                final firstName = ((e['first_name'] ?? e['firstName']) as String? ?? '').toLowerCase();
                final lastName = ((e['last_name'] ?? e['lastName']) as String? ?? '').toLowerCase();
                final fullName = '$firstName $lastName'.trim();
                final email = (e['email'] as String? ?? '').toLowerCase();
                final bio = (e['bio'] as String? ?? '').toLowerCase();
                return username.contains(query) ||
                    displayName.contains(query) ||
                    firstName.contains(query) ||
                    lastName.contains(query) ||
                    fullName.contains(query) ||
                    email.contains(query) ||
                    bio.contains(query);
              }).toList();

              // Separate enrolled from not-enrolled
              final enrolledEducators = filtered.where((e) {
                final uid = (e['uid'] ?? e['id'] ?? '').toString();
                return subscribedUids.contains(uid);
              }).toList();

              final discoverEducators = filtered.where((e) {
                final uid = (e['uid'] ?? e['id'] ?? '').toString();
                return !subscribedUids.contains(uid);
              }).toList();

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // ─── Hero Header, Search & Filter Bar ─────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF81B655).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school_rounded, size: 14, color: Color(0xFF81B655)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'EDUCATOR NETWORK',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF81B655),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Browse Educators',
                                style: GoogleFonts.outfit(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  height: 1.15,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enroll with educators for structured courses, custom lessons, and 1-on-1 mentorship.',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Search Bar & Filter Controls Row
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 640),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                            blurRadius: 14,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _searchCtrl,
                                        onChanged: (val) {
                                          _debounceTimer?.cancel();
                                          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                                            if (mounted) setState(() => _searchQuery = val.toLowerCase());
                                          });
                                        },
                                        onSubmitted: (val) {
                                          _debounceTimer?.cancel();
                                          setState(() => _searchQuery = val.toLowerCase());
                                        },
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          fontSize: 14,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Search educators by name, specialty, or bio…',
                                          hintStyle: TextStyle(
                                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                                            fontSize: 14,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            color: isDark ? Colors.white38 : const Color(0xFF81B655),
                                            size: 22,
                                          ),
                                          suffixIcon: _searchQuery.isNotEmpty
                                              ? IconButton(
                                                  icon: Icon(
                                                    Icons.cancel_rounded,
                                                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                                                    size: 18,
                                                  ),
                                                  onPressed: () {
                                                    _debounceTimer?.cancel();
                                                    _searchCtrl.clear();
                                                    setState(() => _searchQuery = '');
                                                  },
                                                )
                                              : null,
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Segmented Filter Tabs: My Enrolled, Explore Others
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip(
                                      id: 'enrolled',
                                      label: 'My Subscribed Educators',
                                      count: enrolledEducators.length,
                                      icon: Icons.bookmark_added_rounded,
                                      isDark: isDark,
                                      highlightColor: const Color(0xFF81B655),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildFilterChip(
                                      id: 'discover',
                                      label: 'Explore Educators',
                                      count: discoverEducators.length,
                                      icon: Icons.explore_rounded,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ─── Content Sections ─────────────────────────────────────
                    if (filtered.isEmpty)
                      _buildEmptyState(
                        isDark: isDark,
                        title: 'No educators found',
                        subtitle: 'Try a different search term or clear the filter.',
                      )
                    else
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 64),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tab View: ENROLLED ONLY
                                if (_activeTab == 'enrolled') ...[
                                  if (enrolledEducators.isEmpty)
                                    _buildEmptyState(
                                      isDark: isDark,
                                      icon: Icons.school_outlined,
                                      title: 'Not subscribed to any educators yet',
                                      subtitle: 'Explore active educators below to unlock exclusive lessons and mentorship.',
                                      actionButton: ElevatedButton.icon(
                                        onPressed: () => setState(() => _activeTab = 'discover'),
                                        icon: const Icon(Icons.explore_rounded, size: 16),
                                        label: const Text('Explore Educators'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF81B655),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    )
                                  else ...[
                                    _buildSectionHeader(
                                      title: 'My Subscribed Educators',
                                      count: enrolledEducators.length,
                                      icon: Icons.bookmark_added_rounded,
                                      iconColor: const Color(0xFF81B655),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildEducatorGrid(enrolledEducators, subscribedUids, isDark),
                                  ],
                                ]
                                // Tab View: DISCOVER ONLY
                                else if (_activeTab == 'discover') ...[
                                  if (discoverEducators.isEmpty)
                                    _buildEmptyState(
                                      isDark: isDark,
                                      title: 'You are enrolled with all matching educators!',
                                      subtitle: 'Check the Subscribed Educators tab to manage your enrollments.',
                                    )
                                  else ...[
                                    _buildSectionHeader(
                                      title: 'Explore Educators',
                                      count: discoverEducators.length,
                                      icon: Icons.explore_rounded,
                                      iconColor: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildEducatorGrid(discoverEducators, subscribedUids, isDark),
                                  ],
                                ]
                                // Tab View: ALL (Separates subscribed and not-yet-subscribed into clean groups)
                                else ...[
                                  if (enrolledEducators.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      title: 'My Subscribed Educators',
                                      count: enrolledEducators.length,
                                      icon: Icons.bookmark_added_rounded,
                                      iconColor: const Color(0xFF81B655),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildEducatorGrid(enrolledEducators, subscribedUids, isDark),
                                    const SizedBox(height: 36),
                                  ],

                                  if (discoverEducators.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      title: enrolledEducators.isNotEmpty
                                          ? 'Explore Other Educators'
                                          : 'All Educators',
                                      count: discoverEducators.length,
                                      icon: Icons.explore_rounded,
                                      iconColor: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildEducatorGrid(discoverEducators, subscribedUids, isDark),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required bool isDark,
    Color? highlightColor,
  }) {
    final isSelected = _activeTab == id;
    final primaryColor = highlightColor ?? const Color(0xFF81B655);

    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? primaryColor : (isDark ? Colors.white54 : Colors.grey.shade600),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.25)
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEducatorGrid(
    List<Map<String, dynamic>> educators,
    Set<String> subscribedUids,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 640;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 320,
            childAspectRatio: isMobile ? 0.62 : 0.68,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
          ),
          itemCount: educators.length,
          itemBuilder: (context, index) {
            final educator = educators[index];
            final uid = (educator['uid'] ?? educator['id'] ?? '').toString();
            final isEnrolled = subscribedUids.contains(uid);

            return _EducatorCard(
              educator: educator,
              currentUser: widget.user,
              isDark: isDark,
              isEnrolled: isEnrolled,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required String title,
    required String subtitle,
    IconData icon = Icons.search_off_rounded,
    Widget? actionButton,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                  height: 1.45,
                ),
              ),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 18),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Educator Card ──────────────────────────────────────────────────────────

class _EducatorCard extends StatefulWidget {
  final Map<String, dynamic> educator;
  final User currentUser;
  final bool isDark;
  final bool isEnrolled;

  const _EducatorCard({
    required this.educator,
    required this.currentUser,
    required this.isDark,
    required this.isEnrolled,
  });

  @override
  State<_EducatorCard> createState() => _EducatorCardState();
}

class _EducatorCardState extends State<_EducatorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.025)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.educator['photoUrl'] as String?;
    final firstName = ((widget.educator['first_name'] ?? widget.educator['firstName']) as String?)?.trim() ?? '';
    final lastName = ((widget.educator['last_name'] ?? widget.educator['lastName']) as String?)?.trim() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final name = fullName.isNotEmpty
        ? fullName
        : ((widget.educator['full_name'] ?? widget.educator['displayName'] ?? widget.educator['username']) as String? ?? 'Educator');
    String bio = widget.educator['bio'] as String? ?? '';
    if (bio.trim().isEmpty) bio = 'Educator & Lesson Creator';

    final int reviewCount = (widget.educator['reviewCount'] as num?)?.toInt() ?? 0;
    final double rating = reviewCount > 0
        ? ((widget.educator['averageRating'] as num?)?.toDouble() ?? 0.0)
        : 0.0;
    final isDark = widget.isDark;
    final isEnrolled = widget.isEnrolled;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _ctrl.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EducatorProfilePage(
              educator: widget.educator,
              currentUser: widget.currentUser,
            ),
          ),
        ),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEnrolled
                    ? const Color(0xFF81B655).withValues(alpha: _hovered ? 0.9 : 0.45)
                    : (_hovered
                        ? const Color(0xFF81B655)
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                width: isEnrolled ? 1.6 : (_hovered ? 1.6 : 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? const Color(0xFF81B655).withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: _hovered ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Top Accent Banner ───────────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF1A3324), const Color(0xFF122419)]
                              : [const Color(0xFFEDF7E7), const Color(0xFFDCEFD0)],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      alignment: Alignment.topRight,
                      child: isEnrolled
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bookmark_added_rounded,
                                    size: 12,
                                    color: Color(0xFF81B655),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ENROLLED',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF81B655),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Overlapping Avatar
                    Positioned(
                      bottom: -26,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                            onBackgroundImageError: (photoUrl != null && photoUrl.isNotEmpty)
                                ? (err, st) {}
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 28,
                                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ─── Card Body ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Name (Clean, without verified badge icon)
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Bio
                            Text(
                              bio,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Rating & Courses Pills
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 6,
                              runSpacing: 5,
                              children: [
                                // Rating Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: reviewCount > 0
                                        ? Colors.amber.withValues(alpha: 0.12)
                                        : (isDark ? Colors.white10 : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 13,
                                        color: reviewCount > 0
                                            ? Colors.amber
                                            : (isDark ? Colors.white38 : Colors.grey.shade400),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        reviewCount > 0 && rating > 0
                                            ? rating.toStringAsFixed(1)
                                            : '0.0',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: reviewCount > 0
                                              ? (isDark ? Colors.amber.shade200 : const Color(0xFFB45309))
                                              : (isDark ? Colors.white54 : Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '($reviewCount)',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Courses Count Chip
                                StreamBuilder<List<LessonPlaylist>>(
                                  stream: DatabaseService.instance.streamPlaylistsByCreator(
                                    (widget.educator['uid'] ?? widget.educator['id'] ?? '') as String,
                                    email: widget.educator['email'] as String?,
                                  ),
                                  builder: (context, pSnap) {
                                    final pCount = pSnap.data?.length ?? 0;
                                    if (pCount == 0) return const SizedBox.shrink();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.auto_stories_rounded,
                                            size: 12,
                                            color: Color(0xFF81B655),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '$pCount ${pCount == 1 ? "Course" : "Courses"}',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF81B655),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ── Responsive CTA Button ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isEnrolled
                                  ? const Color(0xFF81B655)
                                  : (_hovered
                                      ? const Color(0xFF81B655)
                                      : const Color(0xFF81B655).withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isEnrolled
                                    ? Colors.transparent
                                    : (_hovered
                                        ? Colors.transparent
                                        : const Color(0xFF81B655).withValues(alpha: 0.35)),
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isEnrolled ? 'View Profile' : 'Enroll & View Profile',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isEnrolled || _hovered
                                          ? Colors.white
                                          : const Color(0xFF81B655),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: isEnrolled || _hovered
                                        ? Colors.white
                                        : const Color(0xFF81B655),
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }
}
