import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';

Widget buildConferenceAppBadge(String? app, {bool compact = false}) {
  final normApp = (app ?? 'google_meet').toLowerCase();
  String name;
  Color bg;
  String logoUrl;

  if (normApp.contains('zoom')) {
    name = 'Zoom';
    bg = const Color(0xFF2D8CFF);
    logoUrl = 'https://logo.clearbit.com/zoom.us';
  } else if (normApp.contains('team')) {
    name = 'MS Teams';
    bg = const Color(0xFF5B5FC7);
    logoUrl = 'https://logo.clearbit.com/microsoft.com';
  } else {
    name = 'Google Meet';
    bg = const Color(0xFF00832D);
    logoUrl = 'https://logo.clearbit.com/meet.google.com';
  }

  Widget logoWidget = ClipRRect(
    borderRadius: BorderRadius.circular(compact ? 3 : 4),
    child: Image.network(
      logoUrl,
      width: compact ? 12 : 16,
      height: compact ? 12 : 16,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Icon(
        normApp.contains('zoom') ? Icons.videocam_rounded :
        normApp.contains('team') ? Icons.groups_rounded : Icons.video_call_rounded,
        size: compact ? 12 : 16,
        color: bg,
      ),
    ),
  );

  if (compact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoWidget,
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bg),
          ),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: bg.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        const SizedBox(width: 6),
        Text(
          name,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: bg),
        ),
      ],
    ),
  );
}

class EducatorGroupsTab extends StatefulWidget {
  final User user;
  const EducatorGroupsTab({super.key, required this.user});

  @override
  State<EducatorGroupsTab> createState() => _EducatorGroupsTabState();
}

class _EducatorGroupsTabState extends State<EducatorGroupsTab> {
  DateTime _focusedDate = DateTime.now();
  String _calendarView = 'Week'; // 'Week' or 'Month'
  
