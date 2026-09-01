import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/universal_drawer.dart';

class ManageSubscriptionsPage extends StatefulWidget {
  final User user;
  const ManageSubscriptionsPage({super.key, required this.user});

  @override
  State<ManageSubscriptionsPage> createState() =>
      _ManageSubscriptionsPageState();
}

class _ManageSubscriptionsPageState extends State<ManageSubscriptionsPage> {
  final TextEditingController _standardController = TextEditingController();
  final TextEditingController _premiumController = TextEditingController();
  bool _isEducator = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoadPricing();
  }

  Future<void> _checkRoleAndLoadPricing() async {
    final doc = await DatabaseService.instance.getUserData(widget.user.uid);
    if (doc != null) {
      if (mounted) {
        setState(() {
          _userData = doc;
          _isEducator = doc['role'] == 'Educator';
          final pricing = doc['subscription_pricing'] as Map<String, dynamic>?;
          if (pricing != null) {
            _standardController.text = (pricing['standard'] ?? 3).toString();
            _premiumController.text = (pricing['premium'] ?? 7).toString();
          } else {
            _standardController.text = '3';
            _premiumController.text = '7';
          }
        });
      }
    }
  }

  Future<void> _savePricing() async {
    final standard = int.tryParse(_standardController.text) ?? 3;
    final premium = int.tryParse(_premiumController.text) ?? 7;

    if (standard > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Standard pricing cannot exceed \$10')),
      );
      return;
    }
    if (premium > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium pricing cannot exceed \$30')),
      );
      return;
    }

    await DatabaseService.instance.updateSubscriptionPricing(
      widget.user.uid,
      standard: standard,
      premium: premium,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pricing updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(
        user: widget.user,
        userData: _userData,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
        onLogoTap: () => Navigator.pop(context),
        onProfileTap: () => Navigator.pop(context),
      ),
      drawer: UniversalDrawer(
        user: widget.user,
        userData: _userData ?? {},
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81B655).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF81B655).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_rounded,
                              size: 16,
                              color: Color(0xFF81B655),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Back',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF81B655),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Title
                  Text(
                    'Manage Subscription',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View your active educator subscriptions, manage pricing tiers, and track history.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_isEducator) ...[
                    _buildHeaderBox(
                      Icons.payments_rounded,
                      'Subscription Pricing Settings',
                      Colors.orange,
                      textColor,
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPricingField(
                            label: 'Standard Tier (Max \$10)',
                            controller: _standardController,
                            icon: Icons.star_outline_rounded,
                            isDark: isDark,
                            borderColor: borderColor,
                            textColor: textColor,
                          ),
                          const SizedBox(height: 16),
                          _buildPricingField(
                            label: 'Premium Tier (Max \$30)',
                            controller: _premiumController,
                            icon: Icons.auto_awesome_rounded,
                            isDark: isDark,
                            borderColor: borderColor,
                            textColor: textColor,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF81B655),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _savePricing,
                              child: Text(
                                'Save Pricing Settings',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],

                  _buildLearnerSubscriptions(
                    isDark,
                    cardBg,
                    borderColor,
                    textColor,
                    subtitleColor,
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBox(
    IconData icon,
    String title,
    Color iconColor,
    Color textColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPricingField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    required Color borderColor,
    required Color textColor,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? Colors.white38 : const Color(0xFF64748B),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF81B655), size: 20),
        suffixText: '\$',
        suffixStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF81B655),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF81B655),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLearnerSubscriptions(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamLearnerSubscriptions(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final subscriptions = snapshot.data ?? [];
        final active = subscriptions.where((s) => s['status'] == 'active').toList();
        final history = subscriptions.where((s) => s['status'] != 'active').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderBox(
              Icons.stars_rounded,
              'Active Subscriptions',
              const Color(0xFF81B655),
              textColor,
              isDark,
            ),
            const SizedBox(height: 16),
            if (active.isEmpty)
              _buildEmptyCard('No active subscriptions.', isDark, cardBg, borderColor, subtitleColor)
            else
              ...active.map((s) => _buildSubscriptionCard(s, true, isDark, cardBg, borderColor, textColor, subtitleColor)),

            const SizedBox(height: 36),
            _buildMentorshipSection(isDark, cardBg, borderColor, textColor, subtitleColor),

            const SizedBox(height: 36),
            _buildHeaderBox(
              Icons.history_rounded,
              'Subscription History',
              Colors.amber,
              textColor,
              isDark,
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              _buildEmptyCard('No subscription history.', isDark, cardBg, borderColor, subtitleColor)
            else
              ...history.map((s) => _buildSubscriptionCard(s, false, isDark, cardBg, borderColor, textColor, subtitleColor)),
          ],
        );
      },
    );
  }

  Widget _buildMentorshipSection(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamStudentMentorshipSessions(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data ?? [];
        final scheduledSessions = sessions
            .where((s) => (s['status'] ?? 'scheduled').toString().toLowerCase() != 'cancelled')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderBox(
              Icons.video_call_rounded,
              'Mentorship Sessions & Meetings',
              const Color(0xFF3B82F6),
              textColor,
              isDark,
            ),
            const SizedBox(height: 16),
            if (scheduledSessions.isEmpty)
              _buildEmptyCard('No scheduled mentorship meetings.', isDark, cardBg, borderColor, subtitleColor)
            else
              ...scheduledSessions.map((s) => _buildMentorshipCard(s, isDark, cardBg, borderColor, textColor, subtitleColor)),
          ],
        );
      },
    );
  }

  Widget _buildMentorshipCard(
    Map<String, dynamic> session,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final title = session['meetingTitle'] as String? ?? 'Mentorship Session';
    final app = session['conferenceApp'] as String? ?? 'google_meet';
    final meetingLink = session['meetingLink'] as String? ?? '';
    final educatorId = session['educatorId'] as String? ?? '';

    final startTime = (session['startTime'] as Timestamp?)?.toDate();
    final endTime = (session['endTime'] as Timestamp?)?.toDate();

    final dateStr = startTime != null ? DateFormat('EEE, MMM d, yyyy').format(startTime) : 'Scheduled Date';
    final timeStr = (startTime != null && endTime != null)
        ? '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : 'Mentorship Session',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: DatabaseService.instance.getUserDoc(educatorId),
                      builder: (context, eduSnap) {
                        final eduName = eduSnap.data?['username'] ?? 'Educator';
                        return Text(
                          'With $eduName',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: subtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _buildConferenceBadge(app),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: const Color(0xFF81B655)),
              const SizedBox(width: 8),
              Text(
                '$dateStr  •  $timeStr',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (meetingLink.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  'Join Meeting',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final uri = Uri.parse(meetingLink);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ],
      ),
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
      name = 'Google Meet';
      bg = const Color(0xFF00832D);
      icon = Icons.video_call_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: bg),
          const SizedBox(width: 6),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: bg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(
    String text,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color subtitleColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(color: subtitleColor, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(
    Map<String, dynamic> sub,
    bool isActive,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final eduData = sub['educatorData'] as Map<String, dynamic>? ?? {};
    final username = eduData['username'] as String? ?? 'Educator';
    final tier = sub['tier'] as String? ?? 'Basic';
    final eduUid = sub['educatorUid'] as String;

    final lowerTier = tier.toLowerCase();
    Color pillBg;
    Color pillText;

    if (lowerTier == 'premium') {
      pillBg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
      pillText = const Color(0xFF8B5CF6);
    } else if (lowerTier == 'standard') {
      pillBg = const Color(0xFF81B655).withValues(alpha: 0.12);
      pillText = const Color(0xFF81B655);
    } else {
      pillBg = Colors.blue.withValues(alpha: 0.12);
      pillText = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFF81B655) : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              backgroundImage: (eduData['photoUrl'] as String?)?.isNotEmpty == true
                  ? NetworkImage(eduData['photoUrl']!)
                  : null,
              child: (eduData['photoUrl'] as String?)?.isNotEmpty == true
                  ? null
                  : Icon(
                      Icons.person_rounded,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tier.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: pillText,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '• ${isActive ? 'Active' : 'Cancelled'}',
                      style: GoogleFonts.inter(
                        color: isActive
                            ? const Color(0xFF81B655)
                            : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isActive) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call_rounded, size: 16),
              label: Text(
                'Schedule Meeting',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => LearnerMentorshipBookingModal(
                    user: widget.user,
                    initialEducatorUid: eduUid,
                    initialEducatorName: username,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _confirmCancel(context, eduUid, username),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, String eduUid, String name) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        title: Text(
          'Cancel Subscription?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to cancel your subscription to $name?',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Keep it',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Cancel Subscription',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await DatabaseService.instance.unsubscribeFromEducator(eduUid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unsubscribed from $name.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class LearnerMentorshipBookingModal extends StatefulWidget {
  final User user;
  final String? initialEducatorUid;
  final String? initialEducatorName;

  const LearnerMentorshipBookingModal({
    super.key,
    required this.user,
    this.initialEducatorUid,
    this.initialEducatorName,
  });

  @override
  State<LearnerMentorshipBookingModal> createState() => _LearnerMentorshipBookingModalState();
}

class _LearnerMentorshipBookingModalState extends State<LearnerMentorshipBookingModal> {
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  String _conferenceApp = 'google_meet';
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 60;
  String? _selectedEduUid;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedEduUid = widget.initialEducatorUid;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Schedule Mentorship Session', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meeting Title / Topic', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Grammar Consultation & Practice',
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              Text('Select Educator', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: DatabaseService.instance.streamLearnerSubscriptions(widget.user.uid),
                builder: (context, snapshot) {
                  final activeSubs = (snapshot.data ?? []).where((s) => s['status'] == 'active').toList();
                  if (activeSubs.isEmpty) {
                    return const Text('No active educator subscriptions found.', style: TextStyle(color: Colors.grey, fontSize: 13));
                  }

                  final initialVal = activeSubs.any((s) => s['educatorUid'] == _selectedEduUid)
                      ? _selectedEduUid
                      : activeSubs.first['educatorUid'] as String;

                  _selectedEduUid ??= initialVal;

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedEduUid,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: activeSubs.map((s) {
                      final eduUid = s['educatorUid'] as String;
                      final eduData = s['educatorData'] as Map<String, dynamic>? ?? {};
                      final eduName = eduData['username'] as String? ?? 'Educator';
                      return DropdownMenuItem<String>(
                        value: eduUid,
                        child: Text(eduName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedEduUid = val;
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              Text('Conference App', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildAppChip('google_meet', 'Google Meet', Icons.video_call_rounded, const Color(0xFF00832D))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildAppChip('zoom', 'Zoom', Icons.videocam_rounded, const Color(0xFF2D8CFF))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildAppChip('teams', 'MS Teams', Icons.groups_rounded, const Color(0xFF5B5FC7))),
                ],
              ),
              const SizedBox(height: 16),

              Text('Schedule', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('MM/dd/yyyy').format(_date)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: _date, 
                          firstDate: DateTime.now(), 
                          lastDate: DateTime.now().add(const Duration(days: 365))
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(_time.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _time);
                        if (picked != null) setState(() => _time = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Duration', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _duration,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                items: [30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m mins'))).toList(),
                onChanged: (val) => setState(() => _duration = val!),
              ),
              const SizedBox(height: 16),
              Text('Meeting link (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  hintText: 'https://meet.google.com/... or leave blank',
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context), 
          child: const Text('Cancel', style: TextStyle(color: Colors.grey))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF81B655),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isSubmitting ? null : _handleSchedule,
          child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Schedule Meeting'),
        ),
      ],
    );
  }

  Widget _buildAppChip(String appKey, String label, IconData icon, Color color) {
    final selected = _conferenceApp == appKey;
    return InkWell(
      onTap: () => setState(() => _conferenceApp = appKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSchedule() async {
    final eduUid = _selectedEduUid;
    if (eduUid == null || eduUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an educator')));
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final end = start.add(Duration(minutes: _duration));
      
      final studentDoc = await DatabaseService.instance.getUserDoc(widget.user.uid);
      final studentName = studentDoc?['username'] ?? widget.user.displayName ?? widget.user.email ?? 'Learner';
      
      String link = _linkController.text.trim();
      if (link.isEmpty) {
        if (_conferenceApp == 'zoom') {
          link = 'https://zoom.us/join';
        } else if (_conferenceApp == 'teams') {
          link = 'https://teams.microsoft.com/';
        } else {
          link = 'https://meet.google.com/new';
        }
      }

      await DatabaseService.instance.createMentorshipSession(
        educatorId: eduUid,
        studentId: widget.user.uid,
        studentName: studentName,
        startTime: start,
        endTime: end,
        meetingLink: link,
        conferenceApp: _conferenceApp,
        meetingTitle: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Mentorship Consultation',
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mentorship meeting scheduled successfully!'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }
}
