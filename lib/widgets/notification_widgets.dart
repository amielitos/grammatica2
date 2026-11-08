import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../services/agora_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/role_service.dart';
import '../pages/conference_page.dart';
import '../pages/educator_profile_page.dart';
import '../pages/lesson_page.dart';
import 'package:intl/intl.dart';

class NotificationIconButton extends StatefulWidget {
  final String userId;
  final VoidCallback onTap;

  const NotificationIconButton({
    super.key,
    required this.userId,
    required this.onTap,
  });

  @override
  State<NotificationIconButton> createState() => _NotificationIconButtonState();
}

class _NotificationIconButtonState extends State<NotificationIconButton> {
  late Stream<List<NotificationModel>> _notificationStream;

  @override
  void initState() {
    super.initState();
    _notificationStream = NotificationService.instance.streamNotifications(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationStream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.isRead).length;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(CupertinoIcons.bell, color: isDark ? Colors.white : Colors.black87),
              onPressed: widget.onTap,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDE372A),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class NotificationOverlay extends StatefulWidget {
  final String userId;
  final VoidCallback onClose;

  const NotificationOverlay({
    super.key,
    required this.userId,
    required this.onClose,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  bool _showArchived = false;
  late Stream<List<NotificationModel>> _notificationStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    _notificationStream = NotificationService.instance.streamNotifications(
      widget.userId,
      archived: _showArchived,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showArchived ? 'Archive' : 'Notifications',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _showArchived
                              ? CupertinoIcons.list_bullet
                              : CupertinoIcons.archivebox,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _showArchived = !_showArchived;
                            _updateStream();
                          });
                        },
                        tooltip: _showArchived ? 'Show Active' : 'Show Archive',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        icon: const Icon(CupertinoIcons.xmark, size: 20),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _notificationStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        _showArchived
                            ? 'No archived notifications'
                            : 'No notifications yet',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final notifications = snapshot.data!;
                  return ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return NotificationTile(
                        notification: n,
                        onTap: () => _showDetails(context, n),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, NotificationModel n) {
    _navigateToNotificationTarget(context, n);
  }
}

class NotificationsDialog extends StatefulWidget {
  final String userId;

  const NotificationsDialog({super.key, required this.userId});

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  bool _showArchived = false;
  late Stream<List<NotificationModel>> _notificationStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    _notificationStream = NotificationService.instance.streamNotifications(
      widget.userId,
      archived: _showArchived,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = min(screenWidth - 16.0, 420.0);
    final isMobile = screenWidth < 500;

    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: isMobile ? Alignment.topCenter : Alignment.topRight,
      insetPadding: EdgeInsets.only(
        top: 70,
        right: isMobile ? 8 : 20,
        left: isMobile ? 8 : 20,
        bottom: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: panelWidth,
          maxHeight: min(MediaQuery.sizeOf(context).height * 0.82, 600.0),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showArchived ? 'Archive' : 'Notifications',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_showArchived)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.done_all, color: Colors.blueAccent),
                                      SizedBox(width: 8),
                                      Text('Mark All as Read', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: const Text(
                                    'Are you sure you want to mark all notifications as read?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Mark All Read'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                NotificationService.instance.markAllAsRead(widget.userId);
                              }
                            },
                            child: const Text('Mark all as read', style: TextStyle(fontSize: 11)),
                          ),
                        const SizedBox(width: 2),
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _showArchived
                                ? CupertinoIcons.tray_fill
                                : CupertinoIcons.archivebox,
                            size: 19,
                          ),
                          onPressed: () {
                            setState(() {
                              _showArchived = !_showArchived;
                              _updateStream();
                            });
                          },
                          tooltip: _showArchived
                              ? 'Show Active'
                              : 'Show Archive',
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: const Icon(CupertinoIcons.xmark, size: 19),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<NotificationModel>>(
                  stream: _notificationStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showArchived ? CupertinoIcons.archivebox : CupertinoIcons.bell_slash,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showArchived
                                  ? 'No archived notifications'
                                  : 'No notifications yet',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    final notifications = snapshot.data!;
                    return ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        return NotificationTile(
                          notification: n,
                          onTap: () => _showDetails(context, n),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, NotificationModel n) {
    _navigateToNotificationTarget(context, n);
  }
}

