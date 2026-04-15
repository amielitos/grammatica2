import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification_widgets.dart';

class AdminNotificationsTab extends StatefulWidget {
  final User user;
  const AdminNotificationsTab({super.key, required this.user});

  @override
  State<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<AdminNotificationsTab> {
  bool _showArchived = false;
  late Stream<List<NotificationModel>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _notificationsStream = NotificationService.instance.streamNotifications(
      widget.user.uid,
      archived: _showArchived,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showArchived
                    ? 'Archived Notifications'
                    : 'Active Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Active')),
                  ButtonSegment<bool>(value: true, label: Text('Archived')),
                ],
                selected: {_showArchived},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _showArchived = newSelection.first;
                    _initStream();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NotificationModel>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showArchived ? Icons.archive : Icons.notifications_off,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showArchived
                            ? 'No archived notifications'
                            : 'No active notifications',
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: notifications.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
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
