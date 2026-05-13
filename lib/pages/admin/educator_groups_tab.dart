import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';

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
            const Text('Learner', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(s['studentName'] ?? 'Mentorship', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            const Text('Date & Time', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text('$dateString\n$timeString', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text((s['status']?.toString().toUpperCase() ?? 'SCHEDULED'), style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
            if (meetingLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Meeting Link', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(meetingLink, style: const TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Session?'),
                  content: const Text('Are you sure you want to cancel this mentorship session? This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, keep it')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes, Cancel'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  await DatabaseService.instance.cancelMentorshipSession(s['id']);
                  if (context.mounted) {
                    Navigator.pop(context); // Close details dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session cancelled successfully'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error cancelling session: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Cancel Session'),
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
  const MentorshipBookingModal({super.key, required this.user});

  @override
  State<MentorshipBookingModal> createState() => _MentorshipBookingModalState();
}

class _MentorshipBookingModalState extends State<MentorshipBookingModal> {
  final _linkController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 60;
  String? _sid;
  String? _snam;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New mentorship', style: TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: DatabaseService.instance.streamEducatorSubscribers(widget.user.uid),
                builder: (context, snapshot) {
                  final subs = (snapshot.data ?? []).where((s) => 
                    s['tier']?.toString().toLowerCase() == 'premium'
                  ).toList();
                  
                  if (subs.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                    return DropdownButtonFormField<String>(
                      onChanged: null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      items: const [],
                      hint: const Text('No premium learners found', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                      return DropdownMenuItem(
                        value: uid, 
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: DatabaseService.instance.getUserDoc(uid),
                          builder: (context, userSnap) {
                            final userData = userSnap.data;
                            return Text(userData?['username'] ?? userData?['email'] ?? 'User ($uid)');
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
              const Text('Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
              const Text('Meeting link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  hintText: 'https://zoom.us/j/...',
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
            backgroundColor: const Color(0xFF4B49AC),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isSubmitting ? null : _handleSchedule,
          child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Schedule'),
        ),
      ],
    );
  }

  Future<void> _handleSchedule() async {
    if (_sid == null || _sid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final end = start.add(Duration(minutes: _duration));
      
      await DatabaseService.instance.createMentorshipSession(
        educatorId: widget.user.uid,
        studentId: _sid!,
        studentName: _snam ?? 'Student',
        startTime: start,
        endTime: end,
        meetingLink: _linkController.text,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mentorship scheduled successfully!'),
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
    _linkController.dispose();
    super.dispose();
  }
}
