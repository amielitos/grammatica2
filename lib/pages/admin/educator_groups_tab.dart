import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/database_service.dart';
import '../../services/agora_service.dart';
import 'package:intl/intl.dart';
import '../conference_page.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/center_notice_dialog.dart';

Widget buildConferenceAppBadge(String? app, {bool compact = false}) {
  const brand = Color(0xFF81B655);
  const name = 'Meet';
  const icon = Icons.video_call_rounded;

  if (compact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: brand.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: brand),
          SizedBox(width: 4),
          Text(name,
              style: TextStyle(
                  color: brand,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: brand.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: brand.withValues(alpha: 0.3)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: brand),
        SizedBox(width: 6),
        Text(name,
            style: TextStyle(
                color: brand,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
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
  int _agendaPage = 1;
  static const int _agendaPageSize = 5;
  String _memberSearchQuery = '';
  String _memberSortOrder = 'newest'; // 'newest' or 'oldest'
  
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
    final isMobile = MediaQuery.of(context).size.width <= 768;

    if (isMobile) {
      return _buildMSTeamsMobileCalendar(isDark);
    }

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

  Widget _buildMSTeamsMobileCalendar(bool isDark) {
    final startOfWeek = _getStartOfWeek(_focusedDate);
    const primaryPurple = Color(0xFF5B5FC7);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Month Header & Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDate),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _focusedDate = _focusedDate.subtract(const Duration(days: 7))),
                ),
                IconButton(
                  icon: const Icon(Icons.today_rounded),
                  onPressed: () => setState(() => _focusedDate = DateTime.now()),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => _focusedDate = _focusedDate.add(const Duration(days: 7))),
                ),
              ],
            ),
          ),
          // Action Buttons: Set Availability directly ABOVE New Mentorship
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showSetAvailabilityDialog(context),
                    icon: const Icon(Icons.event_available_rounded, color: Color(0xFF81B655), size: 18),
                    label: const Text('Set Availability', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF81B655))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF81B655), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showBookingModal(context),
                    icon: const Icon(Icons.video_call, color: Colors.white, size: 18),
                    label: const Text('New mentorship', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B49AC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // MS Teams 7-Day Horizontal Strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
            ),
            child: Row(
              children: List.generate(7, (i) {
                final day = startOfWeek.add(Duration(days: i));
                final isSelected = day.day == _focusedDate.day && day.month == _focusedDate.month && day.year == _focusedDate.year;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _focusedDate = day),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('E').format(day).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? primaryPurple : (isDark ? Colors.white54 : Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected ? primaryPurple : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            day.day.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // Agenda List of Sessions for Selected Date
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService.instance.streamEducatorMentorshipSessions(widget.user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sessions = snapshot.data ?? [];
                final selectedDaySessions = sessions.where((s) {
                  final start = (s['startTime'] as Timestamp).toDate();
                  return start.day == _focusedDate.day && start.month == _focusedDate.month && start.year == _focusedDate.year;
                }).toList()
                  ..sort((a, b) {
                    final ta = (a['startTime'] as Timestamp).toDate();
                    final tb = (b['startTime'] as Timestamp).toDate();
                    return ta.compareTo(tb);
                  });

                if (selectedDaySessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No events on this day',
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: selectedDaySessions.length,
                   itemBuilder: (context, index) {
                    final s = selectedDaySessions[index];
                    final start = (s['startTime'] as Timestamp).toDate();
                    final end = (s['endTime'] as Timestamp).toDate();
                    final timeStr = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final sessionDay = DateTime(start.year, start.month, start.day);
                    final isDoneOrPast = (s['status']?.toString().toLowerCase() == 'completed') ||
                        end.isBefore(now) ||
                        sessionDay.isBefore(todayStart);
                    final canJoin = !isDoneOrPast && !now.isBefore(start.subtract(const Duration(minutes: 10)));
                    final agoraChannel = s['agoraChannel']?.toString() ?? '';
                    final sessionId = s['id']?.toString() ?? '';

                    return GestureDetector(
                      onTap: () => _showSessionDetailsDialog(context, s, primaryPurple),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isDoneOrPast ? const Color(0xFF16A34A) : primaryPurple,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (s['meetingTitle'] as String?)?.isNotEmpty == true
                                                    ? s['meetingTitle']
                                                    : 'Mentorship Session',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Student: ${s['studentName'] ?? 'Student'}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF81B655),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isDoneOrPast)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Done',
                                                  style: TextStyle(
                                                    color: Color(0xFF16A34A),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          buildConferenceAppBadge('agora', compact: true),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                                      ),
                                    ),
                                    if (!isDoneOrPast) ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          onPressed: canJoin
                                              ? () {
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
                                                        sessionTitle: s['meetingTitle']?.toString() ?? 'Mentorship Session',
                                                        otherParticipantName: s['studentName']?.toString() ?? 'Student',
                                                        isHost: true,
                                                        currentUser: widget.user,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              : null,
                                          icon: Icon(canJoin ? Icons.video_call_rounded : Icons.schedule_rounded, size: 16),
                                          label: Text(canJoin ? 'Join' : 'Available 10m before'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF81B655),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                                            disabledForegroundColor: isDark ? Colors.white54 : Colors.grey.shade600,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Members',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _memberSortOrder = _memberSortOrder == 'newest' ? 'oldest' : 'newest';
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          _memberSortOrder == 'newest' ? 'Newest' : 'Oldest',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF81B655)),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _memberSortOrder == 'newest' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 13,
                          color: const Color(0xFF81B655),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                suffixIcon: _memberSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => setState(() => _memberSearchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _memberSearchQuery = val.trim()),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService.instance.streamEducatorSubscribers(widget.user.uid),
              builder: (context, snapshot) {
                final subs = (snapshot.data ?? []).where((s) => s['tier'] == 'Premium').toList();
                if (subs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Text('No enrolled members', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  );
                }

                // Sort by subscription date
                subs.sort((a, b) {
                  final da = (a['subscribedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  final db = (b['subscribedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  return _memberSortOrder == 'newest' ? db.compareTo(da) : da.compareTo(db);
                });

                return ListView.builder(
                  itemCount: subs.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final s = subs[index];
                    final rawSub = s['subscribedAt'];
                    DateTime? subDate;
                    if (rawSub is Timestamp) {
                      subDate = rawSub.toDate();
                    } else if (rawSub is DateTime) {
                      subDate = rawSub;
                    }
                    final dateStr = subDate != null
                        ? DateFormat('MMM d, yyyy').format(subDate)
                        : 'Enrolled';

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: DatabaseService.instance.getUserDoc(s['uid']),
                      builder: (context, userSnap) {
                        final userData = userSnap.data;
                        final name = userData?['username'] ?? userData?['displayName'] ?? userData?['email'] ?? 'Member';
                        final email = userData?['email'] ?? '';

                        if (_memberSearchQuery.isNotEmpty) {
                          final query = _memberSearchQuery.toLowerCase();
                          if (!name.toString().toLowerCase().contains(query) &&
                              !email.toString().toLowerCase().contains(query)) {
                            return const SizedBox.shrink();
                          }
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF8CB31D).withValues(alpha: 0.18),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8CB31D)),
                            ),
                          ),
                          title: Text(
                            name.toString(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Subscribed: $dateStr',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                          dense: true,
                        );
                      },
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
          OutlinedButton.icon(
            onPressed: () => _showSetAvailabilityDialog(context),
            icon: const Icon(Icons.event_available_rounded, color: Color(0xFF81B655)),
            label: const Text('Set Availability', style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF81B655), width: 1.5),
              foregroundColor: const Color(0xFF81B655),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
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
            color: active ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white60 : Colors.black45),
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
                Text(DateFormat('E').format(day)[0], style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45)),
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
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black45),
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

                    // Group sessions by day index (Sunday = 0)
                    final Map<int, List<Map<String, dynamic>>> dayMap = {};
                    for (final s in currentWeekSessions) {
                      final start = (s['startTime'] as Timestamp).toDate();
                      final dayIndex = start.weekday == 7 ? 0 : start.weekday;
                      dayMap.putIfAbsent(dayIndex, () => []).add(s);
                    }

                    final List<Widget> positionedList = [];

                    dayMap.forEach((dayIndex, listForDay) {
                      // Sort by start time ascending
                      listForDay.sort((a, b) {
                        final ta = (a['startTime'] as Timestamp).toDate();
                        final tb = (b['startTime'] as Timestamp).toDate();
                        return ta.compareTo(tb);
                      });

                      // Partition into mutually overlapping groups
                      final List<List<Map<String, dynamic>>> clusters = [];
                      for (final s in listForDay) {
                        final sStart = (s['startTime'] as Timestamp).toDate();
                        final sEnd = (s['endTime'] as Timestamp).toDate();

                        bool placed = false;
                        for (final cl in clusters) {
                          final overlaps = cl.any((other) {
                            final oStart = (other['startTime'] as Timestamp).toDate();
                            final oEnd = (other['endTime'] as Timestamp).toDate();
                            return sStart.isBefore(oEnd) && sEnd.isAfter(oStart);
                          });
                          if (overlaps) {
                            cl.add(s);
                            placed = true;
                            break;
                          }
                        }
                        if (!placed) {
                          clusters.add([s]);
                        }
                      }

                      for (final cl in clusters) {
                        final count = cl.length;
                        final subWidth = (dayWidth - 8) / count;

                        for (int col = 0; col < count; col++) {
                          final s = cl[col];
                          final globalIdx = currentWeekSessions.indexOf(s);
                          final color = _sessionColors[(globalIdx >= 0 ? globalIdx : col) % _sessionColors.length];

                          final start = (s['startTime'] as Timestamp).toDate();
                          final end = (s['endTime'] as Timestamp).toDate();

                          final hourStart = start.hour + (start.minute / 60.0);
                          final duration = end.difference(start).inMinutes / 60.0;

                          final topOffset = hourStart * 80;
                          final height = duration * 80;

                          final left = dayIndex * dayWidth + 4 + (col * subWidth);
                          final width = count > 1 ? (subWidth - 2) : (dayWidth - 8);

                          positionedList.add(
                            Positioned(
                              left: left,
                              top: topOffset + 4,
                              width: width,
                              height: height - 8,
                              child: GestureDetector(
                                onTap: () => _showSessionDetailsDialog(context, s, color),
                                child: _buildSessionBlock(s, color),
                              ),
                            ),
                          );
                        }
                      }
                    });

                    return Stack(children: positionedList);
                  },
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

        final totalSessions = upcomingSessions.length;
        if (totalSessions == 0) {
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

        final maxPage = (totalSessions / _agendaPageSize).ceil().clamp(1, 9999);
        if (_agendaPage > maxPage) _agendaPage = maxPage;
        final startIndex = (_agendaPage - 1) * _agendaPageSize;
        final pageSessions = upcomingSessions.skip(startIndex).take(_agendaPageSize).toList();

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: pageSessions.length,
                itemBuilder: (context, index) {
                  final s = pageSessions[index];
                  final originalIndex = startIndex + index;
                  final start = (s['startTime'] as Timestamp).toDate();
                  final end = (s['endTime'] as Timestamp).toDate();
                  final dateString = DateFormat('EEEE, MMMM d').format(start);
                  final timeString = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
                  final color = _sessionColors[originalIndex % _sessionColors.length];
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
                                  Builder(
                                    builder: (context) {
                                      final now = DateTime.now();
                                      final todayStart = DateTime(now.year, now.month, now.day);
                                      final sessionDay = DateTime(start.year, start.month, start.day);
                                      final isDoneOrPast = (s['status']?.toString().toLowerCase() == 'completed') ||
                                          end.isBefore(now) ||
                                          sessionDay.isBefore(todayStart);
                                      if (isDoneOrPast) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                                              SizedBox(width: 4),
                                              Text(
                                                'DONE',
                                                style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          (s['status']?.toString().toUpperCase() ?? 'SCHEDULED'),
                                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (s['meetingTitle'] as String?)?.isNotEmpty == true
                                    ? s['meetingTitle']
                                    : 'Mentorship Session',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Student: ${s['studentName'] ?? 'Student'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF81B655),
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
        ),
      ),
      if (totalSessions > _agendaPageSize)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: PaginationBar(
            currentPage: _agendaPage,
            totalItems: totalSessions,
            pageSize: _agendaPageSize,
            itemName: 'sessions',
            onPageChanged: (newPage) {
              setState(() => _agendaPage = newPage);
            },
          ),
        ),
      ],
    );
  },
);
}

  Widget _buildSessionBlock(Map<String, dynamic> s, Color color) {
    final start = (s['startTime'] as Timestamp).toDate();
    final end = (s['endTime'] as Timestamp).toDate();
    final timeString = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(start.year, start.month, start.day);
    final isDoneOrPast = (s['status']?.toString().toLowerCase() == 'completed') ||
        end.isBefore(now) ||
        sessionDay.isBefore(todayStart);
    final effectiveColor = isDoneOrPast ? const Color(0xFF16A34A) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        border: Border.all(color: effectiveColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (s['meetingTitle'] as String?)?.isNotEmpty == true
                              ? s['meetingTitle']
                              : 'Mentorship',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: effectiveColor,
                          ),
                        ),
                        if (s['studentName'] != null)
                          Text(
                            s['studentName'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: effectiveColor.withValues(alpha: 0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isDoneOrPast)
                    const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                timeString,
                style: TextStyle(
                  fontSize: 9,
                  color: effectiveColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isDoneOrPast && s['meetingLink'] != null && s['meetingLink'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.video_call, size: 12, color: effectiveColor),
                      const SizedBox(width: 4),
                      Text(
                        'Join Link',
                        style: TextStyle(fontSize: 9, color: effectiveColor, fontWeight: FontWeight.bold),
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
    final meetingTitle = s['meetingTitle']?.toString() ?? '';
    final conferenceApp = s['conferenceApp']?.toString() ?? 'agora';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(start.year, start.month, start.day);
    final isDoneOrPast = (s['status']?.toString().toLowerCase() == 'completed') ||
        end.isBefore(now) ||
        sessionDay.isBefore(todayStart);
    final canJoin = !isDoneOrPast && !now.isBefore(start.subtract(const Duration(minutes: 10)));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isDoneOrPast ? Icons.check_circle_rounded : Icons.event_note,
              color: isDoneOrPast ? const Color(0xFF16A34A) : color,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Session Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (isDoneOrPast)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'Done',
                      style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
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
            Row(
              children: [
                if (isDoneOrPast) ...[
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                ],
                Text(
                  isDoneOrPast ? 'COMPLETED' : (s['status']?.toString().toUpperCase() ?? 'SCHEDULED'),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDoneOrPast ? const Color(0xFF16A34A) : color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (!isDoneOrPast) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(canJoin ? Icons.video_call_rounded : Icons.schedule_rounded, size: 18),
                  label: Text(canJoin ? 'Join' : 'Join (Available 10 mins before start)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81B655),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: canJoin
                      ? () {
                          Navigator.pop(context);
                          final agoraChannel = s['agoraChannel']?.toString() ?? '';
                          final sessionId = s['id']?.toString() ?? '';
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
                                sessionTitle: meetingTitle.isNotEmpty ? meetingTitle : 'Mentorship Session',
                                otherParticipantName: s['studentName']?.toString() ?? 'Student',
                                isHost: true,
                                currentUser: widget.user,
                              ),
                            ),
                          );
                        }
                      : null,
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
          if (!isDoneOrPast) ...[
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
            // ── Mark as Done (if not yet completed) ──
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

  void _showSetAvailabilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EducatorSetAvailabilityDialog(user: widget.user),
    );
  }
}

Future<void> _showPastTimeNoticeDialog(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_toggle_off_rounded, color: Colors.redAccent, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Past Time Not Allowed',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Text(
        'You cannot set or schedule a mentorship session in the past. Please select an upcoming date and time.',
        style: GoogleFonts.inter(fontSize: 14, height: 1.5),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Understood'),
        ),
      ],
    ),
  );
}

