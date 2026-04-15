import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
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
    if (!n.isRead) {
      NotificationService.instance.markAsRead(n.id);
    }
    showDialog(
      context: context,
      builder: (context) => NotificationDetailDialog(notification: n),
    );
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
                            onPressed: () {
                              NotificationService.instance.markAllAsRead(widget.userId);
                            },
                            child: const Text('Mark all as read', style: TextStyle(fontSize: 12)),
                          ),
                        IconButton(
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
    if (!n.isRead) {
      NotificationService.instance.markAsRead(n.id);
    }
    showDialog(
      context: context,
      builder: (context) => NotificationDetailDialog(notification: n),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: notification.isRead ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F8E9)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getIconColor(notification.type).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getIcon(notification.type), size: 20, color: _getIconColor(notification.type)),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w800,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            notification.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('MMM d').format(notification.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF81B655), shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Color _getIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.appApproved: return const Color(0xFF81B655);
      case NotificationType.appRejected: return Colors.red;
      case NotificationType.achievement: return Colors.orange;
      case NotificationType.subscription: return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
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
      default:
        return CupertinoIcons.info_circle_fill;
    }
  }
}

class NotificationDetailDialog extends StatelessWidget {
  final NotificationModel notification;

  const NotificationDetailDialog({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(notification.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            if (notification.type == NotificationType.appRejected) ...[
              const SizedBox(height: 16),
              const Text(
                'Rejection Reason:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(notification.rejectionReason ?? 'No reason provided'),
              const SizedBox(height: 8),
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                notification.rejectionDescription ?? 'No description provided',
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Received on: ${DateFormat('MMMM d, yyyy HH:mm').format(notification.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            NotificationService.instance.archiveNotification(
              notification.id,
              archive: !notification.isArchived,
            );
            Navigator.pop(context);
          },
          child: Text(notification.isArchived ? 'Restore' : 'Archive'),
        ),
        TextButton(
          onPressed: () {
            NotificationService.instance.deleteNotification(notification.id);
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
