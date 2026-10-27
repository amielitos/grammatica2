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

  @override
  void initState() {
    super.initState();
    _educatorsStream = DatabaseService.instance.streamEducators();
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
      child: StreamBuilder<List<Map<String, dynamic>>>(
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

          return SingleChildScrollView(
            child: Column(
              children: [
                // ─── Hero Header & Search Bar ─────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
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
                                  'ENROLLMENT',
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
                          const SizedBox(height: 14),
                          Text(
                            'Browse Educators',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.15,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enroll with verified educators for exclusive lessons, structured courses, and personalized mentorship.',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Search Bar
                          Container(
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
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) {
                                _debounceTimer?.cancel();
                                _debounceTimer = Timer(const Duration(milliseconds: 350), () {
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
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Grid / Empty State ───────────────────────────────────────
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No educators found',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try a different search term',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 64),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          childAspectRatio: MediaQuery.of(context).size.width <= 600 ? 0.54 : 0.63,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final educator = filtered[index];
                          return _EducatorCard(
                            educator: educator,
                            currentUser: widget.user,
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Educator Card ──────────────────────────────────────────────────────────

class _EducatorCard extends StatefulWidget {
  final Map<String, dynamic> educator;
  final User currentUser;
  final bool isDark;

  const _EducatorCard({
    required this.educator,
    required this.currentUser,
    required this.isDark,
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
    final isMobile = MediaQuery.of(context).size.width <= 600;
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
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _hovered
                    ? const Color(0xFF81B655)
                    : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                width: _hovered ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? const Color(0xFF81B655).withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: _hovered ? 24 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Card Top Accent Banner ──────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF1E3A2B), const Color(0xFF142E20)]
                              : [const Color(0xFFEAF5E4), const Color(0xFFD8ECCB)],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF81B655).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: Color(0xFF81B655),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF81B655),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Overlapping Avatar
                    Positioned(
                      bottom: -28,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: isMobile ? 30 : 34,
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
                                    size: isMobile ? 28 : 32,
                                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 34),

                // ─── Card Body ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Name ───────────────────────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile ? 15 : 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 15,
                                  color: Color(0xFF81B655),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // ── Bio ────────────────────────────────────────────────
                            Text(
                              bio,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 11 : 12,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ── Rating & Playlists Pills Row ──────────────────────
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // Rating Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: reviewCount > 0
                                        ? Colors.amber.withValues(alpha: 0.12)
                                        : (isDark ? Colors.white10 : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 14,
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
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: reviewCount > 0
                                              ? (isDark ? Colors.amber.shade200 : const Color(0xFFB45309))
                                              : (isDark ? Colors.white54 : Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        reviewCount > 0 ? '($reviewCount)' : '(0)',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Playlist Count Chip
                                StreamBuilder<List<LessonPlaylist>>(
                                  stream: DatabaseService.instance.streamPlaylistsByCreator(
                                    (widget.educator['uid'] ?? widget.educator['id'] ?? '') as String,
                                    email: widget.educator['email'] as String?,
                                  ),
                                  builder: (context, pSnap) {
                                    final pCount = pSnap.data?.length ?? 0;
                                    if (pCount == 0) return const SizedBox.shrink();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF81B655).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.auto_stories_rounded,
                                            size: 13,
                                            color: Color(0xFF81B655),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$pCount ${pCount == 1 ? "Course" : "Courses"}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
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

                        const SizedBox(height: 12),

                        // ── Responsive CTA Button ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? const Color(0xFF81B655)
                                  : const Color(0xFF81B655).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _hovered
                                    ? Colors.transparent
                                    : const Color(0xFF81B655).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Enroll & View Profile',
                                        style: GoogleFonts.outfit(
                                          fontSize: isMobile ? 12 : 13,
                                          fontWeight: FontWeight.w700,
                                          color: _hovered
                                              ? Colors.white
                                              : const Color(0xFF81B655),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: _hovered
                                            ? Colors.white
                                            : const Color(0xFF81B655),
                                      ),
                                    ],
                                  ),
                                ),
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