Future<void> _showScheduleConflictDialog(BuildContext context, String message) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_busy_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Schedule Conflict',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(fontSize: 14, height: 1.5),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
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
  DateTime _date = DateTime.now();
  late TimeOfDay _time;
  int _duration = 90;
  String? _sid;
  String? _snam;
  bool _isSubmitting = false;
  bool _titleTouched = false;
  bool _studentTouched = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    final now = DateTime.now();
    int nextHour = now.minute > 30 ? (now.hour + 2) : (now.hour + 1);
    if (nextHour >= 24) {
      _date = now.add(const Duration(days: 1));
      nextHour = nextHour % 24;
    }
    _time = TimeOfDay(hour: nextHour, minute: 0);

    if (widget.initialSession != null) {
      final s = widget.initialSession!;
      _titleController.text = s['meetingTitle']?.toString() ?? '';
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

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.initialSession != null;
    DateTime? existingStart;
    DateTime? existingEnd;
    if (isEditing) {
      existingStart = (widget.initialSession!['startTime'] as Timestamp?)?.toDate();
      existingEnd = (widget.initialSession!['endTime'] as Timestamp?)?.toDate();
    }
    final now = DateTime.now();
    final isOngoing = existingStart != null && existingEnd != null && now.isAfter(existingStart) && now.isBefore(existingEnd);
    final isPast = existingEnd != null && now.isAfter(existingEnd);
    final canEditName = !isEditing || (!isOngoing && !isPast);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.video_call_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Mentorship Session' : 'New Mentorship',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOngoing)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This mentorship session is currently ONGOING. Name and details cannot be edited.',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isPast)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_clock_rounded, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This session has already concluded and cannot be edited.',
                          style: TextStyle(color: Colors.grey, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Meeting Title / Topic',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                enabled: canEditName,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Grammar Practice & Accent Coaching',
                  errorText: _titleTouched && _titleController.text.trim().isEmpty ? 'Meeting title is required' : null,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.withValues(alpha: canEditName ? 0.05 : 0.15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Meet info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Conference powered by Grammatica Meet — in-app video call, no external links needed.',
                        style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text.rich(
                TextSpan(
                  text: 'Select Student',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: DatabaseService.instance.streamEducatorSubscribers(widget.user.uid),
                builder: (context, snapshot) {
                  final allSubs = (snapshot.data ?? []).toList();
                  final subs = allSubs.where((s) => (s['tier']?.toString().toLowerCase() ?? '') == 'premium').toList();
                  final studentError = _studentTouched && (_sid == null || _sid!.isEmpty)
                      ? 'Student selection is required'
                      : null;
                  
                  if (subs.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                    return DropdownButtonFormField<String>(
                      onChanged: null,
                      decoration: InputDecoration(
                        errorText: studentError,
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                      ),
                      items: const [],
                      hint: Text('No active enrolled learners found', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                    );
                  }

                  // Check if current _sid is still valid
                  final String? currentValue = subs.any((s) => s['uid']?.toString() == _sid) ? _sid : null;

                  return DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    isExpanded: true,
                    style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    decoration: InputDecoration(
                      errorText: studentError,
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
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
                    onChanged: isEditing ? null : (val) async {
                      final userData = await DatabaseService.instance.getUserDoc(val!);
                      setState(() {
                        _sid = val;
                        _studentTouched = false;
                        _snam = userData?['username'] ?? userData?['email'] ?? 'Student';
                      });
                    },
                    hint: Text(
                      snapshot.connectionState == ConnectionState.waiting ? 'Loading...' : 'Choose a learner',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }
              ),
              const SizedBox(height: 16),
              Text('Schedule', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.calendar_today_rounded, size: 16, color: isEditing ? Colors.grey : AppColors.primary),
                      label: Text(
                        DateFormat('MM/dd/yyyy').format(_date),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: isEditing ? Colors.grey : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isEditing ? Colors.grey.shade300 : AppColors.divider),
                      ),
                      onPressed: isEditing ? null : () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: _date.isBefore(DateTime.now()) ? DateTime.now() : _date, 
                          firstDate: DateTime.now(), 
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (!context.mounted) return;
                        if (picked != null) {
                          final chosen = DateTime(picked.year, picked.month, picked.day, _time.hour, _time.minute);
                          if (chosen.isBefore(DateTime.now())) {
                            await _showPastTimeNoticeDialog(context);
                            return;
                          }
                          setState(() => _date = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.access_time_rounded, size: 16, color: isEditing ? Colors.grey : AppColors.primary),
                      label: Text(
                        _time.format(context),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: isEditing ? Colors.grey : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isEditing ? Colors.grey.shade300 : AppColors.divider),
                      ),
                      onPressed: isEditing ? null : () async {
                        final picked = await showTimePicker(context: context, initialTime: _time);
                        if (!context.mounted) return;
                        if (picked != null) {
                          final chosen = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute);
                          if (chosen.isBefore(DateTime.now())) {
                            await _showPastTimeNoticeDialog(context);
                            return;
                          }
                          setState(() => _time = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (isEditing) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Date and time cannot be modified once scheduled in calendar.',
                      style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text('Duration', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '1 hour 30 mins (Fixed duration)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context), 
          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
          onPressed: _isSubmitting || (isEditing && !canEditName)
              ? null
              : () {
                  final title = _titleController.text.trim();
                  final missingTitle = title.isEmpty;
                  final missingStudent = _sid == null || _sid!.isEmpty;
                  if (missingTitle || missingStudent) {
                    setState(() {
                      if (missingTitle) _titleTouched = true;
                      if (missingStudent) _studentTouched = true;
                    });
                    return;
                  }
                  _handleSchedule();
                },
          child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'Update' : 'Schedule', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _handleSchedule() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleTouched = true);
      return;
    }
    if (_sid == null || _sid!.isEmpty) {
      CenterNoticeDialog.show(
        context,
        title: 'Student Required',
        message: 'Please select an enrolled student to proceed with scheduling.',
        icon: Icons.person_search_rounded,
        iconColor: Colors.amber,
      );
      return;
    }
    setState(() => _isSubmitting = true);
    
    try {
      final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final end = start.add(Duration(minutes: _duration));

      if (widget.initialSession != null) {
        final existingStart = (widget.initialSession!['startTime'] as Timestamp?)?.toDate();
        final existingEnd = (widget.initialSession!['endTime'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        if (existingStart != null && existingEnd != null) {
          if (now.isAfter(existingStart) && now.isBefore(existingEnd)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot edit an ongoing mentorship session!'), backgroundColor: Colors.red),
            );
            setState(() => _isSubmitting = false);
            return;
          }
          if (now.isAfter(existingEnd)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot edit past session!'), backgroundColor: Colors.red),
            );
            setState(() => _isSubmitting = false);
            return;
          }
        }

        final sessionId = widget.initialSession!['id']?.toString() ?? '';
        await DatabaseService.instance.updateMentorshipSession(
          sessionId: sessionId,
          studentId: _sid!,
          studentName: _snam ?? 'Student',
          startTime: existingStart ?? start,
          endTime: existingEnd ?? end,
          conferenceApp: 'meet',
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
        if (start.isBefore(DateTime.now())) {
          if (mounted) await _showPastTimeNoticeDialog(context);
          setState(() => _isSubmitting = false);
          return;
        }

        await DatabaseService.instance.createMentorshipSession(
          educatorId: widget.user.uid,
          studentId: _sid!,
          studentName: _snam ?? 'Student',
          startTime: start,
          endTime: end,
          conferenceApp: 'meet',
          meetingTitle: _titleController.text.trim(),
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mentorship scheduled! Tap "Join Conference" when ready.'),
              backgroundColor: Color(0xFF81B655),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('overlap') || errorMsg.contains('conflict') || errorMsg.contains('same') || errorMsg.contains('already have') || errorMsg.contains('already scheduled')) {
          await _showScheduleConflictDialog(context, errorMsg);
        } else if (errorMsg.contains('past')) {
          await _showPastTimeNoticeDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class EducatorSetAvailabilityDialog extends StatefulWidget {
  final User user;
  const EducatorSetAvailabilityDialog({super.key, required this.user});

  @override
  State<EducatorSetAvailabilityDialog> createState() => _EducatorSetAvailabilityDialogState();
}

class _EducatorSetAvailabilityDialogState extends State<EducatorSetAvailabilityDialog> {
  final _topicController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late TimeOfDay _startTime;
  bool _isSaving = false;
  bool _titleTouched = false;
  String _slotFilter = 'Open'; // 'Open', 'Booked'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    int nextHour = now.minute > 30 ? (now.hour + 2) : (now.hour + 1);
    if (nextHour >= 24) {
      _selectedDate = now.add(const Duration(days: 1));
      nextHour = nextHour % 24;
    }
    _startTime = TimeOfDay(hour: nextHour, minute: 0);
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = startDateTime.add(const Duration(minutes: 90));
    final timeRangeStr = '${DateFormat('h:mm a').format(startDateTime)} - ${DateFormat('h:mm a').format(endDateTime)} (1h 30m)';

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
            child: const Icon(Icons.event_available_rounded, color: Color(0xFF81B655), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set Mentorship Availability', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Open slots for your enrolled learners', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Topic
              const Text.rich(
                TextSpan(
                  text: 'Session Topic / Title',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _topicController,
                onChanged: (_) {
                  if (_titleTouched && mounted) setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Enter session topic or title (e.g. Grammar Practice & Coaching)',
                  errorText: _titleTouched && _topicController.text.trim().isEmpty ? 'Topic / Title is required' : null,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Date & Time pickers
              const Text('Date & Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(DateFormat('EEE, MMM d').format(_selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate.isBefore(DateTime.now()) ? DateTime.now() : _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (!context.mounted) return;
                        if (picked != null) {
                          final chosen = DateTime(picked.year, picked.month, picked.day, _startTime.hour, _startTime.minute);
                          if (chosen.isBefore(DateTime.now())) {
                            await _showPastTimeNoticeDialog(context);
                            return;
                          }
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(_startTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (!context.mounted) return;
                        if (picked != null) {
                          final chosen = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, picked.hour, picked.minute);
                          if (chosen.isBefore(DateTime.now())) {
                            await _showPastTimeNoticeDialog(context);
                            return;
                          }
                          setState(() => _startTime = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Duration notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF81B655).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF81B655).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Color(0xFF81B655), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Session duration: $timeRangeStr (Fixed 1 hr 30 mins)',
                        style: const TextStyle(
                          color: Color(0xFF81B655),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Add Slot Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(_isSaving ? 'Adding Slot...' : 'Add Availability Slot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81B655),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _addSlot,
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // Existing Availability Slots for this Educator
              const Text('Your Availability Slots', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: DatabaseService.instance.streamEducatorAvailability(widget.user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                  }
                  final allSlots = List<Map<String, dynamic>>.from(snapshot.data ?? []);
                  allSlots.sort((a, b) {
                    final ta = (a['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final tb = (b['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return ta.compareTo(tb);
                  });

                  final openCount = allSlots.where((s) => s['isBooked'] != true).length;
                  final bookedCount = allSlots.where((s) => s['isBooked'] == true).length;
                  final slots = allSlots.where((s) {
                    if (_slotFilter == 'Open') return s['isBooked'] != true;
                    if (_slotFilter == 'Booked') return s['isBooked'] == true;
                    return true;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text('Open ($openCount)'),
                            selected: _slotFilter == 'Open',
                            selectedColor: Colors.amber.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _slotFilter == 'Open'
                                  ? Colors.amber.shade800
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            onSelected: (_) => setState(() => _slotFilter = 'Open'),
                          ),
                          ChoiceChip(
                            label: Text('Booked ($bookedCount)'),
                            selected: _slotFilter == 'Booked',
                            selectedColor: const Color(0xFF81B655).withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _slotFilter == 'Booked'
                                  ? const Color(0xFF81B655)
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            onSelected: (_) => setState(() => _slotFilter = 'Booked'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (slots.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No ${_slotFilter.toLowerCase()} availability slots found.',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ...slots.map((slot) {
                          final slotId = slot['id']?.toString() ?? '';
                          final start = (slot['startTime'] as Timestamp).toDate();
                          final isBooked = slot['isBooked'] == true;
                          final bookedByName = slot['bookedByName']?.toString();
                          final title = slot['title']?.toString() ?? '1-on-1 Mentorship';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isBooked
                                    ? const Color(0xFF81B655).withValues(alpha: 0.4)
                                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBooked ? const Color(0xFF81B655).withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isBooked ? 'BOOKED' : 'OPEN',
                                    style: TextStyle(
                                      color: isBooked ? const Color(0xFF81B655) : Colors.amber.shade800,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('EEE, MMM d, yyyy • h:mm a').format(start),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        isBooked ? 'Booked by: ${bookedByName ?? "Subscriber"}' : '$title • 1h 30m',
                                        style: TextStyle(fontSize: 12, color: isBooked ? const Color(0xFF81B655) : Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isBooked)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    tooltip: 'Remove slot',
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                                              SizedBox(width: 8),
                                              Text('Delete Slot?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                            ],
                                          ),
                                          content: const Text(
                                            'Are you sure you want to delete this available mentorship slot? This action cannot be undone.',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await DatabaseService.instance.deleteMentorshipAvailabilitySlot(slotId);
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text('Availability slot deleted.')),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
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

  Future<void> _addSlot() async {
    final title = _topicController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleTouched = true);
      return;
    }

    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    if (start.isBefore(DateTime.now())) {
      if (mounted) await _showPastTimeNoticeDialog(context);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final educatorDoc = await DatabaseService.instance.getUserDoc(widget.user.uid);
      final educatorName = educatorDoc?['username'] ?? widget.user.displayName ?? 'Educator';

      await DatabaseService.instance.createMentorshipAvailabilitySlot(
        educatorId: widget.user.uid,
        educatorName: educatorName,
        startTime: start,
        title: _topicController.text.trim(),
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Availability slot added (1h 30m session)!'),
            backgroundColor: Color(0xFF81B655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('overlap') || errorMsg.contains('conflict') || errorMsg.contains('same') || errorMsg.contains('already have') || errorMsg.contains('already exists')) {
          await _showScheduleConflictDialog(context, errorMsg);
        } else if (errorMsg.contains('past')) {
          await _showPastTimeNoticeDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $errorMsg'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