Future<void> openLessonFromNotification(BuildContext context, NotificationModel n) async {
  if (!n.isRead) {
    NotificationService.instance.markAsRead(n.id);
  }

  String lessonTitle = '';
  if (n.title.startsWith('New Lesson: ')) {
    lessonTitle = n.title.substring('New Lesson: '.length).trim();
  } else if (n.message.contains('"')) {
    final match = RegExp(r'"([^"]*)"').firstMatch(n.message);
    if (match != null) {
      lessonTitle = match.group(1) ?? '';
    }
  }
  if (lessonTitle.isEmpty) {
    lessonTitle = n.title.trim();
  }

  final nav = Navigator.of(context, rootNavigator: true);
  final currentUid = AuthService.maybeLiveUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
  final currentRole = currentUid != null
      ? await RoleService.instance.getRole(currentUid)
      : UserRole.learner;

  bool canViewLesson(Lesson l) {
    if (l.isArchived) return false;
    if (l.validationStatus == 'approved') return true;
    final isAuthor = currentUid != null && l.createdByUid == currentUid;
    final isValidator = currentRole == UserRole.validator;
    return isAuthor || isValidator;
  }

  Lesson? resolvedLesson;

  // 1. Try finding by lessonId
  if (n.lessonId != null && n.lessonId!.isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance.collection('lessons').doc(n.lessonId).get();
      if (doc.exists && doc.data() != null) {
        final cand = Lesson.fromDoc(doc);
        if (canViewLesson(cand)) {
          resolvedLesson = cand;
        }
      }
    } catch (_) {}
  }

  // 2. Try finding by exact title
  if (resolvedLesson == null && lessonTitle.isNotEmpty) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lessons')
          .where('title', isEqualTo: lessonTitle)
          .limit(5)
          .get();
      for (final doc in snap.docs) {
        final cand = Lesson.fromDoc(doc);
        if (canViewLesson(cand)) {
          resolvedLesson = cand;
          break;
        }
      }
    } catch (_) {}
  }

  // 3. Try finding within educator lessons
  if (resolvedLesson == null && n.educatorId != null && n.educatorId!.isNotEmpty) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lessons')
          .where('createdByUid', isEqualTo: n.educatorId)
          .limit(10)
          .get();
      for (final doc in snap.docs) {
        final cand = Lesson.fromDoc(doc);
        if (!canViewLesson(cand)) continue;
        if (cand.title.toLowerCase().trim() == lessonTitle.toLowerCase().trim() ||
            cand.title.toLowerCase().contains(lessonTitle.toLowerCase()) ||
            lessonTitle.toLowerCase().contains(cand.title.toLowerCase())) {
          resolvedLesson = cand;
          break;
        }
      }
    } catch (_) {}
  }

  // 4. Try finding across all recent lessons
  if (resolvedLesson == null && lessonTitle.isNotEmpty) {
    try {
      final snap = await FirebaseFirestore.instance.collection('lessons').limit(50).get();
      final target = lessonTitle.toLowerCase().trim();
      for (final doc in snap.docs) {
        final cand = Lesson.fromDoc(doc);
        if (!canViewLesson(cand)) continue;
        final candTitle = cand.title.toLowerCase().trim();
        if (candTitle == target || candTitle.contains(target) || target.contains(candTitle)) {
          resolvedLesson = cand;
          break;
        }
      }
    } catch (_) {}
  }

  // Close open dialog/sheet
  try {
    nav.pop();
  } catch (_) {}

  if (!nav.mounted) return;

  if (resolvedLesson != null) {
    DatabaseService.lastViewedLessonId = resolvedLesson.id;
    final liveUser = AuthService.liveUser;
    DatabaseService.instance.recordLessonViewed(
      user: liveUser,
      lessonId: resolvedLesson.id,
    );
    nav.push(
      MaterialPageRoute(
        builder: (_) => LessonPage(
          user: liveUser,
          lesson: resolvedLesson!,
        ),
      ),
    );
  } else {
    // Fallback: if educatorId is known, go to educator profile
    if (n.educatorId != null && n.educatorId!.isNotEmpty) {
      final eduDoc = await DatabaseService.instance.getUserDoc(n.educatorId!);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (eduDoc != null && currentUser != null && nav.mounted) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => EducatorProfilePage(
              educator: eduDoc,
              currentUser: currentUser,
            ),
          ),
        );
      }
    }
  }
}

