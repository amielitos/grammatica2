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
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showArchived ? 'Archive' : 'Notifications',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _showArchived
                              ? CupertinoIcons.list_bullet
                              : CupertinoIcons.archivebox,
                        ),
                        onPressed: () {
                          setState(() {
                            _showArchived = !_showArchived;
                            _updateStream();
                          });
                        },
                        tooltip: _showArchived ? 'Show Active' : 'Show Archive',
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.only(
        top: 70,
        right: 20,
        left: 20,
        bottom: 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _showArchived ? 'Archive' : 'Notifications',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (!_showArchived)
                          TextButton(
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
                            child: const Text('Mark all as read', style: TextStyle(fontSize: 12)),
                          ),
                        IconButton(
                          icon: Icon(
                            _showArchived
                                ? CupertinoIcons.tray_fill
                                : CupertinoIcons.archivebox,
                            size: 20,
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
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark, size: 20),
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

Future<void> _navigateToNotificationTarget(BuildContext context, NotificationModel n) async {
  if (!n.isRead) {
    NotificationService.instance.markAsRead(n.id);
  }

  final isMentorship = n.type == NotificationType.mentorship ||
      n.title.toLowerCase().contains('mentorship') ||
      n.message.toLowerCase().contains('scheduled');

  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) {
    nav.pop();
  }

  if (isMentorship) {
    showDialog(
      context: nav.context,
      builder: (_) => MentorshipScheduleDialog(notification: n),
    );
    return;
  }

  // Pop-up modal containing "VIEW LESSON" button
  showDialog(
    context: nav.context,
    builder: (context) => NotificationDetailDialog(notification: n),
  );
}

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

bool isNotificationMentorshipExpired(NotificationModel notification) {
  final msg = notification.message;
  if (msg.contains(' for ')) {
    final parts = msg.split(' for ');
    var timeStr = parts.sublist(1).join(' for ').trim();
    if (timeStr.endsWith('.')) {
      timeStr = timeStr.substring(0, timeStr.length - 1).trim();
    }
    for (final pattern in [
      'EEE, MMM d, yyyy @ h:mm a',
      'EEEE, MMMM d, yyyy • h:mm a',
      'MMMM d, yyyy @ h:mm a',
      'MMM d, yyyy @ h:mm a',
    ]) {
      try {
        final parsed = DateFormat(pattern).parse(timeStr);
        final endTime = parsed.add(const Duration(minutes: 90));
        return DateTime.now().isAfter(endTime);
      } catch (_) {}
    }
  }
  return false;
}

class _MentorshipScheduleDialogState extends State<MentorshipScheduleDialog> {
  String? _educatorName;
  String? _sessionTitle;
  String? _timeStr;
  String? _meetingLink;
  String? _agoraChannel;
  String? _sessionId;
  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;

  bool get _isPastSession {
    final now = DateTime.now();
    if (_sessionEndTime != null) {
      return now.isAfter(_sessionEndTime!);
    }
    if (_sessionStartTime != null) {
      return now.isAfter(_sessionStartTime!.add(const Duration(minutes: 90)));
    }
    return false;
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
      // Query mentorship_sessions for session details
      Query query = FirebaseFirestore.instance
          .collection('mentorship_sessions')
          .where('studentId', isEqualTo: currentUid);
      if (n.educatorId != null && n.educatorId!.isNotEmpty) {
        query = query.where('educatorId', isEqualTo: n.educatorId);
      }

      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        final sortedDocs = snap.docs.toList()
          ..sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['startTime'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['startTime'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

        final data = sortedDocs.first.data() as Map<String, dynamic>;
        _sessionId = sortedDocs.first.id;
        _meetingLink = data['meetingLink'] as String?;
        _agoraChannel = data['agoraChannel'] as String?;
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

        final eduId = data['educatorId'] as String? ?? n.educatorId;
        if (eduId != null && eduId.isNotEmpty) {
          final eduDoc =
              await FirebaseFirestore.instance.collection('users').doc(eduId).get();
          if (eduDoc.exists && eduDoc.data() != null) {
            final u = eduDoc.data()?['username'] as String?;
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

    final nav = Navigator.of(context, rootNavigator: true);
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

    nav.push(
      MaterialPageRoute(
        builder: (_) => ConferencePage(
          channelName: effectiveChannel,
          sessionId: effectiveSessionId,
          sessionTitle: _sessionTitle ?? 'Mentorship Session',
          otherParticipantName: _educatorName ?? 'Educator',
          isHost: false,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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

              // Content Body
              Padding(
                padding: const EdgeInsets.all(24),
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

                    const SizedBox(height: 24),

                    // Actions: Dismiss and JOIN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                            side: BorderSide(
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            _isPastSession ? Icons.event_busy_rounded : Icons.video_call_rounded,
                            size: 20,
                          ),
                          label: Text(
                            _isPastSession ? 'SESSION ENDED' : 'JOIN',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          onPressed: _isPastSession ? null : _handleJoin,
                        ),
                      ],
                    ),
                  ],
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
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

              // Content Area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timestamp pill
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMMM d, yyyy • h:mm a').format(notification.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main Message Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
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
                                  const SizedBox(height: 2),
                                  Text(
                                    lessonTitle,
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
                                Text(
                                  'Feedback from Validator',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFDC2626),
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

              // Footer Actions
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Archive and Delete buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        const SizedBox(width: 4),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLessonUpload)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: MouseRegion(
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
                          ),
                        if (isMentorship)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: MouseRegion(
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
                                onPressed: isMentorshipExpired ? null : () {
                                  final nav = Navigator.of(context, rootNavigator: true);
                                  nav.pop();
                                  showDialog(
                                    context: nav.context,
                                    builder: (_) => MentorshipScheduleDialog(notification: notification),
                                  );
                                },
                              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
