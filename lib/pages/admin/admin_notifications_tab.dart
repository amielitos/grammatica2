import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
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
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showArchived
                    ? 'Archived Notifications'
                    : 'Active Notifications',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: _showArchived,
                onValueChanged: (val) {
                  if (val != null && val != _showArchived) {
                    setState(() {
                      _showArchived = val;
                      _initStream();
                    });
                  }
                },
                children: const {
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Active'),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Archived'),
                  ),
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
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                );
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
                        _showArchived
                            ? CupertinoIcons.archivebox
                            : CupertinoIcons.bell_slash,
                        size: 64,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showArchived
                            ? 'No archived notifications'
                            : 'No active notifications',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
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