Future<void> navigateToNotificationTarget(
  BuildContext context,
  NotificationModel n, {
  bool closeCurrent = true,
}) async {
  if (!n.isRead) {
    NotificationService.instance.markAsRead(n.id);
  }

  final nav = Navigator.of(context, rootNavigator: true);
  final isMentorship = n.type == NotificationType.mentorship ||
      n.title.toLowerCase().contains('mentorship') ||
      n.message.toLowerCase().contains('scheduled');

  if (isMentorship) {
    final isPast = await checkIsMentorshipSessionPast(n);
    if (!nav.mounted) return;

    if (closeCurrent && nav.canPop()) {
      nav.pop();
    }

    if (isPast) {
      showSessionEndedDialog(nav.context);
      return;
    }

    showDialog(
      context: nav.context,
      builder: (_) => MentorshipScheduleDialog(notification: n),
    );
    return;
  }

  if (closeCurrent && nav.canPop()) {
    nav.pop();
  }

  // Pop-up modal containing "VIEW LESSON" button
  showDialog(
    context: nav.context,
    builder: (context) => NotificationDetailDialog(notification: n),
  );
}

Future<void> _navigateToNotificationTarget(BuildContext context, NotificationModel n) =>
    navigateToNotificationTarget(context, n);

class MentorshipScheduleDialog extends StatefulWidget {
  final NotificationModel notification;

  const MentorshipScheduleDialog({
    super.key,
    required this.notification,
  });

  @override
  State<MentorshipScheduleDialog> createState() =>
      _MentorshipScheduleDialogState();
}

void showSessionEndedDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Session Ended',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'This mentorship session has already ended and can no longer be joined.',
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white70 : const Color(0xFF334155),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF16A34A),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'OK',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

bool isNotificationMentorshipExpired(NotificationModel notification) {
  // Check 1: 10-minute reminder notification
  // Notification title: "Mentorship Session in 10 Minutes! 🔔"
  // Mentorship sessions strictly last 90 minutes.
  // After 100 minutes from reminder creation, the session has definitely ended.
  final titleLower = notification.title.toLowerCase();
  final msgLower = notification.message.toLowerCase();
  if (titleLower.contains('10 minute') || msgLower.contains('starts in 10 minutes')) {
    if (DateTime.now().difference(notification.createdAt).inMinutes >= 100) {
      return true;
    }
  }

  // Check 2: Parse date from message if present
  final msg = notification.message;
  String? timeStr;
  if (msg.contains(' for ')) {
    final parts = msg.split(' for ');
    timeStr = parts.sublist(1).join(' for ').trim();
  } else if (msg.contains(' scheduled at ')) {
    timeStr = msg.split(' scheduled at ').last.trim();
  }

  if (timeStr != null && timeStr.isNotEmpty) {
    if (timeStr.endsWith('.')) {
      timeStr = timeStr.substring(0, timeStr.length - 1).trim();
    }
    if (timeStr.startsWith('"') && timeStr.endsWith('"')) {
      timeStr = timeStr.substring(1, timeStr.length - 1).trim();
    }
    for (final pattern in [
      'EEE, MMM d, yyyy @ h:mm a',
      'EEEE, MMMM d, yyyy • h:mm a',
      'EEEE, MMMM d, yyyy @ h:mm a',
      'MMMM d, yyyy @ h:mm a',
      'MMM d, yyyy @ h:mm a',
      'EEE, MMM d, yyyy h:mm a',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd h:mm a',
    ]) {
      try {
        final parsed = DateFormat(pattern).parse(timeStr);
        final endTime = parsed.add(const Duration(minutes: 90));
        if (DateTime.now().isAfter(endTime)) {
          return true;
        }
      } catch (_) {}
    }
  }
  return false;
}

