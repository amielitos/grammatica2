import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  welcome,
  appRejected,
  appApproved,
  achievement,
  profileReminder,
  general,
}

class NotificationModel {
  final String id;
  final String uid;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final bool isArchived;
  final String? rejectionReason;
  final String? rejectionDescription;

  NotificationModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.isArchived = false,
    this.rejectionReason,
    this.rejectionDescription,
  });

  factory NotificationModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return NotificationModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: _typeFromString(data['type']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      isArchived: data['isArchived'] ?? false,
      rejectionReason: data['rejectionReason'],
      rejectionDescription: data['rejectionDescription'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'message': message,
      'type': type.toString().split('.').last,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'isArchived': isArchived,
      'rejectionReason': rejectionReason,
      'rejectionDescription': rejectionDescription,
    };
  }

  static NotificationType _typeFromString(String? type) {
    switch (type) {
      case 'welcome':
        return NotificationType.welcome;
      case 'appRejected':
        return NotificationType.appRejected;
      case 'appApproved':
        return NotificationType.appApproved;
      case 'achievement':
        return NotificationType.achievement;
      case 'profileReminder':
        return NotificationType.profileReminder;
      default:
        return NotificationType.general;
    }
  }

  NotificationModel copyWith({bool? isRead, bool? isArchived}) {
    return NotificationModel(
      id: id,
      uid: uid,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      rejectionReason: rejectionReason,
      rejectionDescription: rejectionDescription,
    );
  }
}
