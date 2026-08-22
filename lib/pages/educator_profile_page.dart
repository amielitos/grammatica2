import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../pages/lesson_page.dart';
import '../widgets/subscription_tier_dialog.dart';
import '../widgets/paymongo_qr_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';

class EducatorProfilePage extends StatefulWidget {
  final Map<String, dynamic> educator;
  final User currentUser;

  const EducatorProfilePage({
    super.key,
    required this.educator,
    required this.currentUser,
  });

  @override
  State<EducatorProfilePage> createState() => _EducatorProfilePageState();
}

class _EducatorProfilePageState extends State<EducatorProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _starFilter; // null means "All Ratings"

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.educator['photoUrl'] as String?;
    final username = widget.educator['username'] as String? ?? 'Educator';
    final bio = widget.educator['bio'] as String? ?? 'Verified Educator & Language Specialist';
    final uid = widget.educator['uid'] as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(
        user: widget.currentUser,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.currentUser.uid),
          );
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── 1. Gradient Cover Banner & Profile Container ─────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover Image Gradient Banner
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1B2838), const Color(0xFF0F172A)]
                            : [const Color(0xFF6AAF3D), const Color(0xFF4A8A24)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -40,
                          right: -40,
                          child: CircleAvatar(
                            radius: 120,
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        Positioned(
                          bottom: -60,
                          left: 100,
                          child: CircleAvatar(
                            radius: 100,
                            backgroundColor: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                        // Back Button inside Cover Banner
                        Positioned(
                          top: 20,
                          left: 24,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Back',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Profile Info Box
                  Container(
                    margin: const EdgeInsets.only(top: 130),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.06),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 700;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Overlapping Avatar + Name + Action Buttons
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Avatar with prominent ring
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: cardBg,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: isWide ? 44 : 34,
                                            backgroundColor: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFF1F5F9),
                                            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                                ? NetworkImage(photoUrl)
                                                : null,
                                            child: (photoUrl == null || photoUrl.isEmpty)
                                                ? Icon(
                                                    Icons.person_rounded,
                                                    size: isWide ? 44 : 34,
                                                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 18),

                                        // Name & Bio
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      username,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: isWide ? 26 : 20,
                                                        fontWeight: FontWeight.w900,
                                                        color: textColor,
                                                        letterSpacing: -0.5,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF81B655),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.check_rounded,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                bio,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13.5,
                                                  color: subtitleColor,
                                                  height: 1.4,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Desktop Action Buttons
                                        if (isWide) ...[
                                          const SizedBox(width: 16),
                                          _buildHeaderActions(uid, username, isDark, textColor, borderColor),
                                        ],
                                      ],
                                    ),

                                    // Mobile Action Buttons
                                    if (!isWide) ...[
                                      const SizedBox(height: 20),
                                      _buildHeaderActions(uid, username, isDark, textColor, borderColor),
                                    ],

                                    const SizedBox(height: 24),
                                    Divider(color: borderColor, height: 1),
                                    const SizedBox(height: 20),

                                    // Row 2: Stats Row
                                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final data = snapshot.data?.data() ?? widget.educator;
                                        final avgRating = (data['averageRating'] ?? 5.0).toDouble();

                                        return StreamBuilder<Map<String, int>>(
                                          stream: DatabaseService.instance.getTieredSubscriberCounts(uid),
                                          builder: (context, subSnapshot) {
                                            final counts = subSnapshot.data ??
                                                {'Basic': 0, 'Standard': 0, 'Premium': 0};

                                            return Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildStatItem('Viewers', '${counts['Basic']}', Icons.remove_red_eye_rounded, const Color(0xFF3B82F6), isDark, textColor, subtitleColor),
                                                _buildVerticalDivider(borderColor),
                                                _buildStatItem('Subscribers', '${counts['Standard']}', Icons.people_rounded, const Color(0xFF81B655), isDark, textColor, subtitleColor),
                                                _buildVerticalDivider(borderColor),
                                                _buildStatItem('Mentors', '${counts['Premium']}', Icons.school_rounded, const Color(0xFF8B5CF6), isDark, textColor, subtitleColor),
                                                _buildVerticalDivider(borderColor),
                                                _buildStatItem('Rating', avgRating.toStringAsFixed(1), Icons.star_rounded, Colors.amber, isDark, textColor, subtitleColor),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── 2. Segmented Tab Switcher & Body Content ──────────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Tab Selector Pills
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: const Color(0xFF81B655),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                            labelStyle: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            unselectedLabelStyle: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_stories_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Public Content'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.star_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Ratings & Reviews'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tab Views
                        SizedBox(
                          height: 600,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // ── Tab 1: Public Content ──────────────────────
                              _buildPublicContentTab(
                                uid,
                                widget.currentUser,
                                isDark,
                                cardBg,
                                borderColor,
                                textColor,
                                subtitleColor,
                              ),

                              // ── Tab 2: Ratings & Reviews ────────────────────
                              _buildReviewsTab(
                                uid,
                                isDark,
                                cardBg,
                                borderColor,
                                textColor,
                                subtitleColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActions(
    String uid,
    String username,
    bool isDark,
    Color textColor,
    Color borderColor,
  ) {
    return StreamBuilder<bool>(
      stream: DatabaseService.instance.isSubscribedStream(uid),
      builder: (context, subSnap) {
        final isSubscribed = subSnap.data ?? false;
        return Row(
          children: [
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: isSubscribed
                    ? () => DatabaseService.instance.unsubscribeFromEducator(uid)
                    : () async {
                        final tier = await showDialog<String>(
                          context: context,
                          builder: (context) => SubscriptionTierDialog(
                            pricing: widget.educator['subscription_pricing'],
                            educatorName: username,
                          ),
                        );
                        if (tier != null) {
                          if (tier == 'Basic') {
                            await DatabaseService.instance.subscribeToEducator(uid, tier);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Subscribed to Free Tier.')),
                              );
                            }
                          } else {
                            final pricingData = widget.educator['subscription_pricing'] ?? {};
                            double amountInUSD = tier == 'Standard'
                                ? (pricingData['standard']?.toDouble() ?? 3.0)
                                : (pricingData['premium']?.toDouble() ?? 7.0);
                            double amountInPhp = amountInUSD * 56.0;
                            if (!context.mounted) return;
                            final success = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => PaymongoQrDialog(
                                tier: tier,
                                amount: amountInPhp,
                                educatorName: username,
                              ),
                            );
                            if (success == true) {
                              await DatabaseService.instance.subscribeToEducator(uid, tier);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Payment Successful! Subscribed to $tier.')),
                                );
                              }
                            }
                          }
                        }
                      },
                icon: Icon(
                  isSubscribed ? Icons.check_circle_rounded : Icons.star_rounded,
                  size: 16,
                ),
                label: Text(
                  isSubscribed ? 'Subscribed' : 'Subscribe',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSubscribed
                      ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                      : const Color(0xFF81B655),
                  foregroundColor: isSubscribed
                      ? (isDark ? Colors.white54 : const Color(0xFF64748B))
                      : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: isSubscribed
                    ? () => _showReviewDialog(context, uid, isDark)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Subscribe to leave a review')),
                        ),
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: Text(
                  'Review',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: subtitleColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(Color borderColor) {
    return Container(
      height: 32,
      width: 1,
      color: borderColor,
    );
  }

  // ── Public Content Tab View ───────────────────────────────────────────────

  Widget _buildPublicContentTab(
    String uid,
    User currentUser,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamEducatorLessons(uid, publicOnly: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final lessons = snapshot.data ?? [];
        if (lessons.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined, size: 48, color: subtitleColor),
                const SizedBox(height: 12),
                Text(
                  'No public lessons published yet',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            childAspectRatio: 1.15,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: lessons.length,
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81B655).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'LESSON',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF81B655),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Icon(Icons.book_rounded, color: const Color(0xFF81B655), size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lesson.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonPage(user: currentUser, lesson: lesson),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Start Lesson',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
    );
  }

  // ── Ratings & Reviews Tab View ────────────────────────────────────────────

  Widget _buildReviewsTab(
    String uid,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<Review>>(
      stream: DatabaseService.instance.streamReviews(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allReviews = snapshot.data ?? [];
        final reviews = _starFilter == null
            ? allReviews
            : allReviews.where((r) => r.rating.toInt() == _starFilter).toList();

        if (allReviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_outline_rounded, size: 48, color: subtitleColor),
                const SizedBox(height: 12),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Filter Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${reviews.length} ${reviews.length == 1 ? 'Review' : 'Reviews'}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _starFilter,
                      hint: Text('All Stars', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                      dropdownColor: cardBg,
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                      onChanged: (val) => setState(() => _starFilter = val),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Stars')),
                        const DropdownMenuItem(value: 5, child: Text('5 Stars')),
                        const DropdownMenuItem(value: 4, child: Text('4 Stars')),
                        const DropdownMenuItem(value: 3, child: Text('3 Stars')),
                        const DropdownMenuItem(value: 2, child: Text('2 Stars')),
                        const DropdownMenuItem(value: 1, child: Text('1 Star')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Review List
            Expanded(
              child: ListView.separated(
                itemCount: reviews.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              child: Icon(Icons.person_rounded, size: 20, color: isDark ? Colors.white38 : Colors.grey.shade400),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.reviewerName,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  if (review.createdAt != null)
                                    Text(
                                      _formatDate(review.createdAt!),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: subtitleColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          review.comment,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: subtitleColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  void _showReviewDialog(BuildContext context, String educatorUid, bool isDark) {
    double selectedRating = 0.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Leave a Review',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Share your experience with this educator',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedRating = index + 1.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: index < selectedRating ? Colors.amber : (isDark ? Colors.white24 : Colors.grey.shade300),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF81B655),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            ),
                            foregroundColor: isDark ? Colors.white54 : Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final review = Review(
                              id: '',
                              reviewerUid: widget.currentUser.uid,
                              reviewerName: widget.currentUser.displayName ?? 'Learner',
                              rating: selectedRating,
                              comment: commentController.text,
                            );
                            await DatabaseService.instance.addReview(educatorUid, review);
                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Review submitted!')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF81B655),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Submit', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