Future<bool> checkIsMentorshipSessionPast(NotificationModel notification) async {
  // Fast check from notification text / time
  if (isNotificationMentorshipExpired(notification)) {
    return true;
  }

  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? notification.uid;
    final targetUid = notification.uid;
    final eduId = notification.educatorId;

    final uidsToSearch = <String>{};
    if (currentUid.isNotEmpty) uidsToSearch.add(currentUid);
    if (targetUid.isNotEmpty) uidsToSearch.add(targetUid);
    if (eduId != null && eduId.isNotEmpty) uidsToSearch.add(eduId);

    final List<Map<String, dynamic>> matchingSessions = [];

    // Query for sessions where user is student or educator
    for (final uid in uidsToSearch) {
      try {
        final studentSnap = await FirebaseFirestore.instance
            .collection('mentorship_sessions')
            .where('studentId', isEqualTo: uid)
            .get();
        for (final doc in studentSnap.docs) {
          final data = doc.data();
          data['_id'] = doc.id;
          matchingSessions.add(data);
        }
      } catch (_) {}

      try {
        final educatorSnap = await FirebaseFirestore.instance
            .collection('mentorship_sessions')
            .where('educatorId', isEqualTo: uid)
            .get();
        for (final doc in educatorSnap.docs) {
          final data = doc.data();
          data['_id'] = doc.id;
          matchingSessions.add(data);
        }
      } catch (_) {}
    }

    // Deduplicate by _id
    final uniqueSessions = <String, Map<String, dynamic>>{};
    for (final s in matchingSessions) {
      final id = s['_id'] as String;
      uniqueSessions[id] = s;
    }

    if (uniqueSessions.isNotEmpty) {
      // Try to find the session corresponding to this notification
      final titleMatch = RegExp(r'"([^"]*)"').firstMatch(notification.message);
      final titleFromMsg = titleMatch?.group(1)?.trim().toLowerCase();

      Map<String, dynamic>? bestMatch;

      if (titleFromMsg != null && titleFromMsg.isNotEmpty) {
        for (final s in uniqueSessions.values) {
          final mt = (s['meetingTitle'] ?? '').toString().trim().toLowerCase();
          if (mt == titleFromMsg) {
            bestMatch = s;
            break;
          }
        }
      }

      if (bestMatch == null) {
        int bestDiff = 999999999999;
        for (final s in uniqueSessions.values) {
          DateTime? sTime;
          if (s['startTime'] is Timestamp) {
            sTime = (s['startTime'] as Timestamp).toDate();
          } else if (s['createdAt'] is Timestamp) {
            sTime = (s['createdAt'] as Timestamp).toDate();
          }
          if (sTime != null) {
            final diff = (sTime.difference(notification.createdAt).inSeconds).abs();
            if (diff < bestDiff) {
              bestDiff = diff;
              bestMatch = s;
            }
          }
        }
      }

      bestMatch ??= uniqueSessions.values.first;

      final status = (bestMatch['status'] ?? '').toString().toLowerCase();
      if (status == 'completed' || status == 'cancelled') {
        return true;
      }

      final startTs = bestMatch['startTime'] as Timestamp?;
      final endTs = bestMatch['endTime'] as Timestamp?;
      final now = DateTime.now();

      if (endTs != null) {
        if (now.isAfter(endTs.toDate())) {
          return true;
        }
      } else if (startTs != null) {
        if (now.isAfter(startTs.toDate().add(const Duration(minutes: 90)))) {
          return true;
        }
      }
    } else {
      if (DateTime.now().difference(notification.createdAt).inHours >= 2) {
        return true;
      }
    }
  } catch (e) {
    debugPrint('Error checking if mentorship session is past: $e');
  }

  return false;
}

class _MentorshipScheduleDialogState extends State<MentorshipScheduleDialog> {
  String? _educatorName;
  String? _educatorId;
  String? _sessionTitle;
  String? _timeStr;
  String? _meetingLink;
  String? _agoraChannel;
  String? _sessionId;
  String? _sessionStatus;
  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;

  bool get _isPastSession {
    if (_sessionStatus != null &&
        (_sessionStatus!.toLowerCase() == 'completed' ||
         _sessionStatus!.toLowerCase() == 'cancelled')) {
      return true;
    }
    final now = DateTime.now();
    if (_sessionEndTime != null) {
      return now.isAfter(_sessionEndTime!);
    }
    if (_sessionStartTime != null) {
      return now.isAfter(_sessionStartTime!.add(const Duration(minutes: 90)));
    }
    return isNotificationMentorshipExpired(widget.notification);
  }

  @override
  void initState() {
    super.initState();
    _loadMentorshipDetails();
  }

