import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/navigation_service.dart';
import '../widgets/subscription_tier_dialog.dart';
import '../widgets/paymongo_qr_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/universal_drawer.dart';
import '../services/agora_service.dart';
import '../services/email_sender_service.dart';
import '../services/paymongo_service.dart';
import '../services/idempotency_service.dart';
import 'conference_page.dart';
import '../models/playlist.dart';
import '../widgets/playlist_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/center_notice_dialog.dart';

class EducatorProfilePage extends StatefulWidget {
  final Map<String, dynamic> educator;
  final User currentUser;
  final int initialTab;

  const EducatorProfilePage({
    super.key,
    required this.educator,
    required this.currentUser,
    this.initialTab = 0,
  });

  @override
  State<EducatorProfilePage> createState() => _EducatorProfilePageState();
}

class _EducatorProfilePageState extends State<EducatorProfilePage> {
  late int _selectedTab; // 0 = Lessons, 1 = Playlists, 2 = Reviews
  int? _starFilter; // null means "All Ratings"
  bool _mentorshipSortNewestFirst = false;
  int _mentorshipPage = 1;
  static const int _mentorshipPageSize = 3;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 2);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.educator['photoUrl'] as String?;
    final firstName = ((widget.educator['first_name'] ?? widget.educator['firstName']) as String?)?.trim() ?? '';
    final lastName = ((widget.educator['last_name'] ?? widget.educator['lastName']) as String?)?.trim() ?? '';
    final computedFullName = '$firstName $lastName'.trim();
    final username = computedFullName.isNotEmpty
        ? computedFullName
        : ((widget.educator['full_name'] ?? widget.educator['displayName'] ?? widget.educator['username']) as String? ?? 'Educator');
    final bio = widget.educator['bio'] as String? ?? 'Verified Educator & Language Specialist';
    final uid = (widget.educator['uid'] ?? widget.educator['id'] ?? '') as String;
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
        showBackButton: true,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.currentUser.uid),
          );
        },
      ),
      drawer: UniversalDrawer(
        user: widget.currentUser,
        userData: const {},
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
                                        final int reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
                                        final avgRating = reviewCount > 0 
                                            ? ((data['averageRating'] as num?)?.toDouble() ?? 0.0) 
                                            : 0.0;

                                        return StreamBuilder<Map<String, int>>(
                                          stream: DatabaseService.instance.getTieredSubscriberCounts(uid),
                                          builder: (context, subSnapshot) {
                                            final counts = subSnapshot.data ??
                                                {'Basic': 0, 'Standard': 0, 'Premium': 0};

                                            return StreamBuilder<List<LessonPlaylist>>(
                                              stream: DatabaseService.instance.streamPlaylistsByCreator(
                                                uid,
                                                email: widget.educator['email'] as String?,
                                              ),
                                              builder: (context, pSnap) {
                                                final pCount = pSnap.data?.length ?? 0;

                                                return Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                  children: [
                                                    _buildStatItem('Viewers', '${counts['Basic']}', Icons.remove_red_eye_rounded, const Color(0xFF3B82F6), isDark, textColor, subtitleColor),
                                                    _buildVerticalDivider(borderColor),
                                                    _buildStatItem('Enrolled', '${counts['Standard']}', Icons.people_rounded, const Color(0xFF81B655), isDark, textColor, subtitleColor),
                                                    _buildVerticalDivider(borderColor),
                                                    _buildStatItem(
                                                      'Playlists',
                                                      '$pCount',
                                                      Icons.playlist_play_rounded,
                                                      const Color(0xFF10B981),
                                                      isDark,
                                                      textColor,
                                                      subtitleColor,
                                                      onTap: () => setState(() => _selectedTab = 1),
                                                    ),
                                                    _buildVerticalDivider(borderColor),
                                                    _buildStatItem(
                                                      'Rating',
                                                      avgRating.toStringAsFixed(1),
                                                      Icons.star_rounded,
                                                      Colors.amber,
                                                      isDark,
                                                      textColor,
                                                      subtitleColor,
                                                      onTap: () => setState(() => _selectedTab = 2),
                                                    ),
                                                  ],
                                                );
                                              },
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
                        _buildMentorshipBanner(uid, isDark, cardBg, borderColor, textColor, subtitleColor),
                        StreamBuilder<bool>(
                          stream: DatabaseService.instance.isSubscribedStream(uid),
                          builder: (context, subSnap) {
                            final isSubscribed = subSnap.data ?? false;
                            final canViewMembers = isSubscribed || widget.currentUser.uid == uid;

                            return StreamBuilder<List<Lesson>>(
                              stream: DatabaseService.instance.streamEducatorLessons(uid, publicOnly: false),
                              builder: (context, lessonSnap) {
                                final lessons = lessonSnap.data ?? [];
                                final educatorEmail = widget.educator['email'] as String?;

                                return StreamBuilder<List<LessonPlaylist>>(
                                  stream: DatabaseService.instance.streamPlaylistsByCreator(uid, email: educatorEmail),
                                  builder: (context, playlistSnap) {
                                    final playlists = playlistSnap.data ?? [];

                                    return Column(
                                      children: [
                                        // Tab Selector Pills
                                        _buildTabPillBar(
                                          isDark: isDark,
                                          textColor: textColor,
                                          lessonsCount: lessons.length,
                                          playlistsCount: playlists.length,
                                          uid: uid,
                                        ),
                                        const SizedBox(height: 24),

                                        // Tab Views
                                        if (_selectedTab == 0)
                                          _buildLessonsTab(
                                            lessons,
                                            lessonSnap.connectionState == ConnectionState.waiting,
                                            isDark,
                                            cardBg,
                                            borderColor,
                                            textColor,
                                            subtitleColor,
                                            canViewMembers: canViewMembers,
                                          )
                                        else if (_selectedTab == 1)
                                          _buildPlaylistsTab(
                                            playlists,
                                            playlistSnap.connectionState == ConnectionState.waiting,
                                            isDark,
                                            cardBg,
                                            borderColor,
                                            textColor,
                                            subtitleColor,
                                          )
                                        else
                                          _buildReviewsTab(
                                            uid,
                                            isDark,
                                            cardBg,
                                            borderColor,
                                            textColor,
                                            subtitleColor,
                                          ),
                                        const SizedBox(height: 48),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
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
    );
  }

  Future<void> _handleSubscriptionOrUpgrade(
    BuildContext context,
    String uid,
    String username,
    String? currentTier,
  ) async {
    final tier = await showDialog<String>(
      context: context,
      builder: (context) => SubscriptionTierDialog(
        pricing: widget.educator['subscription_pricing'],
        educatorName: username,
        currentTier: currentTier,
      ),
    );
    if (tier != null) {
      if (tier == 'Basic') {
        await DatabaseService.instance.subscribeToEducator(uid, tier);
        if (context.mounted) {
          CenterNoticeDialog.show(
            context,
            title: 'Enrollment Activated',
            message: 'You have enrolled in the Free Tier.',
            isSuccess: true,
          );
        }
      } else {
        final pricingData = widget.educator['subscription_pricing'] ?? {};
        double amountInUSD = tier == 'Standard'
            ? (pricingData['standard']?.toDouble() ?? 3.0)
            : (pricingData['premium']?.toDouble() ?? 7.0);
        double amountInPhp = amountInUSD * 56.0;
        if (!context.mounted) return;
        final paymentIdempotencyKey =
            IdempotencyService.instance.generatePaymentKey(
          learnerUid: widget.currentUser.uid,
          educatorUid: uid,
          tier: tier,
        );

        final paymentResult = await showDialog<PaymongoPaymentResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PaymongoQrDialog(
            tier: tier,
            amount: amountInPhp,
            educatorName: username,
            learnerName: widget.currentUser.displayName ?? 'Learner',
            learnerEmail: widget.currentUser.email,
            idempotencyKey: paymentIdempotencyKey,
          ),
        );
        if (paymentResult != null && paymentResult.isSuccess) {
          final recordResult = await DatabaseService.instance
              .recordSubscriptionPayment(
            educatorUid: uid,
            educatorName: username,
            tier: tier,
            amount: amountInPhp,
            referenceNumber: paymentResult.referenceNumber,
            paymentMethod: paymentResult.paymentMethod,
            paymongoLinkId: paymentResult.linkId,
            idempotencyKey: paymentResult.idempotencyKey ?? paymentIdempotencyKey,
          );

          final userEmail = widget.currentUser.email;
          if (!recordResult.isDuplicate &&
              userEmail != null &&
              userEmail.isNotEmpty) {
            EmailSenderService.sendSubscriptionPaymentReceiptEmail(
              recipientEmail: userEmail,
              recipientName: widget.currentUser.displayName ?? 'Learner',
              educatorName: username,
              tier: tier,
              amount: amountInPhp,
              referenceNumber: paymentResult.referenceNumber,
              paymentMethod: paymentResult.paymentMethod,
              paymentDate: paymentResult.paidAt,
            );
          }

          if (context.mounted) {
            CenterNoticeDialog.show(
              context,
              title: currentTier != null ? 'Plan Upgraded!' : 'Enrollment Successful!',
              message: recordResult.isDuplicate
                  ? 'Enrollment in $tier is already active!'
                  : 'Payment Successful! You are now enrolled in $tier. Receipt sent to ${userEmail ?? "your email"}.',
              isSuccess: true,
            );
          }
        }
      }
    }
  }

  Widget _buildHeaderActions(
    String uid,
    String username,
    bool isDark,
    Color textColor,
    Color borderColor,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.uid)
          .collection('subscriptions')
          .doc(uid)
          .snapshots(),
      builder: (context, subSnap) {
        final docData = subSnap.data?.data();
        final isSubscribed = subSnap.data?.exists == true && docData?['status'] == 'active';
        final currentTier = isSubscribed ? (docData?['tier'] as String? ?? 'Basic') : null;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _handleSubscriptionOrUpgrade(context, uid, username, currentTier),
                icon: Icon(
                  isSubscribed ? Icons.arrow_circle_up_rounded : Icons.star_rounded,
                  size: 16,
                ),
                label: Text(
                  isSubscribed ? 'Upgrade' : 'Enroll',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81B655),
                  foregroundColor: Colors.white,
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
                    ? () async {
                        final subscribedAt = (docData?['subscribedAt'] as Timestamp?)?.toDate();
                        if (subscribedAt == null) {
                          if (context.mounted) {
                            CenterNoticeDialog.show(
                              context,
                              title: 'Review Notice',
                              message: 'You must be enrolled for at least 7 days before leaving a review.',
                              isSuccess: false,
                            );
                          }
                          return;
                        }
                        final daysSubscribed = DateTime.now().difference(subscribedAt).inDays;
                        if (daysSubscribed < 7) {
                          final daysLeft = 7 - daysSubscribed;
                          if (context.mounted) {
                            CenterNoticeDialog.show(
                              context,
                              title: 'Review Notice',
                              message: 'You can leave a review after 7 days of enrollment ($daysLeft day${daysLeft > 1 ? 's' : ''} remaining).',
                              isSuccess: false,
                            );
                          }
                          return;
                        }
                        if (context.mounted) {
                          _showReviewDialog(context, uid, isDark);
                        }
                      }
                    : () => CenterNoticeDialog.show(
                          context,
                          title: 'Enrollment Required',
                          message: 'Please enroll with this educator first to leave a review.',
                          isSuccess: false,
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
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _selectedTab = 1),
                icon: const Icon(Icons.playlist_play_rounded, size: 18, color: Color(0xFF81B655)),
                label: Text(
                  'Playlists',
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
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _showEducatorCalendarDialog(context, uid, username, isSubscribed),
                icon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF81B655)),
                label: Text(
                  'View Calendar',
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
    Color subtitleColor, {
    VoidCallback? onTap,
  }) {
    final item = Column(
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

    if (onTap == null) return item;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: item,
      ),
    );
  }

  Widget _buildVerticalDivider(Color borderColor) {
    return Container(
      height: 32,
      width: 1,
      color: borderColor,
    );
  }

  // ── Tab Bar & Content Views ───────────────────────────────────────────────

  Widget _buildTabPillBar({
    required bool isDark,
    required Color textColor,
    required int lessonsCount,
    required int playlistsCount,
    required String uid,
  }) {
    Widget buildTabPill(String label, IconData icon, int index, int count) {
      final isSel = _selectedTab == index;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF81B655) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: const Color(0xFF81B655).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Text(
                  '$label ($count)',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<Review>>(
      stream: DatabaseService.instance.streamReviews(uid),
      builder: (context, rSnap) {
        final reviewCount = rSnap.data?.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              buildTabPill('Lessons', Icons.auto_stories_rounded, 0, lessonsCount),
              buildTabPill('Playlists', Icons.playlist_play_rounded, 1, playlistsCount),
              buildTabPill('Reviews', Icons.star_rounded, 2, reviewCount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLessonsTab(
    List<Lesson> lessons,
    bool isLoading,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor, {
    required bool canViewMembers,
  }) {
    if (isLoading && lessons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final publicLessons = lessons.where((l) => !l.isMembersOnly).toList();
    final membersLessons = lessons.where((l) => l.isMembersOnly).toList();

    if (lessons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_outlined, size: 48, color: subtitleColor),
              const SizedBox(height: 12),
              Text(
                'No lessons published yet',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildLessonCard(Lesson lesson, bool isMembersOnly) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMembersOnly
                ? const Color(0xFF9B59B6).withValues(alpha: 0.4)
                : borderColor,
            width: isMembersOnly ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isMembersOnly
                  ? const Color(0xFF9B59B6).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
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
                    color: isMembersOnly
                        ? const Color(0xFF9B59B6).withValues(alpha: 0.15)
                        : const Color(0xFF81B655).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMembersOnly) ...[
                        const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF9B59B6)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isMembersOnly ? 'MEMBERS ONLY' : 'PUBLIC LESSON',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isMembersOnly ? const Color(0xFF9B59B6) : const Color(0xFF81B655),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isMembersOnly ? Icons.stars_rounded : Icons.book_rounded,
                  color: isMembersOnly ? const Color(0xFF9B59B6) : const Color(0xFF81B655),
                  size: 20,
                ),
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
                onPressed: () {
                  if (isMembersOnly && !canViewMembers) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(
                          children: const [
                            Icon(Icons.lock_rounded, color: Color(0xFF9B59B6)),
                            SizedBox(width: 8),
                            Text('Members-Only Lesson'),
                          ],
                        ),
                        content: Text(
                          'This lesson "${lesson.title}" is exclusively available to enrolled learners of ${widget.educator['username'] ?? 'this educator'}. Please enroll to unlock.',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  NavigationService.instance.goToLesson(context, lesson);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMembersOnly
                      ? (canViewMembers ? const Color(0xFF9B59B6) : const Color(0xFF6B7280))
                      : const Color(0xFF81B655),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isMembersOnly && !canViewMembers) ...[
                      const Icon(Icons.lock_rounded, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isMembersOnly
                          ? (canViewMembers ? 'Start Member Lesson' : 'Members Only (Locked)')
                          : 'Start Lesson',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section 1: Public Lessons ──────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF81B655).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.public_rounded, size: 18, color: Color(0xFF81B655)),
            ),
            const SizedBox(width: 10),
            Text(
              'Public Lessons',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${publicLessons.length}',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (publicLessons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No public lessons published yet.',
              style: GoogleFonts.inter(fontSize: 13.5, color: subtitleColor),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 245,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: publicLessons.length,
            itemBuilder: (context, index) => buildLessonCard(publicLessons[index], false),
          ),

        const SizedBox(height: 36),

        // ── Section 2: Members-Only Lessons ────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.stars_rounded, size: 18, color: Color(0xFF9B59B6)),
            ),
            const SizedBox(width: 10),
            Text(
              'Members-Only Lessons',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${membersLessons.length}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9B59B6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'EXCLUSIVE',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9B59B6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (membersLessons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No members-only lessons uploaded yet.',
              style: GoogleFonts.inter(fontSize: 13.5, color: subtitleColor),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 245,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: membersLessons.length,
            itemBuilder: (context, index) => buildLessonCard(membersLessons[index], true),
          ),
      ],
    );
  }

  Widget _buildPlaylistsTab(
    List<LessonPlaylist> playlists,
    bool isLoading,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    if (isLoading && playlists.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF81B655).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.playlist_play_rounded,
                  size: 52,
                  color: Color(0xFF81B655),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No playlists published yet',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This educator has not created sequential lesson playlists yet.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isNarrow ? 1 : 2,
            mainAxisExtent: 185,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return PlaylistCard(
              playlist: playlist,
              isDark: isDark,
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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

  Widget _buildMentorshipBanner(
    String educatorUid,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamStudentMentorshipSessions(widget.currentUser.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final eduSessions = snapshot.data!.where((s) =>
          s['educatorId'] == educatorUid &&
          (s['status'] ?? 'scheduled').toString().toLowerCase() != 'cancelled'
        ).toList()
          ..sort((a, b) {
            final ta = (a['startTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final tb = (b['startTime'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return _mentorshipSortNewestFirst ? tb.compareTo(ta) : ta.compareTo(tb);
          });

        if (eduSessions.isEmpty) return const SizedBox.shrink();

        final totalSessions = eduSessions.length;
        final maxPage = (totalSessions / _mentorshipPageSize).ceil().clamp(1, 9999);
        if (_mentorshipPage > maxPage) _mentorshipPage = maxPage;
        final startIndex = (_mentorshipPage - 1) * _mentorshipPageSize;
        final pageSessions = eduSessions.skip(startIndex).take(_mentorshipPageSize).toList();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.08 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.video_call_rounded, color: Color(0xFF3B82F6), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scheduled Mentorship Session ($totalSessions)',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: _mentorshipSortNewestFirst
                        ? 'Sorted by Date (Newest first)'
                        : 'Sorted by Date (Chronological)',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _mentorshipSortNewestFirst = !_mentorshipSortNewestFirst;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _mentorshipSortNewestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              size: 13,
                              color: const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _mentorshipSortNewestFirst ? 'Newest Date' : 'By Date',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...pageSessions.map((s) {
                final title = s['meetingTitle'] as String? ?? 'Mentorship Meeting';
                final app = s['conferenceApp'] as String? ?? 'agora';
                final startTime = (s['startTime'] as Timestamp?)?.toDate();
                final endTime = (s['endTime'] as Timestamp?)?.toDate();
                final dateStr = startTime != null ? DateFormat('EEE, MMM d, yyyy').format(startTime) : '';
                final timeStr = (startTime != null && endTime != null)
                    ? '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}'
                    : '';
                final isPast = (endTime ?? startTime)?.isBefore(DateTime.now()) ?? false;

                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title.isNotEmpty ? title : 'Mentorship Consultation',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          _buildConferenceBadge(app),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: isPast ? subtitleColor : const Color(0xFF81B655)),
                          const SizedBox(width: 6),
                          Text(
                            '$dateStr  •  $timeStr',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isPast) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Ended',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isPast) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.video_call_rounded, size: 16),
                            label: Text(
                              'Join',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF81B655),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              final agoraChannel = s['agoraChannel'] as String? ?? '';
                              final sessionId = s['id'] as String? ?? '';
                              final channel = agoraChannel.isNotEmpty
                                  ? agoraChannel
                                  : AgoraService.instance.channelFromSessionId(
                                      sessionId.isNotEmpty ? sessionId : 'session',
                                    );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConferencePage(
                                    channelName: channel,
                                    sessionId: sessionId,
                                    sessionTitle: title.isNotEmpty ? title : 'Mentorship Session',
                                    otherParticipantName: widget.educator['username'] as String? ?? 'Educator',
                                    isHost: false,
                                    currentUser: widget.currentUser,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (totalSessions > _mentorshipPageSize) ...[
                const SizedBox(height: 16),
                PaginationBar(
                  currentPage: _mentorshipPage,
                  totalItems: totalSessions,
                  pageSize: _mentorshipPageSize,
                  itemName: 'sessions',
                  onPageChanged: (newPage) {
                    setState(() => _mentorshipPage = newPage);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildConferenceBadge(String app) {
    final normApp = app.toLowerCase();
    String name;
    Color bg;
    IconData icon;

    if (normApp.contains('zoom')) {
      name = 'Zoom';
      bg = const Color(0xFF2D8CFF);
      icon = Icons.videocam_rounded;
    } else if (normApp.contains('team')) {
      name = 'MS Teams';
      bg = const Color(0xFF5B5FC7);
      icon = Icons.groups_rounded;
    } else {
      name = 'Meet';
      bg = const Color(0xFF81B655);
      icon = Icons.video_call_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: bg),
          const SizedBox(width: 4),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: bg,
            ),
          ),
        ],
      ),
    );
  }

  void _showEducatorCalendarDialog(
    BuildContext context,
    String educatorUid,
    String educatorName,
    bool isSubscribed,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _EducatorMentorshipCalendarDialog(
        currentUser: widget.currentUser,
        educatorUid: educatorUid,
        educatorName: educatorName,
        isSubscribed: isSubscribed,
        onSubscribeTapped: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please tap "Enroll" above to unlock mentorship reservations!'),
              backgroundColor: Color(0xFF81B655),
            ),
          );
        },
      ),
    );
  }
}

class _EducatorMentorshipCalendarDialog extends StatefulWidget {
  final User currentUser;
  final String educatorUid;
  final String educatorName;
  final bool isSubscribed;
  final VoidCallback onSubscribeTapped;

  const _EducatorMentorshipCalendarDialog({
    required this.currentUser,
    required this.educatorUid,
    required this.educatorName,
    required this.isSubscribed,
    required this.onSubscribeTapped,
  });

  @override
  State<_EducatorMentorshipCalendarDialog> createState() =>
      _EducatorMentorshipCalendarDialogState();
}

class _EducatorMentorshipCalendarDialogState
    extends State<_EducatorMentorshipCalendarDialog> {
  DateTime _selectedDay = DateTime.now();
  String? _reservingSlotId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF81B655).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: Color(0xFF81B655), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.educatorName}\'s Mentorship Calendar',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '1-on-1 Mentorship Sessions • 1h 30m each',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date picker / selector row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        DateFormat('EEE, MMM d, yyyy').format(_selectedDay),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDay,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) setState(() => _selectedDay = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => setState(() => _selectedDay = DateTime.now()),
                    child: const Text('Today'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Availability stream
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: DatabaseService.instance
                    .streamEducatorAvailability(widget.educatorUid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final allSlots = snapshot.data ?? [];
                  if (allSlots.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_rounded,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No mentorship slots available at this time.',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check back later as the educator updates their schedule.',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter slots for selected day
                  final daySlots = allSlots.where((s) {
                    final start = (s['startTime'] as Timestamp?)?.toDate();
                    if (start == null) return false;
                    return start.year == _selectedDay.year &&
                        start.month == _selectedDay.month &&
                        start.day == _selectedDay.day;
                  }).toList()
                    ..sort((a, b) {
                      final ta = (a['startTime'] as Timestamp).toDate();
                      final tb = (b['startTime'] as Timestamp).toDate();
                      return ta.compareTo(tb);
                    });

                  if (daySlots.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.event_note_rounded,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No slots open on ${DateFormat('MMMM d, yyyy').format(_selectedDay)}.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select another date above to view upcoming slots.',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: daySlots.map((slot) {
                      final slotId = slot['id']?.toString() ?? '';
                      final start = (slot['startTime'] as Timestamp).toDate();
                      final end = (slot['endTime'] as Timestamp?)?.toDate() ??
                          start.add(const Duration(minutes: 90));
                      final timeStr =
                          '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
                      final isBooked = slot['isBooked'] == true;
                      final isBookedByMe =
                          isBooked && slot['bookedByUid'] == widget.currentUser.uid;
                      final isReservingThis = _reservingSlotId == slotId;
                      final title =
                          slot['title']?.toString() ?? '1-on-1 Mentorship';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isBookedByMe
                                ? const Color(0xFF81B655)
                                : (isBooked
                                    ? Colors.grey.withValues(alpha: 0.3)
                                    : const Color(0xFF81B655).withValues(alpha: 0.5)),
                            width: isBookedByMe ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isBooked
                                    ? (isBookedByMe
                                        ? const Color(0xFF81B655).withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15))
                                    : const Color(0xFF81B655).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isBooked
                                    ? (isBookedByMe
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_rounded)
                                    : Icons.access_time_rounded,
                                color: isBooked
                                    ? (isBookedByMe
                                        ? const Color(0xFF81B655)
                                        : Colors.grey)
                                    : const Color(0xFF81B655),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        timeStr,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isBooked
                                              ? (isBookedByMe
                                                  ? const Color(0xFF81B655).withValues(alpha: 0.15)
                                                  : Colors.grey.withValues(alpha: 0.2))
                                              : const Color(0xFF81B655).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isBooked
                                              ? (isBookedByMe ? 'BOOKED BY YOU' : 'BOOKED')
                                              : 'AVAILABLE (1h 30m)',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isBooked
                                                ? (isBookedByMe
                                                    ? const Color(0xFF81B655)
                                                    : Colors.grey)
                                                : const Color(0xFF81B655),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Action Button
                            if (!isBooked) ...[
                              if (widget.isSubscribed)
                                ElevatedButton.icon(
                                  icon: isReservingThis
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.bookmark_add_rounded,
                                          size: 16),
                                  label: Text(
                                    isReservingThis ? 'Reserving...' : 'Reserve Slot',
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF81B655),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: isReservingThis
                                      ? null
                                      : () => _handleReserveSlot(slotId, title),
                                )
                              else
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.star_rounded, size: 16),
                                  label: Text(
                                    'Enroll to Reserve',
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: widget.onSubscribeTapped,
                                ),
                            ] else if (isBookedByMe) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF81B655).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Confirmed ✓',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF81B655),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Unavailable',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _handleReserveSlot(String slotId, String title) async {
    setState(() => _reservingSlotId = slotId);
    try {
      await DatabaseService.instance.reserveMentorshipSlot(
        slotId: slotId,
        learner: widget.currentUser,
        educatorId: widget.educatorUid,
        educatorName: widget.educatorName,
        meetingTitle: title,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Slot reserved successfully! 1h 30m session confirmed with ${widget.educatorName}.',
            ),
            backgroundColor: const Color(0xFF81B655),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reservingSlotId = null);
    }
  }
}