  final List<Color> _sessionColors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF10B981), // Emerald
    const Color(0xFFEC4899), // Pink
  ];

  DateTime _getStartOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday % 7));
  }

  @override
  Widget build(BuildContext context) {
    final startOfWeek = _getStartOfWeek(_focusedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      body: Row(
        children: [
          // Sidebar: Active Members
          _buildSidebar(isDark),
          
          // Main Content: Calendar
          Expanded(
            child: Column(
              children: [
                _buildToolbar(isDark),
                const Divider(height: 1),
                const Divider(height: 1),
                if (_calendarView == 'Week') ...[
                  _buildDayHeader(startOfWeek, isDark),
                  const Divider(height: 1),
                  Expanded(child: _buildCalendarGrid(startOfWeek, isDark)),
                ] else ...[
                  Expanded(child: _buildAgendaView(isDark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Active Members',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService.instance.streamEducatorSubscribers(widget.user.uid),
              builder: (context, snapshot) {
                final subs = (snapshot.data ?? []).where((s) => s['tier'] == 'Premium').toList();
                if (subs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('No premium members', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  );
                }
                return ListView.builder(
                  itemCount: subs.length,
                  itemBuilder: (context, index) {
                    final s = subs[index];
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: DatabaseService.instance.getUserDoc(s['uid']),
                      builder: (context, userSnap) {
                        final userData = userSnap.data;
                        final name = userData?['username'] ?? userData?['email'] ?? 'Loading...';
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF8CB31D).withValues(alpha: 0.2),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8CB31D)),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          dense: true,
                        );
                      }
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    final monthYear = DateFormat('MMMM yyyy').format(_focusedDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _focusedDate = DateTime.now()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () => setState(() => _focusedDate = _focusedDate.subtract(const Duration(days: 7))),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () => setState(() => _focusedDate = _focusedDate.add(const Duration(days: 7))),
          ),
          const SizedBox(width: 16),
          Text(
            monthYear,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildToggleItem('Week', isDark),
                _buildToggleItem('Agenda', isDark),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _showBookingModal(context),
            icon: const Icon(Icons.video_call, color: Colors.white),
            label: const Text('New mentorship', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B49AC), // Purple like MS Teams
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isDark) {
    bool active = _calendarView == label;
    return GestureDetector(
      onTap: () => setState(() => _calendarView = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? (isDark ? Colors.white24 : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active && !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? (isDark ? Colors.white : Colors.black87) : Colors.black45,
          ),
        ),
      ),
    );
  }

  Widget _buildDayHeader(DateTime startOfWeek, bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 80), // For time column alignment
      child: Row(
        children: List.generate(7, (i) {
          final day = startOfWeek.add(Duration(days: i));
          final isToday = day.day == DateTime.now().day && day.month == DateTime.now().month && day.year == DateTime.now().year;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(DateFormat('E').format(day)[0], style: const TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF4B49AC) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime startOfWeek, bool isDark) {
    return SingleChildScrollView(
      child: Stack(
        children: [
          // The Background Grid
          Column(
            children: List.generate(24, (h) {
              final hour = h; // Start at 12 AM
              final isAfternoon = hour >= 12;
              final hourDisplay = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
              final period = isAfternoon ? 'PM' : 'AM';
              
              return Container(
                height: 80,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$hourDisplay $period',
                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ),
                    ...List.generate(7, (i) => Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
                        ),
                      ),
                    )),
                  ],
                ),
              );
            }),
          ),

          // The Sessions Layer
          Positioned.fill(
            left: 80,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService.instance.streamEducatorMentorshipSessions(widget.user.uid),
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];
                // Filtering to only current week
                final currentWeekSessions = sessions.where((s) {
                  final start = (s['startTime'] as Timestamp).toDate();
                  return start.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
                         start.isBefore(startOfWeek.add(const Duration(days: 7)));
                }).toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final dayWidth = constraints.maxWidth / 7;
                    return Stack(
                      children: currentWeekSessions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final s = entry.value;
                        final start = (s['startTime'] as Timestamp).toDate();
                        final end = (s['endTime'] as Timestamp).toDate();
                        
                        // Sunday is 7 in Dart, we want Sunday = 0
                        final dayIndex = start.weekday == 7 ? 0 : start.weekday;
                        final hourStart = start.hour + (start.minute / 60.0);
                        final duration = end.difference(start).inMinutes / 60.0;
                        
                        // Calculate position (12AM is top 0)
                        final topOffset = hourStart * 80;
                        final height = duration * 80;

                        return Positioned(
                          left: dayIndex * dayWidth + 4,
                          top: topOffset + 4,
                          width: dayWidth - 8,
                          height: height - 8,
                          child: GestureDetector(
                            onTap: () => _showSessionDetailsDialog(context, s, _sessionColors[idx % _sessionColors.length]),
                            child: _buildSessionBlock(s, _sessionColors[idx % _sessionColors.length]),
                          ),
                        );
                      }).toList(),
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaView(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService.instance.streamEducatorMentorshipSessions(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('No upcoming mentorship sessions', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        // Sort sessions by start time
        sessions.sort((a, b) {
          final startA = (a['startTime'] as Timestamp).toDate();
          final startB = (b['startTime'] as Timestamp).toDate();
          return startA.compareTo(startB);
        });

        // Only show future or current sessions (up to 1 day old)
        final now = DateTime.now();
        final upcomingSessions = sessions.where((s) {
          final end = (s['endTime'] as Timestamp).toDate();
          return end.isAfter(now.subtract(const Duration(days: 1)));
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: upcomingSessions.length,
          itemBuilder: (context, index) {
            final s = upcomingSessions[index];
            final start = (s['startTime'] as Timestamp).toDate();
            final end = (s['endTime'] as Timestamp).toDate();
            final dateString = DateFormat('EEEE, MMMM d').format(start);
            final timeString = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
            final color = _sessionColors[index % _sessionColors.length];
            final meetingLink = s['meetingLink']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showSessionDetailsDialog(context, s, color),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Date/Time Badge
                        Container(
                          width: 100,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('MMM').format(start).toUpperCase(),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                start.day.toString(),
                                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateString,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      (s['status']?.toString().toUpperCase() ?? 'SCHEDULED'),
                                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                s['studentName'] ?? 'Mentorship Session',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: color),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeString,
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
                                  ),
                                ],
                              ),
                              if (meetingLink.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.videocam, size: 18, color: Colors.blue.shade600),
                                    const SizedBox(width: 6),
                                    const Text('Video call link attached', style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildSessionBlock(Map<String, dynamic> s, Color color) {
    final start = (s['startTime'] as Timestamp).toDate();
    final end = (s['endTime'] as Timestamp).toDate();
    final timeString = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s['studentName'] ?? 'Mentorship',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeString,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (s['meetingLink'] != null && s['meetingLink'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.video_call, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Join Link',
                        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionDetailsDialog(BuildContext context, Map<String, dynamic> s, Color color) {
    final start = (s['startTime'] as Timestamp).toDate();
    final end = (s['endTime'] as Timestamp).toDate();
    final dateString = DateFormat('MMMM d, yyyy').format(start);
    final timeString = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
    final meetingLink = s['meetingLink']?.toString() ?? '';
    final meetingTitle = s['meetingTitle']?.toString() ?? '';
    final conferenceApp = s['conferenceApp']?.toString() ?? 'google_meet';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.event_note, color: color),
            const SizedBox(width: 8),
            const Text('Session Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meetingTitle.isNotEmpty) ...[
              const Text('Meeting Topic', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(meetingTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Learner', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(s['studentName'] ?? 'Mentorship', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
                buildConferenceAppBadge(conferenceApp),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Date & Time', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text('$dateString\n$timeString', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text((s['status']?.toString().toUpperCase() ?? 'SCHEDULED'), style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
            if (meetingLink.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open Conference App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          // ── Edit Button ──
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue.shade700,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close details dialog
              showDialog(
                context: context,
                builder: (ctx) => MentorshipBookingModal(user: widget.user, initialSession: s),
              );
            },
          ),
          // ── Mark as Done (only if has link & not yet completed) ──
          if (meetingLink.isNotEmpty && (s['status']?.toString().toLowerCase() != 'completed'))
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Mark as Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('End Session?'),
                    content: const Text('Mark this mentorship session as completed?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF81B655), foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Yes, Done'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  try {
                    await DatabaseService.instance.completeMentorshipSession(s['id']);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session marked as completed ✓'), backgroundColor: Color(0xFF81B655)),
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
              },
            ),
          // ── Delete Button with Confirmation ──
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Session?'),
                    ],
                  ),
                  content: const Text('Are you sure you want to delete this mentorship session? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Yes, Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  await DatabaseService.instance.deleteMentorshipSession(s['id']);
                  if (context.mounted) {
                    Navigator.pop(context); // Close details dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session deleted successfully'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting session: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBookingModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MentorshipBookingModal(user: widget.user),
    );
  }
}

class MentorshipBookingModal extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? initialSession;
  const MentorshipBookingModal({super.key, required this.user, this.initialSession});

  @override
  State<MentorshipBookingModal> createState() => _MentorshipBookingModalState();
}

class _MentorshipBookingModalState extends State<MentorshipBookingModal> {
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  String _conferenceApp = 'google_meet';
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 60;
  String? _sid;
  String? _snam;
  bool _isSubmitting = false;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    if (widget.initialSession != null) {
      final s = widget.initialSession!;
      _titleController.text = s['meetingTitle']?.toString() ?? '';
      _linkController.text = s['meetingLink']?.toString() ?? '';
      _conferenceApp = s['conferenceApp']?.toString() ?? 'google_meet';
      _sid = s['studentId']?.toString();
      _snam = s['studentName']?.toString();
      final start = (s['startTime'] as Timestamp?)?.toDate();
      if (start != null) {
        _date = DateTime(start.year, start.month, start.day);
        _time = TimeOfDay(hour: start.hour, minute: start.minute);
      }
      final end = (s['endTime'] as Timestamp?)?.toDate();
      if (start != null && end != null) {
        final diff = end.difference(start).inMinutes;
        if (diff > 0) _duration = diff;
      }
    }
  }

  /// Validates meeting link matches the selected conference app
  String? _validateLink(String link) {
    if (link.trim().isEmpty) return null; // optional
    final lower = link.toLowerCase();
    if (_conferenceApp == 'zoom') {
      if (!lower.contains('zoom.us')) {
        return 'Please enter a valid Zoom link (e.g. https://zoom.us/j/...)';
      }
    } else if (_conferenceApp == 'teams') {
      if (!lower.contains('teams.microsoft.com') && !lower.contains('teams.live.com')) {
        return 'Please enter a valid MS Teams link (e.g. https://teams.microsoft.com/...)';
      }
    } else {
      if (!lower.contains('meet.google.com')) {
        return 'Please enter a valid Google Meet link (e.g. https://meet.google.com/xxx-xxxx-xxx)';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialSession != null;
    return AlertDialog(
      title: Text(
        isEditing ? 'Edit mentorship session' : 'New mentorship',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Meeting Title / Topic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Grammar Practice & Accent Coaching',
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Conference App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildAppChip('google_meet', 'Google Meet', 'https://logo.clearbit.com/meet.google.com', const Color(0xFF00832D))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildAppChip('zoom', 'Zoom', 'https://logo.clearbit.com/zoom.us', const Color(0xFF2D8CFF))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildAppChip('teams', 'MS Teams', 'https://logo.clearbit.com/microsoft.com', const Color(0xFF5B5FC7))),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Select Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: DatabaseService.instance.streamEducatorSubscribers(widget.user.uid),
                builder: (context, snapshot) {
                  final subs = (snapshot.data ?? []).toList();
                  
                  if (subs.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                    return DropdownButtonFormField<String>(
                      onChanged: null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      items: const [],
                      hint: const Text('No active subscribers found', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    );
                  }

                  // Check if current _sid is still valid
                  final String? currentValue = subs.any((s) => s['uid']?.toString() == _sid) ? _sid : null;

                  return DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: subs.map((s) {
                      final uid = s['uid']?.toString() ?? '';
                      final tierStr = (s['tier'] ?? 'Subscribed').toString();
                      return DropdownMenuItem(
                        value: uid, 
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: DatabaseService.instance.getUserDoc(uid),
                          builder: (context, userSnap) {
                            final userData = userSnap.data;
                            final name = userData?['username'] ?? userData?['email'] ?? 'User ($uid)';
                            return Text('$name • $tierStr');
                          }
                        ),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      final userData = await DatabaseService.instance.getUserDoc(val!);
                      setState(() {
                        _sid = val;
                        _snam = userData?['username'] ?? userData?['email'] ?? 'Student';
                      });
                    },
                    hint: snapshot.connectionState == ConnectionState.waiting 
                      ? const Text('Loading...') 
                      : const Text('Choose a learner'),
                  );
                }
              ),
              const SizedBox(height: 16),
              const Text('Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                          firstDate: DateTime.now().subtract(const Duration(days: 365)), 
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
              const Text('Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: [30, 45, 60, 90, 120].contains(_duration) ? _duration : 60,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                items: [30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m mins'))).toList(),
                onChanged: (val) => setState(() => _duration = val!),
              ),
              const SizedBox(height: 16),
              const Text('Meeting link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _linkController,
                onChanged: (val) {
                  setState(() => _linkError = _validateLink(val));
                },
                decoration: InputDecoration(
                  hintText: _conferenceApp == 'zoom'
                      ? 'https://zoom.us/j/123456789'
                      : _conferenceApp == 'teams'
                          ? 'https://teams.microsoft.com/l/meetup-join/...'
                          : 'https://meet.google.com/xxx-xxxx-xxx',
                  filled: true,
                  fillColor: _linkError != null
                      ? Colors.red.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _linkError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _linkError != null
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                  ),
                  errorText: _linkError,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _conferenceApp == 'zoom'
                            ? 'https://logo.clearbit.com/zoom.us'
                            : _conferenceApp == 'teams'
                                ? 'https://logo.clearbit.com/microsoft.com'
                                : 'https://logo.clearbit.com/meet.google.com',
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.link_rounded, size: 18),
                      ),
                    ),
                  ),
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
            backgroundColor: const Color(0xFF4B49AC),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isSubmitting ? null : _handleSchedule,
          child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'Update' : 'Schedule'),
        ),
      ],
    );
  }

  Widget _buildAppChip(String appKey, String label, String logoUrl, Color color) {
    final selected = _conferenceApp == appKey;
    return InkWell(
      onTap: () => setState(() {
        _conferenceApp = appKey;
        // Re-validate link when app changes
        _linkError = _validateLink(_linkController.text);
      }),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.13) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
          boxShadow: selected ? [
            BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3)),
          ] : [],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                logoUrl,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Icon(
                  appKey == 'zoom' ? Icons.videocam_rounded :
                  appKey == 'teams' ? Icons.groups_rounded : Icons.video_call_rounded,
                  color: selected ? color : Colors.grey,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? color : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSchedule() async {
    if (_sid == null || _sid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }

    // Validate link
    final linkVal = _validateLink(_linkController.text.trim());
    if (linkVal != null) {
      setState(() => _linkError = linkVal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(linkVal), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    
    try {
      final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final end = start.add(Duration(minutes: _duration));

      if (widget.initialSession != null) {
        final sessionId = widget.initialSession!['id']?.toString() ?? '';
        await DatabaseService.instance.updateMentorshipSession(
          sessionId: sessionId,
          studentId: _sid!,
          studentName: _snam ?? 'Student',
          startTime: start,
          endTime: end,
          meetingLink: _linkController.text,
          conferenceApp: _conferenceApp,
          meetingTitle: _titleController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mentorship updated successfully!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        await DatabaseService.instance.createMentorshipSession(
          educatorId: widget.user.uid,
          studentId: _sid!,
          studentName: _snam ?? 'Student',
          startTime: start,
          endTime: end,
          meetingLink: _linkController.text,
          conferenceApp: _conferenceApp,
          meetingTitle: _titleController.text.trim(),
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mentorship scheduled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