  Future<void> _loadMentorshipDetails() async {
    final n = widget.notification;
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? n.uid;

    // Parse fallback info from notification message:
    // Format: "$educatorName scheduled \"$titleStr\" for $dateStr."
    String fallbackName = 'Your Educator';
    String fallbackTitle = 'Mentorship Session';
    String fallbackTime = '';

    if (n.message.contains(' scheduled ')) {
      final parts = n.message.split(' scheduled ');
      if (parts.first.trim().isNotEmpty) {
        fallbackName = parts.first.trim();
      }
      if (parts.length > 1) {
        final rest = parts[1];
        if (rest.contains(' for ')) {
          final titleAndDate = rest.split(' for ');
          fallbackTitle = titleAndDate.first.replaceAll('"', '').trim();
          fallbackTime = titleAndDate.sublist(1).join(' for ').trim();
          if (fallbackTime.endsWith('.')) {
            fallbackTime = fallbackTime.substring(0, fallbackTime.length - 1);
          }
        } else {
          fallbackTitle = rest.trim();
        }
      }
    }

    _educatorName = fallbackName;
    _sessionTitle = fallbackTitle;
    _timeStr = fallbackTime.isNotEmpty
        ? fallbackTime
        : DateFormat('EEE, MMM d, yyyy @ h:mm a').format(n.createdAt);

    try {
      final List<Map<String, dynamic>> candidateSessions = [];
      final List<String> sessionDocIds = [];

      // 1. Query mentorship_sessions where studentId == currentUid
      try {
        final snapStudent = await FirebaseFirestore.instance
            .collection('mentorship_sessions')
            .where('studentId', isEqualTo: currentUid)
            .get();
        for (final doc in snapStudent.docs) {
          candidateSessions.add(doc.data());
          sessionDocIds.add(doc.id);
        }
      } catch (_) {}

      // 2. Query mentorship_sessions where educatorId == currentUid (for educator)
      try {
        final snapEducator = await FirebaseFirestore.instance
            .collection('mentorship_sessions')
            .where('educatorId', isEqualTo: currentUid)
            .get();
        for (final doc in snapEducator.docs) {
          if (!sessionDocIds.contains(doc.id)) {
            candidateSessions.add(doc.data());
            sessionDocIds.add(doc.id);
          }
        }
      } catch (_) {}

      // 3. Fallback: if educatorId is specified on the notification
      if (candidateSessions.isEmpty && n.educatorId != null && n.educatorId!.isNotEmpty) {
        try {
          final snapEdu = await FirebaseFirestore.instance
              .collection('mentorship_sessions')
              .where('educatorId', isEqualTo: n.educatorId)
              .get();
          for (final doc in snapEdu.docs) {
            if (!sessionDocIds.contains(doc.id)) {
              candidateSessions.add(doc.data());
              sessionDocIds.add(doc.id);
            }
          }
        } catch (_) {}
      }

      if (candidateSessions.isNotEmpty) {
        int bestIndex = -1;
        final targetTitle = fallbackTitle.toLowerCase();
        for (int i = 0; i < candidateSessions.length; i++) {
          final mt = (candidateSessions[i]['meetingTitle'] ?? '').toString().trim().toLowerCase();
          if (mt.isNotEmpty && (mt == targetTitle || targetTitle.contains(mt) || mt.contains(targetTitle))) {
            bestIndex = i;
            break;
          }
        }

        if (bestIndex == -1) {
          int bestDiff = 999999999999;
          for (int i = 0; i < candidateSessions.length; i++) {
            final startTs = candidateSessions[i]['startTime'] as Timestamp?;
            if (startTs != null) {
              final diff = (startTs.toDate().difference(n.createdAt).inSeconds).abs();
              if (diff < bestDiff) {
                bestDiff = diff;
                bestIndex = i;
              }
            }
          }
        }

        if (bestIndex == -1) bestIndex = 0;

        final data = candidateSessions[bestIndex];
        _sessionId = sessionDocIds[bestIndex];
        _meetingLink = data['meetingLink'] as String?;
        _agoraChannel = data['agoraChannel'] as String?;
        _sessionStatus = data['status'] as String?;
        _educatorId = data['educatorId'] as String? ?? n.educatorId;
        if (data['meetingTitle'] != null && data['meetingTitle'].toString().isNotEmpty) {
          _sessionTitle = data['meetingTitle'].toString();
        }
        final startTs = data['startTime'] as Timestamp?;
        final endTs = data['endTime'] as Timestamp?;
        if (startTs != null) {
          final dt = startTs.toDate();
          _sessionStartTime = dt;
          _sessionEndTime = endTs?.toDate() ?? dt.add(const Duration(minutes: 90));
          _timeStr = DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(dt);
        }

        final otherUid = (currentUser?.uid == _educatorId)
            ? (data['studentId'] as String?)
            : _educatorId;
        if (otherUid != null && otherUid.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUid).get();
          if (userDoc.exists && userDoc.data() != null) {
            final u = userDoc.data()?['username'] as String?;
            if (u != null && u.isNotEmpty) {
              _educatorName = u;
            }
          }
        }
      } else if (n.educatorId != null && n.educatorId!.isNotEmpty) {
        final eduDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(n.educatorId)
            .get();
        if (eduDoc.exists && eduDoc.data() != null) {
          final u = eduDoc.data()?['username'] as String?;
          if (u != null && u.isNotEmpty) {
            _educatorName = u;
          }
        }
      }
      if (_sessionStartTime == null && fallbackTime.isNotEmpty) {
        for (final pattern in [
          'EEE, MMM d, yyyy @ h:mm a',
          'EEEE, MMMM d, yyyy • h:mm a',
          'MMMM d, yyyy @ h:mm a',
          'MMM d, yyyy @ h:mm a',
        ]) {
          try {
            _sessionStartTime = DateFormat(pattern).parse(fallbackTime);
            _sessionEndTime = _sessionStartTime!.add(const Duration(minutes: 90));
            break;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error loading mentorship session details: $e');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleJoin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_isPastSession) {
      if (mounted) {
        showSessionEndedDialog(context);
      }
      return;
    }

    final nav = Navigator.of(context, rootNavigator: true);

    if (_sessionId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('mentorship_sessions').doc(_sessionId).get();
        if (doc.exists) {
          final data = doc.data()!;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final endTs = data['endTime'] as Timestamp?;
          final startTs = data['startTime'] as Timestamp?;
          final now = DateTime.now();
          bool isEnded = (status == 'completed' || status == 'cancelled');
          if (endTs != null && now.isAfter(endTs.toDate())) {
            isEnded = true;
          } else if (startTs != null && now.isAfter(startTs.toDate().add(const Duration(minutes: 90)))) {
            isEnded = true;
          }
          if (isEnded) {
            if (mounted) {
              setState(() {
                _sessionStatus = 'completed';
              });
              showSessionEndedDialog(nav.context);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Error verifying session live status: $e');
      }
    }

    if (!nav.mounted) return;
    nav.pop();

    // If external link provided and non-empty
    if (_meetingLink != null &&
        _meetingLink!.trim().isNotEmpty &&
        (_meetingLink!.startsWith('http://') || _meetingLink!.startsWith('https://'))) {
      try {
        final uri = Uri.parse(_meetingLink!.trim());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        debugPrint('Error launching meeting link: $e');
      }
    }

    // Default to in-app Agora conference
    final effectiveSessionId = _sessionId ?? 'session_${widget.notification.id}';
    final effectiveChannel = (_agoraChannel != null && _agoraChannel!.isNotEmpty)
        ? _agoraChannel!
        : AgoraService.instance.channelFromSessionId(effectiveSessionId);

    final isHost = (currentUser.uid == _educatorId) ||
                   (widget.notification.educatorId == currentUser.uid);

    nav.push(
      MaterialPageRoute(
        builder: (_) => ConferencePage(
          channelName: effectiveChannel,
          sessionId: effectiveSessionId,
          sessionTitle: _sessionTitle ?? 'Mentorship Session',
          otherParticipantName: _educatorName ?? (isHost ? 'Learner' : 'Educator'),
          isHost: isHost,
          currentUser: currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentGreen = Color(0xFF16A34A);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentGreen.withValues(alpha: isDark ? 0.25 : 0.12),
                      accentGreen.withValues(alpha: isDark ? 0.08 : 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: accentGreen.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentGreen.withValues(alpha: isDark ? 0.3 : 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentGreen.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.video_camera_front_rounded,
                        color: accentGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mentorship Session Scheduled',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '1-on-1 Interactive Video Call',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content Body - Scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Educator info message
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: accentGreen.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.person,
                            color: accentGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _educatorName ?? 'Educator',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Scheduled an interactive mentorship session with you.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Topic
                    if (_sessionTitle != null && _sessionTitle!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.topic_outlined,
                              size: 16,
                              color: accentGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _sessionTitle!,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Time display card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accentGreen.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accentGreen.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentGreen.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              color: accentGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCHEDULED TIME',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: accentGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _timeStr ?? 'Time not set',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    ],
                  ),
                ),
              ),

              // Pinned Actions
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  12 + MediaQuery.of(context).viewPadding.bottom,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPastSession
                              ? (isDark ? Colors.white12 : Colors.grey.shade300)
                              : accentGreen,
                          foregroundColor: _isPastSession
                              ? (isDark ? Colors.white38 : Colors.grey.shade600)
                              : Colors.white,
                          disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                          disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          _isPastSession ? Icons.event_busy_rounded : Icons.video_call_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _isPastSession ? 'SESSION ENDED' : 'JOIN',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: _isPastSession
                            ? () => showSessionEndedDialog(context)
                            : _handleJoin,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.lessonUpload:
        return const Color(0xFF0D9488);
      case NotificationType.appApproved:
        return const Color(0xFF16A34A);
      case NotificationType.appRejected:
        return const Color(0xFFDC2626);
      case NotificationType.achievement:
        return const Color(0xFFF59E0B);
      case NotificationType.subscription:
        return const Color(0xFF6366F1);
      case NotificationType.mentorship:
        return const Color(0xFF0284C7);
      case NotificationType.welcome:
        return const Color(0xFFEC4899);
      case NotificationType.profileReminder:
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.lessonUpload:
        return 'NEW LESSON';
      case NotificationType.appApproved:
        return 'APPROVED';
      case NotificationType.appRejected:
        return 'UPDATE REQUIRED';
      case NotificationType.achievement:
        return 'ACHIEVEMENT';
      case NotificationType.subscription:
        return 'ENROLLMENT';
      case NotificationType.mentorship:
        return 'MENTORSHIP';
      case NotificationType.welcome:
        return 'WELCOME';
      case NotificationType.profileReminder:
        return 'PROFILE';
      default:
        return 'SYSTEM';
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.lessonUpload:
        return CupertinoIcons.book_fill;
      case NotificationType.welcome:
        return CupertinoIcons.heart_fill;
      case NotificationType.appRejected:
        return CupertinoIcons.xmark_circle_fill;
      case NotificationType.appApproved:
        return CupertinoIcons.check_mark_circled_solid;
      case NotificationType.achievement:
        return CupertinoIcons.star_fill;
      case NotificationType.profileReminder:
        return CupertinoIcons.person_crop_circle_badge_exclam;
      case NotificationType.subscription:
        return CupertinoIcons.person_2_fill;
      case NotificationType.mentorship:
        return CupertinoIcons.calendar_today;
      default:
        return CupertinoIcons.info_circle_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !notification.isRead;
    final typeColor = _getTypeColor(notification.type);
    final typeLabel = _getTypeLabel(notification.type);
    final iconData = _getIcon(notification.type);

    final isMentorship = notification.type == NotificationType.mentorship ||
        (notification.educatorId != null && notification.educatorId!.isNotEmpty) ||
        notification.title.toLowerCase().contains('mentorship') ||
        notification.message.toLowerCase().contains('scheduled');

    return Container(
      decoration: BoxDecoration(
        color: isUnread
            ? typeColor.withValues(alpha: isDark ? 0.14 : 0.06)
            : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isUnread ? typeColor : Colors.transparent,
            width: 4.0,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: isDark ? 0.22 : 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: typeColor.withValues(alpha: isUnread ? 0.5 : 0.2),
              width: 1.5,
            ),
          ),
          child: Icon(
            iconData,
            size: 20,
            color: typeColor,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: Text(
                notification.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  height: 1.3,
                ),
              ),
              if (isMentorship || notification.type == NotificationType.lessonUpload)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 12, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        notification.type == NotificationType.lessonUpload
                            ? 'Tap to view educator lesson'
                            : (isMentorship
                                ? 'Tap to view mentorship schedule'
                                : 'Tap to view educator profile'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('MMM d').format(notification.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationDetailDialog extends StatelessWidget {
  final NotificationModel notification;

  const NotificationDetailDialog({super.key, required this.notification});

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.lessonUpload:
        return const Color(0xFF0D9488);
      case NotificationType.appApproved:
        return const Color(0xFF16A34A);
      case NotificationType.appRejected:
        return const Color(0xFFDC2626);
      case NotificationType.achievement:
        return const Color(0xFFF59E0B);
      case NotificationType.subscription:
        return const Color(0xFF6366F1);
      case NotificationType.mentorship:
        return const Color(0xFF0284C7);
      case NotificationType.welcome:
        return const Color(0xFFEC4899);
      case NotificationType.profileReminder:
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.lessonUpload:
        return 'NEW LESSON';
      case NotificationType.appApproved:
        return 'APPROVED';
      case NotificationType.appRejected:
        return 'UPDATE REQUIRED';
      case NotificationType.achievement:
        return 'ACHIEVEMENT';
      case NotificationType.subscription:
        return 'ENROLLMENT';
      case NotificationType.mentorship:
        return 'MENTORSHIP';
      case NotificationType.welcome:
        return 'WELCOME';
      case NotificationType.profileReminder:
        return 'REMINDER';
      default:
        return 'NOTIFICATION';
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.lessonUpload:
        return Icons.auto_stories_rounded;
      case NotificationType.appApproved:
        return Icons.check_circle_rounded;
      case NotificationType.appRejected:
        return Icons.error_rounded;
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.subscription:
        return Icons.card_membership_rounded;
      case NotificationType.mentorship:
        return Icons.calendar_today_rounded;
      case NotificationType.welcome:
        return Icons.favorite_rounded;
      case NotificationType.profileReminder:
        return Icons.person_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(notification.type);
    final typeLabel = _getTypeLabel(notification.type);
    final iconData = _getIcon(notification.type);

    final isLessonUpload = notification.type == NotificationType.lessonUpload ||
        (notification.lessonId != null && notification.lessonId!.isNotEmpty) ||
        notification.title.toLowerCase().contains('lesson');

    final isMentorship = !isLessonUpload && (
        notification.type == NotificationType.mentorship ||
        notification.title.toLowerCase().contains('mentorship') ||
        notification.message.toLowerCase().contains('scheduled'));

    final isMentorshipExpired = isMentorship && isNotificationMentorshipExpired(notification);

    String lessonTitle = '';
    if (isLessonUpload) {
      if (notification.title.startsWith('New Lesson: ')) {
        lessonTitle = notification.title.substring('New Lesson: '.length).trim();
      } else if (notification.message.contains('"')) {
        final match = RegExp(r'"([^"]*)"').firstMatch(notification.message);
        if (match != null) {
          lessonTitle = match.group(1) ?? '';
        }
      }
      if (lessonTitle.isEmpty) {
        lessonTitle = notification.title;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      typeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      typeColor.withValues(alpha: isDark ? 0.08 : 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: typeColor.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: isDark ? 0.3 : 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        iconData,
                        size: 22,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Area - Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timestamp pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM d, yyyy • h:mm a').format(notification.createdAt),
                              softWrap: true,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Main Message Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          notification.message,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            height: 1.5,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      if (isLessonUpload && lessonTitle.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Color(0xFF10B981),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LESSON TITLE',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF10B981),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lessonTitle,
                                      softWrap: true,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Rejection info if applicable
                      if (notification.type == NotificationType.appRejected) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Feedback from Validator',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification.rejectionReason ?? 'No reason provided',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              if (notification.rejectionDescription != null &&
                                  notification.rejectionDescription!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  notification.rejectionDescription!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer Actions - Pinned with SafeArea / viewPadding.bottom
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  12 + MediaQuery.of(context).viewPadding.bottom,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Archive and Delete buttons
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: Icon(
                                notification.isArchived
                                    ? Icons.unarchive_outlined
                                    : Icons.archive_outlined,
                                size: 16,
                              ),
                              label: Text(
                                notification.isArchived ? 'Restore' : 'Archive',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              onPressed: () {
                                NotificationService.instance.archiveNotification(
                                  notification.id,
                                  archive: !notification.isArchived,
                                );
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: Text(
                                'Delete',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              onPressed: () {
                                NotificationService.instance.deleteNotification(notification.id);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),

                    // Primary and Close buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isLessonUpload)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.menu_book_rounded, size: 18),
                              label: Text(
                                'VIEW LESSON',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                              ),
                              onPressed: () => openLessonFromNotification(context, notification),
                            ),
                          ),
                        if (isMentorship)
                          MouseRegion(
                            cursor: isMentorshipExpired
                                ? SystemMouseCursors.basic
                                : SystemMouseCursors.click,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMentorshipExpired
                                    ? (isDark ? Colors.white12 : Colors.grey.shade300)
                                    : const Color(0xFF16A34A),
                                foregroundColor: isMentorshipExpired
                                    ? (isDark ? Colors.white38 : Colors.grey.shade600)
                                    : Colors.white,
                                disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                                disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: Icon(
                                isMentorshipExpired ? Icons.event_busy_rounded : Icons.video_call_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isMentorshipExpired ? 'SESSION ENDED' : 'JOIN',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                              ),
                              onPressed: isMentorshipExpired
                                  ? () => showSessionEndedDialog(context)
                                  : () async {
                                      final nav = Navigator.of(context, rootNavigator: true);
                                      final isPast = await checkIsMentorshipSessionPast(notification);
                                      if (!nav.mounted) return;
                                      if (isPast) {
                                        showSessionEndedDialog(nav.context);
                                        return;
                                      }
                                      nav.pop();
                                      showDialog(
                                        context: nav.context,
                                        builder: (_) => MentorshipScheduleDialog(notification: notification),
                                      );
                                    },
                            ),
                          ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                              side: BorderSide(
                                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Close',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
