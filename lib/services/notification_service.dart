import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<List<NotificationModel>> streamNotifications(
    String uid, {
    bool archived = false,
  }) {
    return _notifications
        .where('uid', isEqualTo: uid)
        .where('isArchived', isEqualTo: archived)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromDoc(doc))
              .toList(),
        );
  }

  Future<void> sendNotification({
    required String uid,
    required String title,
    required String message,
    required NotificationType type,
    String? rejectionReason,
    String? rejectionDescription,
  }) async {
    final notification = NotificationModel(
      id: '',
      uid: uid,
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
      rejectionReason: rejectionReason,
      rejectionDescription: rejectionDescription,
    );
    await _notifications.add(notification.toMap());
  }

  Future<void> markAsRead(String id) async {
    await _notifications.doc(id).update({'isRead': true});
  }

  Future<void> archiveNotification(String id, {bool archive = true}) async {
    await _notifications.doc(id).update({'isArchived': archive});
  }

  Future<void> deleteNotification(String id) async {
    await _notifications.doc(id).delete();
  }

  Future<void> sendWelcomeNotification(String uid) async {
    await sendNotification(
      uid: uid,
      title: 'Welcome to Grammatica!',
      message:
          'We are excited to have you here! Explore lessons, practice your spelling, and improve your English skills with us.',
      type: NotificationType.welcome,
    );
  }

  Future<void> sendRejectionNotification({
    required String uid,
    required String reason,
    required String description,
  }) async {
    await sendNotification(
      uid: uid,
      title: 'Application Update',
      message: 'Your educator application has been reviewed.',
      type: NotificationType.appRejected,
      rejectionReason: reason,
      rejectionDescription: description,
    );
  }

  Future<void> sendApprovalNotification(String uid) async {
    await sendNotification(
      uid: uid,
      title: 'Application Approved!',
      message:
          'Congratulations! Your application to become an educator has been approved. You can now start creating lessons and quizzes.',
      type: NotificationType.appApproved,
    );
  }

  Future<void> sendAchievementNotification({
    required String uid,
    required String title,
    required String message,
  }) async {
    await sendNotification(
      uid: uid,
      title: title,
      message: message,
      type: NotificationType.achievement,
    );
  }

  Future<void> sendProfileReminderNotification(String uid) async {
    await sendNotification(
      uid: uid,
      title: 'Complete Your Profile',
      message:
          'Please finish setting up your profile by adding your phone number and birthdate to get the most out of Grammatica.',
      type: NotificationType.profileReminder,
    );
  }
}
